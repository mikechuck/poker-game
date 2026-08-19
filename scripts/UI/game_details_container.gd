extends Control
class_name GameDetailsContainer

const GAME_DETAILS_SCENE = preload("res://scenes/UI/game_details.tscn")

@onready var main_scene_manager: MainSceneManager = get_tree().current_scene
@onready var no_games_container_node = $MarginContainer/MarginContainer/Table/NoRecordsContainer
@onready var scroll_container = $MarginContainer/MarginContainer/Table/MarginContainer/ScrollContainer
@onready var game_details_container_node = $MarginContainer/MarginContainer/Table/MarginContainer/ScrollContainer/GameDetailsContainer

# Create game nodes
@onready var blind_value_node = $MarginContainer/MarginContainer/Table/GameControls/Blind
@onready var privacy_value_node = $MarginContainer/MarginContainer/Table/GameControls/Privacy
@onready var buy_in_value_node = $MarginContainer/MarginContainer/Table/GameControls/BuyIn
@onready var chips_ratio_value_node = $MarginContainer/MarginContainer/Table/GameControls/ChipRatio
@onready var create_game_button_node = $MarginContainer/MarginContainer/Table/GameControls/CreateButton

# Join game nodes
@onready var join_game_id = $MarginContainer/MarginContainer/Table/GameControls/GameCodeInput

var _games_details_nodes: Array[Node] = []
var _join_game_code: String = ""
var has_active_game: bool = false


func _ready():
	# Grab games list on an interval
	var timer: Timer = Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(get_games_list)
	add_child(timer)
	get_games_list()


func get_games_list() -> void:
	var games_list: Array[Contracts.GameRecord] = await HttpRequestsManager.get_games()
	if (games_list != null):
		set_games_list(games_list)


func set_games_list(games_list: Array[Contracts.GameRecord]):
	has_active_game = false
	
	# First remove rows that are no longer in the list
	var game_rows: Array[Node] = game_details_container_node.get_children()
	for game_row: GameDetails in game_rows:
		var delete_row = true
		for game: Contracts.GameRecord in games_list:
			if game_row.game_id == game.gameId:
				game_row.set_details(game)
				delete_row = false
		if delete_row:
			if is_instance_valid(game_row):
				game_row.queue_free()

	# Then create rows for games that don't have rows yet
	for game: Contracts.GameRecord in games_list:
		var create_new_row = true
		for details_row: GameDetails in game_rows:
			if (game.gameId == details_row.game_id):
				create_new_row = false
		if create_new_row:
			var game_details_instance: GameDetails = GAME_DETAILS_SCENE.instantiate()
			game_details_container_node.add_child(game_details_instance)
			game_details_instance.set_details(game)
		if (game.gameStatus != Contracts.GameStatus.ENDED):
			has_active_game = true
	
	if (has_active_game):
		blind_value_node.editable = false
		buy_in_value_node.editable = false
		chips_ratio_value_node.editable = false
		privacy_value_node.disabled = true
		create_game_button_node.disabled = true
		create_game_button_node.mouse_default_cursor_shape = 0
	else:
		blind_value_node.editable = true
		buy_in_value_node.editable = true
		chips_ratio_value_node.editable = true
		privacy_value_node.disabled = false
		create_game_button_node.disabled = false
		create_game_button_node.mouse_default_cursor_shape = 2
	
	if (len(games_list) > 0):
		no_games_container_node.visible = false
		scroll_container.visible = true
	else:
		no_games_container_node.visible = true
		scroll_container.visible = false
		

func _on_game_code_input_text_changed(game_code: String) -> void:
	_join_game_code = game_code
	
	
func _on_join_game_button_pressed() -> void:
	main_scene_manager.join_game(_join_game_code)


func _on_create_button_pressed() -> void:
	Log.message("Creating game...")
	var blind_value: float = blind_value_node.value
	var buy_in: float = buy_in_value_node.value
	var chip_ratio: float = chips_ratio_value_node.value
	var privacy: int = privacy_value_node.selected
	var game_record: Contracts.GameRecord = await HttpRequestsManager.create_game(int(blind_value), int(buy_in), int(chip_ratio), privacy)
	if (game_record != null):
		get_games_list()
