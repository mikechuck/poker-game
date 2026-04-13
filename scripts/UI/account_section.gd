extends Control

@onready var account_id = $Control/AccountId/Value
@onready var player_name = $Control/PlayerName/Value
@onready var hands_played = $Control/HandsPlayed/Value
@onready var hands_won = $Control/HandsWon/Value

func display_account_data(data):
	print("displaying account data")
	account_id.text = data["AccountId"]
	player_name.text = data["PlayerName"]
	hands_played.text = data["HandsPlayed"]
	hands_won.text = data["HandsWon"]
