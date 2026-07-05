extends Node

const NOTIFICATION_CONTAINER_SCENE = preload("res://scenes/UI/notification_container.tscn")
const NOTIFICATION_ROW_SCENE = preload("res://scenes/UI/notification_row.tscn")

var _notification_container_scene;
var _notifications_node;

func _ready() -> void:
	_notification_container_scene = NOTIFICATION_CONTAINER_SCENE.instantiate()
	add_child(_notification_container_scene)
	_notifications_node = _notification_container_scene.find_child("Notifications")
	print("setup notifications node")
	
func write(message: String, icon: String = "👉", warning: bool = false, error: bool = false):
	var new_notification_row = NOTIFICATION_ROW_SCENE.instantiate()
	var text_node: RichTextLabel = new_notification_row.find_child("Text")
	var icon_node: RichTextLabel = new_notification_row.find_child("Icon")
	#
	icon_node.text = "[font_size=10]%s[/font_size]" % icon
	text_node.text = "[font_size=8]%s[/font_size]" % message
	
	if (warning):
		text_node.add_theme_color_override("default_color", Color.ORANGE)
	
	if (error):
		text_node.add_theme_color_override("default_color", Color.INDIAN_RED)
	
	if (_notifications_node):
		_notifications_node.add_child(new_notification_row)
	
