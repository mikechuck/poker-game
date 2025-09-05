extends Node2D

### Networking fields
var is_server = false
const server_ip_address = "0.0.0.0"
const server_port = 8083

### Scenes
@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

### UI Fields
var screen_origin
var single_angle = PI / 4
var table_radius = 225

### Game logic fields

### Server fields
var host_player: ConnectedPlayer = null
var connected_players: Dictionary[int, ConnectedPlayer] = {}
var player_seats: Dictionary[int, PlayerSeat] = {}

### Client fields
var player = null

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
		connect_to_server()
		queue_redraw()
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _draw() -> void:
	# Redraw the players in their given seats
	var seat_color = Color(1.0, 1.0, 1.0, 0.5)
	var player_color = Color(1.0, 0.0, 0.0)
	for seat_index in player_seats.keys():
		var seat = player_seats[seat_index]
		print("Seat index: %s | Seat player id: %s" % [seat_index, seat.player_id])
		var new_seat_pos =  Vector2(seat.pos.x + screen_origin.x, seat.pos.y + screen_origin.y)
		if (seat.player_id != 0):
			draw_circle(new_seat_pos, 30, player_color)
		else:
			#var xPos = (table_radius + 60) * cos(seat.id * single_angle) + screen_origin.x
			#var yPos = (table_radius + 60) * sin(seat.id * single_angle) + screen_origin.y
			#var pos = Vector2(xPos, yPos)
			draw_circle(new_seat_pos, 30, seat_color)
			var label = Label.new()
			label.position.x = new_seat_pos.x - 6
			label.position.y = new_seat_pos.y - 15
			label.text = str(seat_index + 1)
			label.add_theme_font_size_override("font_size", 22)
			add_child(label)
	
### End built in methods

### Server networking methods

func start_server():
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_server(server_port)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Started server at ws://localhost:%s ..." % [server_port])
	
func _on_peer_connected(id):
	print("Player connected: %s" % [id])
	var connected_player = ConnectedPlayer.new()
	connected_player.id = id
	connected_players[id] = connected_player
	# If this was the first player to connect, set it as host player
	if (host_player == null):
		host_player = connected_player
		connected_player.is_host = true
		print("Player %s is the game host" % [id])
	var dict_connect_players = {}
	for player_id in connected_players.keys():
		dict_connect_players[player_id] = connected_players[player_id].to_dict()
	update_connected_players_list.rpc(dict_connect_players)
	print("Number of players connected: %s" % [connected_players.size()])
	
func _on_peer_disconnected(id):
	print("Player disconnected: %s" % [id])
	var disconnecting_player = connected_players.get(id)
	connected_players.erase(id)
	if disconnecting_player.is_host && connected_players.values().size() > 0:
		var new_host_id = connected_players.keys()[0]
		host_player = connected_players.get(new_host_id)
		print("Host left, new host is player %s" % [new_host_id])
	# Clear the player from the seat
	for seat in player_seats.values():
		if seat.player_id == id:
			seat.player_id = 0
	update_player_seats_list.rpc(serialize_player_seats())
	print("Number of players connected: %s" % [connected_players.size()])
	
### End server networking methods

### Start server RPCs

@rpc("any_peer")
func client_request_seat(seat_number: int):
	print("Client is requesting seat number %s" %[seat_number])
	var client_id = multiplayer.get_remote_sender_id()
	var desired_seat = player_seats.get(seat_number)
	if (desired_seat.player_id != 0):
		seat_number = (seat_number + 1) % 8
		desired_seat = player_seats.get(seat_number)
		print("Seat is not available, assigning seat %s" % [seat_number])
	# First remove them from their current seat then put them in the new seat
	for seat in player_seats.values():
		if (seat.player_id == client_id):
			seat.player_id = 0
	desired_seat.player_id = client_id
	player_seats[seat_number] = desired_seat
	print("Sending player seats to all clients")
	update_player_seats_list.rpc(serialize_player_seats())

### End server RPCs

### Player networking methods

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
	client_request_seat.rpc_id(1, 0)
	print("Requesting seat number 1")

func _on_connection_failed():
	print("Connection to server failed.")
	
func _on_disconnected():
	print("Disconnected from server.")
	
func spawn_player(seat_details: PlayerSeat):
	var player_instance = player_scene.instantiate()
	player_instance.position = seat_details.pos + screen_origin
	player_instance.player_id = seat_details.player_id
	connected_players[seat_details.player_id].player_node = player_instance
	add_child(player_instance)

func clear_drawn_player_nodes():
	for seat in player_seats.values():
		if seat.player_node != null:
			print("Removing node for player %s" % [seat.player_id])
			remove_child(seat.player_node)
			queue_free()

func redraw_players():
	for seat_index in player_seats.keys():
		var seat = player_seats[seat_index]
		if seat.player_id != 0:
			print("Spawning player %s at seat %s" % [seat.player_id, seat_index])
			var player_instance = player_scene.instantiate()
			player_instance.position = seat.pos + screen_origin
			player_instance.player_id = seat.player_id
			seat.player_node = player_instance
			add_child(player_instance)
	
### Client RPCs

@rpc("reliable")
func assign_player_id(id):
	player = ConnectedPlayer.new()
	player.id = id
	print("My player id is: %s" % [player.id])
	
@rpc("call_remote")
func update_connected_players_list(new_connected_players_list):
	connected_players = {}
	for id in new_connected_players_list:
		connected_players[id] = ConnectedPlayer.from_dict(new_connected_players_list[id])

@rpc("call_remote")
func update_player_seats_list(new_player_seats):
	print("Got new player seat list")
	clear_drawn_player_nodes()
	player_seats = deserialize_player_seats(new_player_seats)
	redraw_players()
	queue_redraw()
	
### End Client RPCs

### End player networking methods
	
func set_player_seats():
	for i in 8:
		var xPos = (table_radius + 60) * cos(i * single_angle) + screen_origin.x
		var yPos = (table_radius + 60) * sin(i * single_angle) + screen_origin.y
		var pos = Vector2(xPos, yPos)
		var player_seat = PlayerSeat.new()
		player_seat.pos = pos
		player_seat.player_id = 0
		player_seats[i] = player_seat
		
### Start helper functions

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
	
### End helper functions
		
### Start custom data types 
	
class ConnectedPlayer:
	var id: int = 0
	var is_host: bool = false
	var is_ready: bool = false
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"is_host": is_host,
			"is_ready": is_ready
		}
		
	static func from_dict(dict: Dictionary) -> ConnectedPlayer:
		var instance = ConnectedPlayer.new()
		instance.id = dict.get("id")
		instance.is_host = dict.get("is_host")
		instance.is_ready = dict.get("is_ready")
		return instance
	
class PlayerSeat:
	var pos: Vector2
	var player_id: int = 0
	var player_node: Node2D
	
	func to_dict() -> Dictionary:
		return {
			"pos": pos,
			"player_id": player_id,
			"player_node": player_node
		}
	
	static func from_dict(dict) -> PlayerSeat:
		var instance = PlayerSeat.new()
		instance.pos = dict.get("pos")
		instance.player_id = dict.get("player_id")
		instance.player_node = dict.get("player_node")
		return instance

### End custom data types
