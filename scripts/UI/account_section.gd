extends Control
class_name AccountSection

var client_manager: ClientManager
var server_manager: ServerManager

@onready var player_name: RichTextLabel = $MarginContainer/Account/MarginContainer/Name
@onready var hands_played: Control = $MarginContainer/Account/HandsPlayed
@onready var hands_played_value: RichTextLabel = $MarginContainer/Account/HandsPlayed/Value
@onready var hands_won: Control = $MarginContainer/Account/HandsWon
@onready var hands_won_value: RichTextLabel = $MarginContainer/Account/HandsWon/Value
@onready var player_card_background: Sprite2D = $MarginContainer/Account/ProfilePicture

@export var show_data: bool = true
@export var logout_behavior_leave_game = false


func _ready() -> void:
	Log.message("Account section ready")
	if (show_data):
		hands_played.visible = true
		hands_won.visible = true
	else: 
		hands_played.visible = false
		hands_won.visible = false
		
	if (DataStore.account_data):
		display_account_data(DataStore.account_data)
		
	if (get_tree().root.find_child("ClientManager")):
		client_manager = get_tree().root.get_node("ClientManager")
	if (get_tree().root.find_child("ServerManager")):
		server_manager = get_tree().root.get_node("ServerManager")


func display_account_data(data: Contracts.AccountRecord):
	var player_color: String = data.playerColor
	Log.message("player_card_background: %s" % player_card_background)
	player_card_background.modulate = Color(player_color)
	player_name.text = data.playerName
	hands_played_value.text = str(data.handsPlayed)
	hands_won_value.text = str(data.handsWon)


func _on_logout_button_pressed() -> void:
	if (client_manager):
		client_manager.disconnect_from_server()
		
	if (logout_behavior_leave_game):
		NavigationManager.navigate_to_main()
	else:
		AuthManager.logout()
	
