extends Node

@onready var debug_output_node = $DebugOutput
@onready var url_input_node = $Menu/JoinGame/IpInput
@onready var port_input_node = $Menu/JoinGame/PortInput
@onready var web_auth_guard = $WebAuthGuard

func get_current_path() -> String:
	var js_code = "window.location.pathname"
	var result = JavaScriptBridge.eval(js_code)
	if result == null:
		return ""
	return str(re

var is_navigating = false
var server_url = "poker.mikechucktingle.net/game"
var server_port = "12001"
var mp_peer = null

func _ready() -> void:
	var args = OS.get_cmdline_args()
	if (args.find("--server") >= 0):
		navigate_to_game_scene()
		return
	var current_path = get_current_path()
	if current_path.ends_with("/callback"):
		call_deferred("_handle_oauth_callback_deferred")
		return
	_setup_menu()

func _handle_oauth_callback_deferred():
	web_auth_guard.handle_oauth_callback()

func _setup_menu():
	if not AccessTokenService.has_token():
		web_auth_guard.redirect_to_auth()
		return
	url_input_node.text = server_url
	port_input_node.text = server_port
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
		
func add_debug_line(text: String) -> void:
	debug_output_node.text += text + "\n"

func _on_create_game_button_pressed() -> void:
	pass

func _on_join_game_button_pressed() -> void:
	print("Joining server at wss://%s/%s..." % [server_url, server_port])
	connect_to_server()
	
func _on_port_input_text_changed(new_text: String) -> void:
	server_port = new_text

func _on_ip_input_text_changed(new_text: String) -> void:
	server_url = new_text

func connect_to_server():
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_client("wss://%s/%s" % [server_url, server_port])
	multiplayer.multiplayer_peer = peer

func _on_connected():
	if is_navigating:
		return
	is_navigating = true
	navigate_to_game_scene()

func _on_connection_failed():
	pass
	
func _on_disconnected():
	pass

func navigate_to_game_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
