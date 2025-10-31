extends Node

@onready var debug_output_node = $DebugOutput
@onready var url_input_node = $Menu/JoinGame/IpInput
@onready var port_input_node = $Menu/JoinGame/PortInput
@onready var web_auth_guard = $WebAuthGuard

var server_url = "localhost"
var server_port = "8083"
var mp_peer = null
var connection_check_timer = null
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
		web_auth_guard.handle_oauth_callback()
		return
	
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
	
	# Start polling connection status (WebSocket connections in web may not fire signal immediately)
	if connection_check_timer == null:
		connection_check_timer = Timer.new()
		connection_check_timer.wait_time = 0.1
		connection_check_timer.timeout.connect(_check_connection_status)
		connection_check_timer.one_shot = false
		add_child(connection_check_timer)
		connection_check_timer.start()

func _check_connection_status():
	if multiplayer.multiplayer_peer == null:
		return
	
	var connection_state = multiplayer.multiplayer_peer.get_connection_status()
	print("Connection status: %s" % connection_state)
	
	# Check if we're connected (connection_status 2 = CONNECTION_CONNECTED)
	if connection_state == MultiplayerPeer.CONNECTION_CONNECTED and not is_navigating:
		print("Connection established! Navigating to game scene...")
		is_navigating = true
		if connection_check_timer:
			connection_check_timer.stop()
			connection_check_timer.queue_free()
			connection_check_timer = null
		# Small delay to ensure connection is fully established, then navigate
		get_tree().create_timer(0.1).timeout.connect(_on_delayed_navigate)
	elif connection_state == MultiplayerPeer.CONNECTION_DISCONNECTED:
		print("Connection failed or disconnected")
		if connection_check_timer:
			connection_check_timer.stop()
			connection_check_timer.queue_free()
			connection_check_timer = null
	
func _on_connected():
	print("Successfully connected to server! (via signal)")
	if is_navigating:
		return  # Already navigating, don't navigate twice
	is_navigating = true
	if connection_check_timer:
		connection_check_timer.stop()
		connection_check_timer.queue_free()
		connection_check_timer = null
	navigate_to_game_scene()

func _on_connection_failed():
	print("Connection to server failed. (via signal)")
	if connection_check_timer:
		connection_check_timer.stop()
		connection_check_timer.queue_free()
		connection_check_timer = null
	
func _on_disconnected():
	print("Disconnected from server.")
	
func _on_delayed_navigate() -> void:
	navigate_to_game_scene()

func navigate_to_game_scene() -> void:
	print("Navigating to game scene...")
	var error = get_tree().change_scene_to_file("res://scenes/game.tscn")
	if error != OK:
		print("ERROR: Failed to change scene: %s" % error)
		# Fallback to deferred call
		get_tree().call_deferred("change_scene_to_file", "res://scenes/game.tscn")
	else:
		print("Scene change initiated successfully")