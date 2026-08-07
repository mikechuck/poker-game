extends Control
class_name AccountSection

@onready var player_name: RichTextLabel = $MarginContainer/PlayerCard/Name
@onready var hands_played: RichTextLabel = $MarginContainer/PlayerCard/HandsPlayed/Value
@onready var hands_won: RichTextLabel = $MarginContainer/PlayerCard/HandsWon/Value
@onready var player_card_background: Sprite2D = $MarginContainer/PlayerCard/DetailsCard

func display_account_data(data: Contracts.AccountRecord):
	var player_color: String = data.playerColor
	Log.message("account color: %s" % Color(player_color))
	player_card_background.modulate = Color(player_color)
	player_name.text = data.playerName
	hands_played.text = str(data.handsPlayed)
	hands_won.text = str(data.handsWon)
	
