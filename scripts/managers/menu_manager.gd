extends Node

@onready var debug_output_node = $DebugOutput
@onready var url_input_node = $Menu/JoinGame/IpInput
@onready var port_input_node = $Menu/JoinGame/PortInput
@onready var web_auth_guard = $WebAuthGuard

var server_url = "localhost"
var server_port = "8083"
var is_navigating = false


func get_current_path() -> String:
	# Use JavaScript to get current URL path
	# Return empty string if JavaScriptBridge is not available (e.g., in server mode)
	var js_code = "window.location.pathname"
	var result = JavaScriptBridge.eval(js_code)
	if result == null:
		return ""
	# Ensure we return a String type
	return str(result)

func _ready() -> void:
	# Check for server mode FIRST before any client-side code
	var args = OS.get_cmdline_args()
	if (args.find("server_mode") >= 0):
		print("Starting in server mode, loading game scene...")
		navigate_to_game_scene()
		return
	
	# All code below is client-side only
	var current_path = get_current_path()
	if current_path.ends_with("/callback"):
		# Defer callback handling to ensure scene is fully loaded
		call_deferred("_handle_oauth_callback_deferred")
		return
	
	# Normal flow: check for token and setup menu
	_setup_menu()

func _handle_oauth_callback_deferred():
	"""Handle OAuth callback after scene is fully loaded"""
	print("Deferred OAuth callback handling...")
	web_auth_guard.handle_oauth_callback()
	# Note: Token will be set asynchronously, then redirect to "/" happens
	# When redirected, _ready() will run again and call _setup_menu()
	# which will check for the token

func _setup_menu():
	"""Setup the game menu - called from _ready() or after redirect"""
	if not AccessTokenService.has_token():
		print("User not authenticated, redirecting to auth system...")
		web_auth_guard.redirect_to_auth()
		return
	
	print("User authenticated, proceeding to game menu")
	
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
	var error = peer.create_client("ws://%s:%s" % [server_url, server_port])
	if error != OK:
		print("Failed to create client: %s" % error)
		return
	
	multiplayer.multiplayer_peer = peer
	print("Attempting to connect to ws://%s:%s..." % [server_url, server_port])

func _on_connected():
	print("Successfully connected to server! (via signal)")
	if is_navigating:
		return
	is_navigating = true
	navigate_to_game_scene()

func _on_connection_failed():
	print("Connection to server failed. (via signal)")
	
func _on_disconnected():
	print("Disconnected from server.")

func navigate_to_game_scene() -> void:
	print("Navigating to game scene...")
	var error = get_tree().change_scene_to_file("res://scenes/game.tscn")
	if error != OK:
		print("ERROR: Failed to change scene: %s" % error)
		# Fallback to deferred call
		get_tree().call_deferred("change_scene_to_file", "res://scenes/game.tscn")
	else:
		print("Scene change initiated successfully")