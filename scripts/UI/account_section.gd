extends Control
class_name AccountSection

@onready var player_name: RichTextLabel = $PlayerCard/Name
@onready var hands_played: RichTextLabel = $PlayerCard/HandsPlayed/Value
@onready var hands_won: RichTextLabel = $PlayerCard/HandsWon/Value
@onready var player_card_background: Sprite2D = $PlayerCard/DetailsCard

func display_account_data(data):
	var player_color: String = data["playerColor"]
	player_name.text = data["playerName"]
	hands_played.text = data["handsPlayed"]
	hands_won.text = data["handsWon"]
	Log.message("setting player color to %s" % data["playerColor"])
	player_card_background.modulate = Color.html(player_color) # does this work with the string "#ff8407"?
