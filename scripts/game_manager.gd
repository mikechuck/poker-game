extends Node2D

# Networking fields
var is_server = false
const server_ip_address = "0.0.0.0"
const server_port = 8083

#Scenes
@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

# UI Fields
var screen_origin

# Game logic fields

# Server fields
var host_player: ConnectedPlayer = null
var connected_players: Dictionary[int, ConnectedPlayer] = {}
var player_seats: Dictionary[int, PlayerSeat] = {}

# Client fields
var player = null

func _ready() -> void:
	screen_origin = get_viewport_rect().size / 2
	set_player_seats()
	
	var args = OS.get_cmdline_args()
	if (args.find("server_mode") >= 0):
		is_server = true
		start_server()
	else:
		is_server = false
		connect_to_server()
	
# Server networking methods

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
	connected_player.index = connected_players.size()
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
		var new_host_id = connected_players.keys()[0].id
		host_player = connected_players.get(new_host_id)
		print("Host left, new host is player %s" % [new_host_id])
	print("Number of players connected: %s" % [connected_players.size()])
	
# End server networking methods

# Start server RPCs

@rpc("any_peer")
func client_request_seat(seat_number: int):
	print("client is requesting seat number %s" %[seat_number])
	var client_id = multiplayer.get_remote_sender_id()
	var desired_seat = player_seats.get(seat_number)
	if (desired_seat.player_id == 0):
		# First remove them from their current seat then put them in the new seat
		for seat in player_seats.values():
			if (seat.player_id == client_id):
				seat.player_id = 0
		desired_seat.player_id = client_id
		player_seats[seat_number] = desired_seat
		print("Sending player seats to all clients")
		var player_seats_dict = {}
		for player_id in player_seats:
			player_seats_dict[player_id] = player_seats[player_id].to_dict()
		update_player_seats_list.rpc(player_seats_dict)
		rpc("update_player_seats_list")
		
	else:
		print("Seat is not available")

# End server RPCs

# Player networking methods

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
	client_request_seat.rpc_id(1, 1)
	print("Requesting seat number 1")

func _on_connection_failed():
	print("Connection to server failed.")
	
func _on_disconnected():
	print("Disconnected from server.")
	
func spawn_player(seat_details: PlayerSeat):
	var player_instance = player_scene.instantiate()
	player_instance.position = seat_details.pos
	add_child(player_instance)
	
# Client RPCs

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
	player_seats = {}
	for id in new_player_seats.keys():
		player_seats[id] = PlayerSeat.from_dict(new_player_seats[id])
	print("got player seats in client, length: %s" % [player_seats])
	#player_seats = parse_player_seats_from_json(player_seats)
	for seat_id in player_seats.keys():
		var seat = player_seats[seat_id]
		if (seat.player_id != 0):
			spawn_player(seat)
			print("Spawning player %s at seat %s" % [seat.player_id, seat_id])
	
# End Client RPCs

# End player networking methods

# Helper functions
func parse_player_seats_from_json(json_string: String) -> Dictionary[int, PlayerSeat]:
	var new_player_seats: Dictionary[int, PlayerSeat]
	var dictionary_parser = JSON.new()
	var error = dictionary_parser.parse(json_string)
	var dictionary_data = dictionary_parser.get_data()
	#for key in dictionary_data.keys():
		
		#player_seats[key] = instance_from_id(dictionary_data.)
		
	return new_player_seats
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func set_player_seats():
	var single_angle = PI / 4
	var table_radius = 225
	for i in 8:
		var xPos = (table_radius + 60) * cos(i * single_angle) + screen_origin.x
		var yPos = (table_radius + 60) * sin(i * single_angle) + screen_origin.y
		var pos = Vector2(xPos, yPos)
		var player_seat = PlayerSeat.new()
		player_seat.pos = pos
		player_seat.player_id = 0
		player_seats[i] = player_seat
	
class ConnectedPlayer:
	var id: int = 0
	var index: int = 0
	var is_host: bool = false
	var is_ready: bool = false
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"index": index,
			"is_host": is_host,
			"is_ready": is_ready
		}
		
	static func from_dict(dict: Dictionary) -> ConnectedPlayer:
		var instance = ConnectedPlayer.new()
		instance.id = dict.get("id")
		instance.index = dict.get("index")
		instance.is_host = dict.get("is_host")
		instance.is_ready = dict.get("is_ready")
		return instance
	
class PlayerSeat:
	var pos: Vector2
	var player_id: int = 0
	
	func to_dict() -> Dictionary:
		return {
			"pos": pos,
			"player_id": player_id
		}
	
	static func from_dict(dict) -> PlayerSeat:
		var instance = PlayerSeat.new()
		instance.pos = dict.get("pos")
		instance.player_id = dict.get("player_id")
		return instance
