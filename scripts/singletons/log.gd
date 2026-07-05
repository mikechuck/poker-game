extends Node

var logger_name = "Client"

func _init() -> void:
	if OS.has_feature("server"):
		logger_name = "Server"

func message(log_text: String, notification_icon: String = "🤖", write_to_notifications: bool = true) -> void:
	var scene_name = get_tree().current_scene.name
	var message = "[%s] [%s] MESSAGE - %s" % [logger_name, scene_name, log_text]
	print(message)
	if (write_to_notifications):
		NotificationManager.write(message, notification_icon)
		
func warning(log_text: String, notification_icon: String = "⚠️", write_to_notifications: bool = true) -> void:
	var scene_name = get_tree().current_scene.name
	var message = "[%s] [%s] WARNING - %s" % [logger_name, scene_name, log_text]
	print(message)
	if (write_to_notifications):
		NotificationManager.write(message, notification_icon, true)

func error(log_text: String, notification_icon: String = "⛔", write_to_notifications: bool = true) -> void:
	var scene_name = get_tree().current_scene.name
	var message = "[%s] [%s] ERROR - %s" % [logger_name, scene_name, log_text]
	print(message)
	if (write_to_notifications):
		NotificationManager.write(message, notification_icon, false, true)
