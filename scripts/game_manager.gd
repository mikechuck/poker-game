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

# Client fields
var player = null

func _ready() -> void:
	var args = OS.get_cmdline_args()
	if (args.find("server_mode") >= 0):
		is_server = true
		start_server()
	else:
		is_server = false
		connect_to_server()
	screen_origin = get_viewport_rect().size / 2
	
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

func _on_connection_failed():
	print("Connection to server failed.")
	
func _on_disconnected():
	print("Disconnected from server.")
	
func spawn_player(player):
	var player_instance = player_scene.instantiate()
	player_instance.position = Vector2(screen_origin.x, screen_origin.y)
	add_child(player_instance)
	
# Client RPCs

@rpc("reliable")
func assign_player_id(id):
	player = ConnectedPlayer.new()
	player.id = id
	print("My player id is: %s" % [player.id])
	
@rpc("any_peer")
func update_connected_players_list(server_connected_players_list):
	connected_players = server_connected_players_list
	for player in connected_players:
		spawn_player(player)
	
# End Client RPCs

# End player networking methods

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
class ConnectedPlayer:
	var id = 0
	var index = 0
	var is_host = false
	var is_ready = false
