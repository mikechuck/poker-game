extends HBoxContainer
class_name FriendDetails

@onready var main_scene_manager: MainSceneManager = get_tree().current_scene
@onready var friends_list_container_node: FriendsListContainer = get_tree().current_scene.get_node("Content/FriendsList")

@onready var PLAYER_COLOR_NODE: ColorRect = $PlayerColor
@onready var PLAYER_NAME_NODE = $NameContainer/Name
@onready var STATUS_NODE = $Status
@onready var ACCEPT_BUTTON_NODE = $AcceptButton
@onready var REJECT_BUTTON_NODE = $RejectButton

var friend_account_id: String = ""

func set_details(friend_details: Contracts.FriendRecord):
	var friendStatus: String = Contracts.FriendStatus.find_key(friend_details.friendStatus)
	friend_account_id = friend_details.peerAccountId
	PLAYER_NAME_NODE.text = "[font_size=16]%s[/font_size]" % friend_details.peerPlayerName
	PLAYER_COLOR_NODE.modulate = friend_details.peerPlayerColor
	STATUS_NODE.visible = false
	ACCEPT_BUTTON_NODE.visible = false
	REJECT_BUTTON_NODE.visible = false
	
	if (friend_details.friendStatus == Contracts.FriendStatus.INCOMING_PENDING):
		ACCEPT_BUTTON_NODE.visible = true
		REJECT_BUTTON_NODE.visible = true
	elif (friend_details.friendStatus == Contracts.FriendStatus.OUTGOING_PENDING):
		STATUS_NODE.visible = true
		

func set_buttons_loading(is_loading: bool) -> void:
	if (is_loading):
		ACCEPT_BUTTON_NODE.disabled = true
		ACCEPT_BUTTON_NODE.modulate = "#17c3b264"
		ACCEPT_BUTTON_NODE.mouse_default_cursor_shape = 0
		REJECT_BUTTON_NODE.disabled = true
		REJECT_BUTTON_NODE.modulate = "#fe6d7364"
		REJECT_BUTTON_NODE.mouse_default_cursor_shape = 0
	else:
		ACCEPT_BUTTON_NODE.disabled = false
		ACCEPT_BUTTON_NODE.modulate = "#17c3b2"
		ACCEPT_BUTTON_NODE.mouse_default_cursor_shape = 2
		REJECT_BUTTON_NODE.disabled = false
		REJECT_BUTTON_NODE.modulate = "#fe6d73"
		REJECT_BUTTON_NODE.mouse_default_cursor_shape = 2


func _on_accept_button_pressed() -> void:
	set_buttons_loading(true)
	var response_code: int = await HttpRequestsManager.accept_friend_request(friend_account_id)
	if (response_code == 200):
		friends_list_container_node.get_friends_list()
		Log.toast("Friend request accepted!")
	else:
		set_buttons_loading(false)
		Log.toast("Failed to accept friend request")


func _on_reject_button_pressed() -> void:
	set_buttons_loading(true)
	var response_code: int = await HttpRequestsManager.reject_friend_request(friend_account_id)
	if (response_code == 200):
		friends_list_container_node.get_friends_list()
		Log.toast("Friend request rejected")
	else:
		set_buttons_loading(false)
		Log.toast("Failed to accept friend request")
