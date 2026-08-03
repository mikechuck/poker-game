extends Control
class_name AccountSection

@onready var player_name: RichTextLabel = $PlayerCard/Name
@onready var hands_played: RichTextLabel = $PlayerCard/HandsPlayed/Value
@onready var hands_won: RichTextLabel = $PlayerCard/HandsWon/Value
@onready var player_card_background: Sprite2D = $PlayerCard/DetailsCard

func display_account_data(data: Contracts.AccountRecord):
	var player_color: String = data.playerColor
	player_name.text = data.playerName
	hands_played.text = str(data.handsPlayed)
	hands_won.text = str(data.handsWon)
	player_card_background.modulate = player_color
