extends Node

@onready var debug_output_node = $DebugOutput
@onready var url_input_node = $Menu/JoinGame/IpInput
@onready var port_input_node = $Menu/JoinGame/PortInput
#var game_scene_resource = preload("res://scenes/game.tscn")

var server_url = "localhost"
var server_port = "8083"

func _ready() -> void:
	# Get os args
	# If server, load Game scene (server will start automatically there)
	var args = OS.get_cmdline_args()
	if (args.find("server_mode") >= 0):
		navigate_to_game_scene()
	url_input_node.text = server_url
	port_input_node.text = server_port
		
func add_debug_line(text: String) -> void:
	debug_output_node.text += text + "\n"
	print(text)

func _on_create_game_button_pressed() -> void:
	print("Create button pressed")
	# Call our orchestration API to request new server startup
	# On response, set server_url and server_port and connect to the server

func _on_join_game_button_pressed() -> void:
	print("Joining server at ws://%s:%s..." % [server_url, server_port])
	connect_to_server()
	
func _on_port_input_text_changed(new_text: String) -> void:
	server_port = new_text

func _on_ip_input_text_changed(new_text: String) -> void:
	server_url = new_text

func connect_to_server():
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_client("ws://%s:%s" % [server_url, server_port])
	multiplayer.multiplayer_peer = peer
	
	# Events
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
	
func _on_connected():
	print("Successfully connected to server!")
	navigate_to_game_scene()

func _on_connection_failed():
	print("Connection to server failed.")
	
func _on_disconnected():
	print("Disconnected from server.")
	
func navigate_to_game_scene() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/game.tscn")
