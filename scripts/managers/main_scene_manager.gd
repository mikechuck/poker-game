extends Node

@onready var debug_output_node = $DebugOutput
@onready var game_code_input_node = $Menu/JoinGame/GameCodeInput
@onready var account_section = $AccountSection
@onready var auth_manager =  get_tree().current_scene.get_node("AuthManager")
@onready var http_request_manager =  get_tree().current_scene.get_node("HttpRequests")

var _game_code = ""

func _ready() -> void:
	if (OS.has_feature("server")):
		NavigationManager.navigate_to_game_scene()
	
	# Should have auth by now, grab their account data on load
	http_request_manager.get_account_data(func(response_code, data):
		if (response_code == 200):
			auth_manager.PLAYER_DATA = data
			account_section.display_account_data(data)
	)
	
	### TODO add loading screen until we get back our auth data
	
	### TODO add this back in when we have a "games history" view
	# Grab list of the users games to display in the menu
	#http_request_manager.get_games(func(response_code, data):
		#Log.message("Got response from GetGames endpoint! Response code: %s" % response_code)
	#)
	
	
	
	# If not the server, then we should bounce the user the landing if they don't have
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
	
func wait_for_game_creation(game_id: String):
	http_request_manager.get_game(game_id, func(response_code, data):
		if (response_code == 200):
			if (data["gameStatus"] == Globals.Enums.GameStatus.STARTED):
				Log.message("Joining game...")
				connect_to_server(data["port"])
			else:
				await get_tree().create_timer(3.0).timeout
				wait_for_game_creation(game_id)
		else:
			Log.message("Error getting game status")
	)

func _on_create_game_button_pressed() -> void:
	Log.message("Creating game...")
	http_request_manager.create_game(func(response_code, data):
		if (response_code == 202 or response_code == 200):
			var game_id = data["gameId"]
			if (game_id):
				wait_for_game_creation(game_id)
	)

func _on_join_game_button_pressed() -> void:
	Log.message("Joining game code: %s" % _game_code)
	http_request_manager.get_game(_game_code, func(response_code, data):
		if (response_code == 200):
			if (data["gameStatus"] == Globals.Enums.GameStatus.STARTED):
				connect_to_server(data["port"])
			else:
				Log.message("Game not active")
		else:
			Log.message("Error getting game status")
	)

func _on_game_code_input_text_changed(game_code: String) -> void:
	_game_code = game_code

func connect_to_server(port):
	Log.message("Connecting to game %s..." % _game_code)
	var connection_url = "wss://%s/game/%s" % [auth_manager.BASE_URL, int(port)]
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_client(connection_url)
	multiplayer.multiplayer_peer = peer
	
func _on_connected():
	Log.message("Connected to game!")
	http_request_manager.authenticate_game_player(_game_code, multiplayer.get_unique_id(), func(response_code, data):
		if (response_code == 200):
			if (data["gameStatus"] == Globals.Enums.GameStatus.STARTED):
				connect_to_server(data["port"])
			else:
				Log.message("Game not active")
		else:
			Log.message("Error getting game status")
	)
	NavigationManager.navigate_to_game_scene()

func _on_connection_failed():
	Log.message("Connection to server failed.")
	
func _on_disconnected():
	Log.message("Disconnected from server.")
