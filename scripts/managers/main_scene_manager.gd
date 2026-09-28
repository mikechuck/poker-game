extends Node
class_name MainSceneManager

@onready var game_code_input_node: Node = $Content/Menu/MarginContainer/VBoxContainer/JoinGameMenu/GameCodeInput
@onready var account_section: AccountSection = $Content/AccountSection
@onready var games_list_container: GameDetailsContainer = $Content/GamesList
@onready var loading_screen: Control = $Loading
@onready var main_content: Control = $Content


func _ready() -> void:
	main_content.visible = false
	loading_screen.visible = true
	if (OS.has_feature("server")):
		NavigationManager.navigate_to_game_scene()
	
	# Should have auth by now, grab their account data on load
	var account_record: Contracts.AccountRecord = await HttpRequestsManager.get_account_data()
	if (account_record != null):
		DataStore.account_data = account_record
		await games_list_container.get_games_list()
		account_section.display_account_data(account_record)
		main_content.visible = true
		loading_screen.visible = false


func join_game(game_id: String) -> void:
	Log.toast("Getting game details...")
	var game_record: Contracts.GameRecord = await HttpRequestsManager.get_game(game_id)
	if (game_record != null):
		if (game_record.gameStatus == Contracts.GameStatus.ACTIVE):
			var join_token: String = await HttpRequestsManager.join_game(game_id)
			if (join_token):
				DataStore.game_data = game_record
				DataStore.join_token = join_token
				Log.toast("Connecting to server...")
				ClientManager.connect_to_server()
			else:
				Log.toast("Failed to join game")
		else:
			Log.toast("Game not active")
	else:
		Log.error("Error getting game status")
