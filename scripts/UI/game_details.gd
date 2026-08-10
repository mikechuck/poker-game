extends HBoxContainer
class_name GameDetails

@onready var GAME_ID_NODE = $GameId
@onready var STATUS_NODE = $Status
@onready var BUY_IN_NODE = $BuyIn
@onready var CHIP_RATIO_NODE = $ChipRatio
@onready var HANDS_NODE = $Hands
@onready var JOIN_BUTTON_NODE = $JoinButton

func set_details(game_details: Contracts.GameRecord):
	var gameStatus: String = Contracts.GameStatus.find_key(game_details.gameStatus)
	GAME_ID_NODE.text = "[font_size=12]%s[/font_size]" % game_details.gameId
	STATUS_NODE.text = "[font_size=12]%s[/font_size]" % gameStatus.to_pascal_case()
	BUY_IN_NODE.text = "[font_size=12]$%s[/font_size]" % str(game_details.buyInDollars)
	CHIP_RATIO_NODE.text = "[font_size=12]%s:1[/font_size]" % str(game_details.chipRatio)
	HANDS_NODE.text = "[font_size=12]%s[/font_size]" % str(game_details.handsPlayed)
	
	if (game_details.gameStatus == Contracts.GameStatus.STARTED):
		JOIN_BUTTON_NODE.disabled = false
