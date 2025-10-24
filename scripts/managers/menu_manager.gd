extends Node

@onready var debug_output_node = $DebugOutput
@onready var url_input_node = $Menu/JoinGame/IpInput
@onready var port_input_node = $Menu/JoinGame/PortInput
@onready var web_auth_guard = $WebAuthGuard

var server_url = "localhost"
var server_port = "8083"
var mp_peer = null


func get_current_path() -> String:
	# Use JavaScript to get current URL path
	var js_code = "window.location.pathname"
	return JavaScriptBridge.eval(js_code)

func _ready() -> void:
	var current_path = get_current_path()
	if current_path.ends_with("/callback"):
		web_auth_guard.handle_oauth_callback()
		return
	
	if not web_auth_guard.check_auth_status():
		print("User not authenticated, redirecting to auth system...")
		web_auth_guard.redirect_to_auth()
		return
	
	print("User authenticated, proceeding to game menu")
	
	# Get os args
	# If server, load Game scene (server will start automatically there)
	var args = OS.get_cmdline_args()
	if (args.find("server_mode") >= 0):
		navigate_to_game_scene()
	url_input_node.text = server_url
	port_input_node.text = server_port
	
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
		
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
	
func _on_connected():
	print("Successfully connected to server!")
	navigate_to_game_scene()

func _on_connection_failed():
	print("Connection to server failed.")
	
func _on_disconnected():
	print("Disconnected from server.")
	
func navigate_to_game_scene() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/game.tscn")
