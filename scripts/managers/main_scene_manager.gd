extends Node
class_name MainSceneManager

@onready var debug_output_node: Node = $DebugOutput
@onready var game_code_input_node: Node = $Content/Menu/MarginContainer/VBoxContainer/JoinGameMenu/GameCodeInput
@onready var account_section: AccountSection = $Content/AccountSection
@onready var games_list_container: GameDetailsContainer = $Content/GamesList
@onready var loading_screen: Control = $Loading
@onready var main_content: Control = $Content

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
		main_content.visible = true
		loading_screen.visible = false
	
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)


func join_game(game_id: String) -> void:
	Log.message("Joining game code: %s" % game_id)
	var game_record: Contracts.GameRecord = await HttpRequestsManager.get_game(game_id)
	if (game_record != null):
		if (game_record.gameStatus == Contracts.GameStatus.ACTIVE):
			var join_token: String = await HttpRequestsManager.join_game(game_id)
			connect_to_server(game_record.port, join_token, game_id)
		else:
			Log.message("Game not active")
	else:
		Log.message("Error getting game status")
		

func connect_to_server(port: int, join_token: String, game_id: String):
	Log.message("Connecting to game %s..." % _game_code)
	var connection_url: String = "wss://%s/game/%s?joinToken=%s&gameId=%s" % [AuthManager.BASE_URL, port, join_token, game_id]
	var max_retries: int = 3
	
	for attempt in range(max_retries):
		multiplayer.multiplayer_peer = null
		var peer:= WebSocketMultiplayerPeer.new()
		var err := peer.create_client(connection_url)
		if err == OK:
			multiplayer.multiplayer_peer = peer
			break;
		else:
			# Short delay before the next attempt
			if attempt < max_retries - 1:
				await get_tree().create_timer(0.2).timeout
		

func _on_connected():
	Log.message("Connected to game!")
	NavigationManager.navigate_to_game_scene()


func _on_connection_failed():
	Log.message("Connection to server failed.")

	
func _on_disconnected():
	Log.message("Disconnected from server.")
