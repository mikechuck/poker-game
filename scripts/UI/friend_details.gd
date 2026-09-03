extends HBoxContainer
class_name FriendDetails

@onready var main_scene_manager: MainSceneManager = get_tree().current_scene

@onready var PLAYER_COLOR_NODE: ColorRect = $PlayerColor
@onready var PLAYER_NAME_NODE = $NameContainer/Name
@onready var STATUS_NODE = $Status

var friend_account_id = ""

func set_details(friend_details: Contracts.RelationshipRecord):
	var relationshipStatus: String = Contracts.RelationshipStatus.find_key(friend_details.relationshipStatus)
	PLAYER_NAME_NODE.text = "[font_size=16]%s[/font_size]" % friend_details.peerPlayerName
	STATUS_NODE.text = "[font_size=12]%s[/font_size]" % relationshipStatus.to_pascal_case()
	PLAYER_COLOR_NODE.modulate = friend_details.peerPlayerColor
	
	#if (game_details.gameStatus == Contracts.GameStatus.STARTING):
		#JOIN_BUTTON_NODE.disabled = true
		#JOIN_BUTTON_NODE.mouse_default_cursor_shape = 0
		#STATUS_NODE.modulate = Color.WEB_GREEN
	#elif (game_details.gameStatus == Contracts.GameStatus.ACTIVE):
		#JOIN_BUTTON_NODE.disabled = false
		#JOIN_BUTTON_NODE.mouse_default_cursor_shape = 2
		#STATUS_NODE.modulate = Color.WEB_GREEN
	#else:
		#JOIN_BUTTON_NODE.disabled = true
		#JOIN_BUTTON_NODE.mouse_default_cursor_shape = 0
		#STATUS_NODE.modulate = "#ffffff"
