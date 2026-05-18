extends Node

@onready var http_request_manager = $HttpRequests
@onready var debug_output_node = $DebugOutput
@onready var url_input_node = $Menu/JoinGame/IpInput
@onready var port_input_node = $Menu/JoinGame/PortInput
@onready var account_section = $AccountSection

var server_url = "poker.mikechucktingle.net/game"
var server_port = "12001"
var mp_peer = null

func _ready() -> void:
	# Get os args
	# If server, load Game scene (server will start automatically there)
	var args = OS.get_cmdline_args()
	if (args.find("--server") >= 0):
		navigate_to_game_scene()

	http_request_manager.get_account_data(func(data):
		account_section.display_account_data(data)
	)
		
	# If not the server, then we should bounce the user the landing if they don't have
	port_input_node.text = server_port
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
		
func add_debug_line(text: String) -> void:
	debug_output_node.text += text + "\n"
	print(text)

func _on_create_game_button_pressed() -> void:
	print("Create button pressed, calling API")
	http_request_manager.create_game(func(data):
		print("Create game response: %s" % [JSON.stringify(data)])
	)
	# Call our orchestration API to request new server startup
	# On response, set server_url and server_port and connect to the server

func _on_join_game_button_pressed() -> void:
	print("Joining server at ws://%s/%s..." % [server_url, server_port])
	connect_to_server()
	
func _on_port_input_text_changed(new_text: String) -> void:
	server_port = new_text

func _on_ip_input_text_changed(new_text: String) -> void:
	server_url = new_text

func connect_to_server():
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_client("ws://%s/%s" % ["localhost", server_port])
	multiplayer.multiplayer_peer = peer
	
func _on_connected():
	print("Successfully connected to server!")
	navigate_to_game_scene()

func _on_connection_failed():
	print("Connection to server failed.")
	
func _on_disconnected():
	print("Disconnected from server.")
	
func navigate_to_game_scene() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/game.tscn")
