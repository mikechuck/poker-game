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
@onready var game_code_container_node = $GameCodeContainer
@onready var game_code_node: RichTextLabel = $GameCodeContainer/Value
@onready var friend_code_node: RichTextLabel = $AccountDetails/Account/FriendCode/Value

@export var show_data: bool = true
@export var logout_behavior_leave_game = false


func _ready() -> void:
	if (get_tree().current_scene.name == "Game"):
		account_details_container.visible = false
		if (DataStore.game_code):
			game_code_container_node.visible = true
			game_code_node.text = DataStore.game_code
		else:
			game_code_container_node.visible = false
	else:
		account_details_container.visible = true
		game_code_container_node.visible = false
	
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
	ClientManager.disconnect_from_server()
		
	if (logout_behavior_leave_game):
		game_code_container_node.visible = false
		game_code_node.text = ""
		NavigationManager.navigate_to_main()
	else:
		AuthManager.logout()
	
