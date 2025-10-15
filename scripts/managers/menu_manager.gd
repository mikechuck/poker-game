extends Node

@onready var debug_output_node = $DebugOutput

var server_url = ""
var server_port = ""

func _ready() -> void:
	# Get os args
	# If server, load Game scene (server will start automatically there)
	pass

func add_debug_line(text: String) -> void:
	debug_output_node.text += text + "\n"

func _on_create_game_button_pressed() -> void:
	add_debug_line("Create button pressed")
	# Call our orchestration API to request new server startup
	# On response, set server_url and server_port and connect to the server

func _on_join_game_button_pressed() -> void:
	add_debug_line("Joining server at %s:%s..." % [server_url, server_port])
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
	add_debug_line("Successfully connected to server")

func _on_connection_failed():
	add_debug_line("Connection to server failed.")
	
func _on_disconnected():
	add_debug_line("Disconnected from server.")
