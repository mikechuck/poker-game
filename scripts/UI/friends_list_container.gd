extends Control
class_name FriendsListContainer

const FRIEND_DETAILS_SCENE = preload("res://scenes/UI/friend_details.tscn")

@onready var main_scene_manager: MainSceneManager = get_tree().current_scene
@onready var no_friends_container_node = $MarginContainer/MarginContainer/Table/NoRecordsContainer
@onready var scroll_container = $MarginContainer/MarginContainer/Table/ScrollContainer
@onready var friend_details_container_node = $MarginContainer/MarginContainer/Table/ScrollContainer/FriendDetailsContainer

# Join game nodes
@onready var AddFriendCodeNode = $MarginContainer/MarginContainer/Table/HBoxContainer/FriendCodeInput

var _friend_details_nodes: Array[Node] = []
var _add_friend_code: String = ""


func _ready():
	# Grab games list on an interval
	var timer: Timer = Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(get_friends_list)
	add_child(timer)
	get_friends_list()

func get_friends_list() -> void:
	var friends_list: Array[Contracts.RelationshipRecord] = await HttpRequestsManager.get_friends()
	#friends_list = []
	if (friends_list != null):
		set_friends_list(friends_list)


func set_friends_list(friends_list: Array[Contracts.RelationshipRecord]):
	# First remove rows that are no longer in the list
	var friend_rows: Array[Node] = friend_details_container_node.get_children()
	for friend_row: FriendDetails in friend_rows:
		var delete_row = true
		for friend: Contracts.RelationshipRecord in friends_list:
			if friend_row.friend_account_id == friend.peerAccountId:
				friend_row.set_details(friend)
				delete_row = false
		if delete_row:
			if is_instance_valid(friend_row):
				friend_row.queue_free()

	# Then create rows for games that don't have rows yet
	for friend: Contracts.RelationshipRecord in friends_list:
		var create_new_row = true
		for details_row: FriendDetails in friend_rows:
			if (friend.peerAccountId == details_row.friend_account_id):
				create_new_row = false
		if create_new_row:
			var friend_details_instance: FriendDetails = FRIEND_DETAILS_SCENE.instantiate()
			friend_details_container_node.add_child(friend_details_instance)
			friend_details_instance.set_details(friend)
	
	if (len(friends_list) > 0):
		no_friends_container_node.visible = false
		scroll_container.visible = true
	else:
		no_friends_container_node.visible = true
		scroll_container.visible = false
