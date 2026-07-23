extends Node
class_name MainSceneManager

@onready var debug_output_node: Node = $DebugOutput
@onready var game_code_input_node: Node = $Content/Menu/MarginContainer/VBoxContainer/HBoxContainer/GameCodeInput
@onready var account_section: Node = $Content/AccountSection
@onready var games_list_container: Node = $Content/GamesList/MarginContainer/MarginContainer/Table/ScrollContainer/GameDetailsContainer
@onready var loading_screen: Node = $Loading
@onready var main_content: Node = $Content
@onready var auth_manager: AuthManager =  get_tree().current_scene.get_node("AuthManager")
@onready var http_request_manager: HttpRequestsManager =  get_tree().current_scene.get_node("HttpRequests")

var _game_code = ""

func _ready() -> void:
	if (OS.has_feature("server")):
		NavigationManager.navigate_to_game_scene()
	
	# Should have auth by now, grab their account data on load
	http_request_manager.get_account_data(func(response_code, data):
		if (response_code == 200):
			DataStore.account_data = data
			account_section.display_account_data(data)
			
			http_request_manager.get_games(func(response_code, data):
				if (response_code == 200):
					games_list_container.create_games_list(data["games"])
					loading_screen.visible = false
					main_content.visible = true
			)
	)
	
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
