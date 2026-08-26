extends HBoxContainer
class_name GameDetails

@onready var main_scene_manager: MainSceneManager = get_tree().current_scene

@onready var GAME_ID_NODE = $GameId
@onready var STATUS_NODE = $Status
@onready var PLAYERS_NODE = $Players
@onready var PRIVACY_NODE = $Privacy
@onready var BUY_IN_NODE = $BuyIn
@onready var CHIP_RATIO_NODE = $ChipRatio
@onready var BLIND_VALUE_NODE = $Blind
@onready var HANDS_NODE = $Hands
@onready var JOIN_BUTTON_NODE = $JoinButton

# Todo: make it so we can crate a new game inline in this table, not a separate section
@export var row_type: int = 1

var game_id: String = ""

func set_details(game_details: Contracts.GameRecord):
	game_id = game_details.gameId
	var gameStatus: String = Contracts.GameStatus.find_key(game_details.gameStatus)
	var gamePrivacy: String = Contracts.GamePrivacy.find_key(game_details.gamePrivacy)
	GAME_ID_NODE.text = "[font_size=12]%s[/font_size]" % game_details.gameId
	STATUS_NODE.text = "[font_size=12]%s[/font_size]" % gameStatus.to_pascal_case()
	PLAYERS_NODE.text = "[font_size=12]%s[/font_size]" % len(game_details.connectedPlayers())
	PRIVACY_NODE.text = "[font_size=12]%s[/font_size]" % gamePrivacy.to_pascal_case()
	BUY_IN_NODE.text = "[font_size=12]%s[/font_size]" % str(game_details.buyInChips)
	CHIP_RATIO_NODE.text = "[font_size=12]%s:$1[/font_size]" % str(game_details.chipRatio)
	HANDS_NODE.text = "[font_size=12]%s[/font_size]" % str(game_details.handsPlayed)
	BLIND_VALUE_NODE.text = "[font_size=12]%s[/font_size]" % str(game_details.blindChips)
	
	if (game_details.gameStatus == Contracts.GameStatus.STARTING):
		JOIN_BUTTON_NODE.disabled = true
		JOIN_BUTTON_NODE.mouse_default_cursor_shape = 0
		STATUS_NODE.modulate = Color.WEB_GREEN
	elif (game_details.gameStatus == Contracts.GameStatus.ACTIVE):
		JOIN_BUTTON_NODE.disabled = false
		JOIN_BUTTON_NODE.mouse_default_cursor_shape = 2
		STATUS_NODE.modulate = Color.WEB_GREEN
	else:
		JOIN_BUTTON_NODE.disabled = true
		JOIN_BUTTON_NODE.mouse_default_cursor_shape = 0
		STATUS_NODE.modulate = "#ffffff"


func _on_join_button_pressed() -> void:
	main_scene_manager.join_game(game_id)
