extends Control
class_name AccountSection

var server_manager: ServerManager

@onready var account_details_container: MarginContainer = $AccountDetails
@onready var player_name: RichTextLabel = $AccountDetails/Account/MarginContainer/Name
@onready var hands_played: Control = $AccountDetails/Account/HandsPlayed
@onready var hands_played_value: RichTextLabel = $AccountDetails/Account/HandsPlayed/Value
@onready var hands_won: Control = $AccountDetails/Account/HandsWon
@onready var hands_won_value: RichTextLabel = $AccountDetails/Account/HandsWon/Value
@onready var player_card_background: Sprite2D = $AccountDetails/Account/ProfilePicture
@onready var friend_code_node: RichTextLabel = $AccountDetails/Account/FriendCode/Value

@export var show_data: bool = true
@export var logout_behavior_leave_game = false


func _ready() -> void:
	if (show_data):
		hands_played.visible = true
		hands_won.visible = true
	else: 
		hands_played.visible = false
		hands_won.visible = false
		
	if (DataStore.account_data):
		display_account_data(DataStore.account_data)
		
	if (get_tree().root.find_child("ServerManager")):
		server_manager = get_tree().root.get_node("ServerManager")


func display_account_data(data: Contracts.AccountRecord):
	var player_color: String = data.playerColor
	player_card_background.modulate = Color(player_color)
	player_name.text = data.playerName
	hands_played_value.text = str(data.handsPlayed)
	hands_won_value.text = str(data.handsWon)
	friend_code_node.text = str(data.friendCode)
	
func _on_logout_button_pressed() -> void:
	AuthManager.logout()
