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
var host_player = null
var connected_players = {}
var player_seats = {}


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
	var connected_player = ConnectedPlayer.new()
	connected_player.id = id
	connected_players[id] = connected_player
	connected_player.index = connected_players.size()
	# If this was the first player to connect, set it as host player
	if (host_player == null):
		host_player = connected_player
		connected_player.is_host = true
		print("Player %s is the game host" % [id])
	update_connected_players_list.rpc(connected_players)
	print("Player connected: %s" % [id])
	print("Number of players connected: %s" % [connected_players.size()])
	
func _on_peer_disconnected(id):
	var disconnecting_player = connected_players.get(id)
	connected_players.erase(id)
	if disconnecting_player.id == host_player.id:
		var new_host_id = connected_players.keys()
		host_player = connected_players[new_host_id]
		print("Host left, new host is player %s" % [new_host_id])
	print("Player disconnected: %s" % [id])
	print("Number of players connected: %s" % [connected_players.size()])
	
# End server networking methods

# Start server RPCs

@rpc("any_peer")
func client_request_seat(seat_number):
	print("client is requesting seat number %s" %[seat_number])
	if (player_seats.get(seat_number).sitting_player == null):
		print("Seat is availble")
		var player = connected_players.get(multiplayer.get_remote_sender_id())
		player_seats[seat_number] = player
		update_player_seats_list.rpc(player_seats)
	else:
		print("Seat is not available")

# End server RPCs

# Player networking methods

func connect_to_server():
	print("Starting server at ws://localhost:%s ..." % [server_port])
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
	#rpc_id(1, "request_spawn_player")
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
func update_connected_players_list(server_connected_players_list):
	connected_players = server_connected_players_list
		
@rpc("call_remote")
func update_player_seats_list(player_seats_list):
	player_seats = player_seats_list
	for seat in player_seats:
		spawn_player(seat)
	
	
# End Client RPCs

# End player networking methods

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
		player_seat.sitting_player = null
		player_seats[i] = player_seat
	
class ConnectedPlayer:
	var id = 0
	var index = 0
	var is_host = false
	var is_ready = false
	
class PlayerSeat:
	var pos
	var sitting_player
	
