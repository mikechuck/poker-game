extends Node2D

### Networking fields
var is_server = false
const server_ip_address = "0.0.0.0"
const server_port = 8083

### Scenes
@export var player_scene: PackedScene = preload("res://scenes/player.tscn")
@export var player_ui_scene: PackedScene = preload("res://scenes/UI/player_ui.tscn")

### Instantiated scenes
var player_ui_instance = null

### Signals
signal connected_players_updated_signal(connected_players)
signal player_seats_updated_signal(player_seats)
signal game_started_signal()

### UI Fields
var screen_origin
var single_angle = PI / 4
var table_radius = 225

### Game logic fields
var default_starting_cash = 100
var game_started: bool = false
var turn

### Server fields
var host_player: ConnectedPlayer = null
var connected_players: Dictionary[int, ConnectedPlayer] = {}
var player_seats: Dictionary[int, PlayerSeat] = {}

### Client fields
var player_data = null

### Start built in methods

func _ready() -> void:
	var args = OS.get_cmdline_args()
	if (args.find("server_mode") >= 0):
		is_server = true
		screen_origin = Vector2.ZERO # Adjust for screen size on client only
		start_server()
		set_player_seats()
	else:
		is_server = false
		screen_origin = get_viewport_rect().size / 2
		#player_ui_instance = player_ui_scene.instantiate()
		#get_tree().root.add_child(player_ui_instance)
		player_ui_instance = get_parent().find_child("PlayerUI")
		connect_to_server()
		queue_redraw()
		
func _process(delta: float) -> void:
	pass

func _draw() -> void:
	pass
	
### End built in methods

###################################### Server #############################################

### Start Server networking methods

func start_server():
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_server(server_port)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Started server at ws://localhost:%s ..." % [server_port])
	
func _on_peer_connected(id):
	var connected_player = ConnectedPlayer.new()
	connected_player.id = id
	connected_player.starting_cash = default_starting_cash
	connected_player.current_cash = default_starting_cash
	connected_players[id] = connected_player
	# If this was the first player to connect, set it as host player
	if (host_player == null):
		host_player = connected_player
		connected_player.is_host = true
	print("Number of players connected: %s" % [connected_players.size()])
	update_connected_players_list.rpc(serialize_connected_players())
	
func _on_peer_disconnected(id):
	var disconnecting_player = connected_players.get(id)
	connected_players.erase(id)
	if disconnecting_player.is_host:
		if (connected_players.values().size() > 0):
			var new_host_id = connected_players.keys()[0]
			host_player = connected_players.get(new_host_id)
		else:
			host_player = null
	# Clear the player from the seat
	for seat in player_seats.values():
		if seat.player_id == id:
			seat.player_id = 0
			seat.player_node = null
	update_connected_players_list.rpc(serialize_connected_players())
	update_player_seats_list.rpc(serialize_player_seats())
	print("Number of players connected: %s" % [connected_players.size()])
	
### End server networking methods

### Start server RPCs

@rpc("reliable", "any_peer")
func client_request_player_data():
	var connected_player = connected_players.get(multiplayer.get_remote_sender_id())
	assign_player_data.rpc_id(connected_player.id, connected_player.to_dict())
	update_connected_players_list.rpc(serialize_connected_players())
	update_player_seats_list.rpc(serialize_player_seats())

@rpc("reliable", "any_peer")
func client_request_seat(seat_number: int):
	var client_id = multiplayer.get_remote_sender_id()
	# Check to see if seat is already filled
	seat_number = get_next_free_seat(seat_number)
	# First remove them from their current seat then put them in the new seat
	var desired_seat = player_seats.get(seat_number)
	for seat in player_seats.values():
		if (seat.player_id == client_id):
			seat.player_id = 0
	desired_seat.player_id = client_id
	player_seats[seat_number] = desired_seat
	print("Assigned player %s to seat number %s" % [client_id, seat_number])
	update_player_seats_list.rpc(serialize_player_seats())
	
@rpc("reliable", "any_peer")
func client_set_ready_status(is_ready: bool):
	connected_players[multiplayer.get_remote_sender_id()].is_ready = is_ready
	update_connected_players_list.rpc(serialize_connected_players())
	
@rpc("reliable", "any_peer")
func client_start_game():
	var requestor_id = multiplayer.get_remote_sender_id()
	if (host_player.id == requestor_id):
		start_game()

func start_game() -> void:
	game_started.rpc() # Tell all the clients the game has started
	# do other game start things.
	# - deal cards
	# - tell blinds to add antes
	# - allow player one to make a bet
	
### End server RPCs

###################################### Client #############################################

func connect_to_server():
	print("Connecting to server at ws://localhost:%s ..." % [server_port])
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_client("ws://localhost:%s" % [server_port])
	multiplayer.multiplayer_peer = peer
	
	# Events
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
	
func _on_connected():
	print("Successfully connected to server")
	client_request_player_data.rpc_id(1)

func _on_connection_failed():
	print("Connection to server failed.")
	
func _on_disconnected():
	print("Disconnected from server.")
	
### Client RPCs

@rpc("reliable", "authority")
func assign_player_data(player):
	player_data = ConnectedPlayer.from_dict(player)
	player_ui_instance.set_player_data(player_data)
	client_request_seat.rpc_id(1, 1)
	emit_signal("connected_players_updated_signal", connected_players)
	
@rpc("reliable", "call_remote")
func update_connected_players_list(new_connected_players_list):
	if (player_data != null):
		for connected_player in new_connected_players_list.values():
			if connected_player.id == multiplayer.get_unique_id():
				player_data = connected_player
		connected_players = deserialize_connected_players(new_connected_players_list)
		emit_signal("connected_players_updated_signal", connected_players)

@rpc("reliable", "call_remote")
func update_player_seats_list(new_player_seats):
	# Player has not finished setup process while another player connected,
	# can't do anything with this data yet in that case
	if (player_data != null):
		player_seats = deserialize_player_seats(new_player_seats)
		emit_signal("player_seats_updated_signal", player_seats)
		
@rpc("reliable", "call_remote")
func game_started():
	emit_signal("game_started_signal")
		
###################################### Helper Functions #############################################

func set_player_seats():
	for i in range(1, 9):
		var player_seat = PlayerSeat.new()
		player_seat.player_id = 0
		player_seats[i] = player_seat

# Converts a dict of custom objects to dict of generic objects
func serialize_player_seats() -> Dictionary:
	var player_seats_dict = {}
	for player_id in player_seats:
		player_seats_dict[player_id] = player_seats[player_id].to_dict()
	return player_seats_dict
	
func deserialize_player_seats(new_player_seats) -> Dictionary[int, PlayerSeat]:
	var deserialized_player_seats: Dictionary[int, PlayerSeat] = {}
	for id in new_player_seats.keys():
		deserialized_player_seats[id] = PlayerSeat.from_dict(new_player_seats[id])
	return deserialized_player_seats
	
func serialize_connected_players() -> Dictionary:
	var connected_players_dict = {}
	for player_id in connected_players:
		connected_players_dict[player_id] = connected_players[player_id].to_dict()
	return connected_players_dict
	
func deserialize_connected_players(new_connected_players) -> Dictionary[int, ConnectedPlayer]:
	var deserialized_connected_players: Dictionary[int, ConnectedPlayer] = {}
	for id in new_connected_players.keys():
		deserialized_connected_players[id] = ConnectedPlayer.from_dict(new_connected_players[id])
	return deserialized_connected_players
	
func get_next_free_seat(seat_number):
	var desired_seat = player_seats.get(seat_number)
	if (desired_seat.player_id != 0):
		seat_number = (seat_number + 1) % 8
		desired_seat = player_seats.get(seat_number)
		seat_number = get_next_free_seat(seat_number)
	return seat_number
	
enum GameState {
	Lobby,
	GameStarted,
	GameEnded,
}
