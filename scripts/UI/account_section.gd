extends Control

@onready var player_name = $PlayerCard/Name
@onready var hands_played = $PlayerCard/HandsPlayed/Value
@onready var hands_won = $PlayerCard/HandsWon/Value
@onready var player_card_background = $PlayerCard/DetailsCard

func display_account_data(data):
	player_name.text = data["PlayerName"]
	hands_played.text = data["HandsPlayed"]
	hands_won.text = data["HandsWon"]
	player_card_background.modulate = Color.html(data["PlayerCardColor"])
