extends Node2D

# Networking fields
var is_server = false
const server_ip_address = "0.0.0.0"
const server_port = 8083

#Scenes
@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

# UI Fields
var screen_origin

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
	print("Starting server at ws://localhost:%s ..." % [server_port])
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_server(server_port)
	multiplayer.multiplayer_peer = peer
	print("Server started.")
	
func _on_player_connected(id):
	print("Player connected: ", id)
	
func _on_player_disconnected(id):
	print("Player disconnected: ", id)
	
# End server networking methods

# Player networking methods

func connect_to_server():
	print("Starting server at ws://localhost:%s ..." % [server_port])
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_client("ws://localhost:" + str(server_port))
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
	
func spawn_player():
	var player_instance = player_scene.instantiate()
	player_instance.position = Vector2(screen_origin.x, screen_origin.y)
	add_child(player_instance)

# End player networking methods

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
