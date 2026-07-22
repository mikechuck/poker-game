extends Control

@onready var player_name = $PlayerCard/Name
@onready var hands_played = $PlayerCard/HandsPlayed/Value
@onready var hands_won = $PlayerCard/HandsWon/Value
@onready var player_card_background = $PlayerCard/DetailsCard

func display_account_data(data):
	player_name.text = data["playerName"]
	hands_played.text = data["handsPlayed"]
	hands_won.text = data["handsWon"]
	Log.message("setting player color to %s" % data["playerColor"])
	player_card_background.modulate = Color.html(data["playerColor"]) # does this work with the string "#ff8407"?
