extends Node
class_name MainSceneManager

@onready var debug_output_node: Node = $DebugOutput
@onready var game_code_input_node: Node = $Content/Menu/MarginContainer/VBoxContainer/HBoxContainer/GameCodeInput
@onready var account_section: AccountSection = $Content/AccountSection
@onready var games_list_container: GameDetailsContainer = $Content/GamesList/MarginContainer/MarginContainer/Table/ScrollContainer/GameDetailsContainer
@onready var loading_screen: Control = $Loading
@onready var main_content: Control = $Content
@onready var NO_GAMES_CONTAINER = $Content/GamesList/MarginContainer/MarginContainer/Table/NoRecordsContainer
@onready var GAMES_LIST_CONTAINER = $Content/GamesList/MarginContainer/MarginContainer/Table/ScrollContainer

var _game_code: String = ""

func _ready() -> void:
	main_content.visible = false
	loading_screen.visible = true
	if (OS.has_feature("server")):
		NavigationManager.navigate_to_game_scene()
	
	# Should have auth by now, grab their account data on load
	var account_record: Contracts.AccountRecord = await HttpRequestsManager.get_account_data()
	if (account_record != null):
		DataStore.account_data = account_record
		account_section.display_account_data(account_record)
		var games_list: Array[Contracts.GameRecord] = await HttpRequestsManager.get_games()
		if (games_list != null):
			if (len(games_list) > 0):
				NO_GAMES_CONTAINER.visible = false
				GAMES_LIST_CONTAINER.visible = true
				games_list_container.create_games_list(games_list)
		main_content.visible = true
		loading_screen.visible = false
	
	# If not the server, then we should bounce the user the landing if they don't have
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
	
func wait_for_game_creation(game_id: String):
	var game_record: Contracts.GameRecord = await HttpRequestsManager.get_game(game_id)
	if (game_record != null):
		if (game_record.gameStatus == Contracts.GameStatus.STARTED):
			Log.message("Joining game...")
			connect_to_server(game_record.port)
		else:
			await get_tree().create_timer(3.0).timeout
			wait_for_game_creation(game_id)
	else:
		Log.message("Error getting game status")

func _on_create_game_button_pressed() -> void:
	Log.message("Creating game...")
	var game_record: Contracts.GameRecord = await HttpRequestsManager.create_game()
	if (game_record != null):
		var game_id: String = game_record.gameId
		if (game_id):
			wait_for_game_creation(game_id)

func _on_join_game_button_pressed() -> void:
	Log.message("Joining game code: %s" % _game_code)
	var game_record: Contracts.GameRecord = await HttpRequestsManager.get_game(_game_code)
	if (game_record != null):
		if (game_record.gameStatus == Contracts.GameStatus.STARTED):
			connect_to_server(game_record.port)
		else:
			Log.message("Game not active")
	else:
		Log.message("Error getting game status")

func _on_game_code_input_text_changed(game_code: String) -> void:
	_game_code = game_code

func connect_to_server(port: int):
	Log.message("Connecting to game %s..." % _game_code)
	var connection_url: String = "wss://%s/game/%s" % [AuthManager.BASE_URL, port]
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_client(connection_url)
	multiplayer.multiplayer_peer = peer
	
func _on_connected():
	Log.message("Connected to game!")
	#var http_request_manager.authenticate_game_player(_game_code, multiplayer.get_unique_id(), func(response_code, data):
		#if (response_code == 200):
			#if (data["gameStatus"] == Contracts.GameStatus.STARTED):
				#connect_to_server(data["port"])
			#else:
				#Log.message("Game not active")
		#else:
			#Log.message("Error getting game status")
	#)
	NavigationManager.navigate_to_game_scene()

func _on_connection_failed():
	Log.message("Connection to server failed.")
	
func _on_disconnected():
	Log.message("Disconnected from server.")
