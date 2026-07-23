extends HBoxContainer
class_name GameDetails

@onready var GAME_ID_NODE = $GameId
@onready var STATUS_NODE = $Status
@onready var BUY_IN_NODE = $BuyIn
@onready var CHIP_RATIO_NODE = $ChipRatio
@onready var HANDS_NODE = $Hands
@onready var JOIN_BUTTON_NODE = $JoinButton

func set_details(game_details):
	GAME_ID_NODE.text = "test"
	Log.message("setting game row with details: %s" % game_details)
