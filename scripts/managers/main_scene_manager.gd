extends Node

@onready var debug_output_node = $DebugOutput
@onready var url_input_node = $Menu/JoinGame/IpInput
@onready var port_input_node = $Menu/JoinGame/PortInput
@onready var account_section = $AccountSection
@onready var auth_manager =  get_tree().current_scene.get_node("AuthManager")
@onready var http_request_manager =  get_tree().current_scene.get_node("HttpRequests")

const SERVER_URL = "server.mikechucktingle.net"
var _server_port = "12001"
var _game_code = ""

func _ready() -> void:
	if (OS.has_feature("server")):
		NavigationManager.navigate_to_game_scene()
	
	# Should have auth by now, grab their account data on load
	http_request_manager.get_account_data(func(response_code, data):
		if (response_code == 200):
			account_section.display_account_data(data)
	)
		
	# If not the server, then we should bounce the user the landing if they don't have
	port_input_node.text = _server_port
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
		
func add_debug_line(text: String) -> void:
	debug_output_node.text += text + "\n"
	Log.write(text)
	
func wait_for_game_creation(game_id: String):
	http_request_manager.get_game(game_id, func(response_code, data):
		if (response_code == 200):
			if (data["gameStatus"] == "ACTIVE"):
				Log.write("Game is active!")
				connect_to_server(data["port"])
			else:
				await get_tree().create_timer(3.0).timeout
				wait_for_game_creation(game_id)
		else:
			Log.write("Error getting game status")
	)

func _on_create_game_button_pressed() -> void:
	Log.write("Create button pressed, calling API")
	http_request_manager.create_game(func(response_code, data):
		if (response_code == 202 or response_code == 200):
			var game_id = data["gameId"]
			if (game_id):
				wait_for_game_creation(game_id)
			else:
				Log.write("Bad response from create game, not polling for active state")
		else:
			Log.write("Bad response from create game, not polling for active state")
	)
	# Call our orchestration API to request new server startup
	# On response, set server_url and server_port and connect to the server

func _on_join_game_button_pressed() -> void:
	Log.write("Joining game code: %s" % _game_code)
	
	http_request_manager.get_game(_game_code, func(response_code, data):
		if (response_code == 200):
			if (data["gameStatus"] == "STARTED"):
				Log.write("Game is active!")
				#connect_to_server(data["port"])
			else:
				Log.write("Game not active")
		else:
			Log.write("Error getting game status")
	)
	#connect_to_server(_server_port)

func _on_game_code_input_text_changed(game_code: String) -> void:
	_game_code = game_code

func connect_to_server(port: String):
	var connection_url = "wss://%s/game/%s" % [SERVER_URL, port]
	Log.write("Joining server at %s..." % connection_url)
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_client(connection_url)
	multiplayer.multiplayer_peer = peer
	
func _on_connected():
	Log.write("Successfully connected to server!")
	NavigationManager.navigate_to_game_scene()

func _on_connection_failed():
	Log.write("Connection to server failed.")
	
func _on_disconnected():
	Log.write("Disconnected from server.")
