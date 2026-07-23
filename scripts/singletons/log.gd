extends Node

var logger_name = "Client"

func _init() -> void:
	if OS.has_feature("server"):
		logger_name = "Server"

func message(log_text: Variant, notification_icon: String = "🤖", write_to_notifications: bool = true) -> void:
	var log_text_string: String = JSON.stringify(log_text)
	var scene_name = get_tree().current_scene.name
	var message: String = "[%s] [%s] MESSAGE - %s" % [logger_name, scene_name, log_text_string]
	print(message)
	if (write_to_notifications):
		NotificationManager.write(message, notification_icon)
		
func warning(log_text: Variant, notification_icon: String = "⚠️", write_to_notifications: bool = true) -> void:
	var log_text_string: String = JSON.stringify(log_text)
	var scene_name = get_tree().current_scene.name
	var message: String = "[%s] [%s] WARNING - %s" % [logger_name, scene_name, log_text_string]
	print(message)
	if (write_to_notifications):
		NotificationManager.write(message, notification_icon, true)

func error(log_text: String, notification_icon: String = "⛔", write_to_notifications: bool = true) -> void:
	var log_text_string: String = JSON.stringify(log_text)
	var scene_name = get_tree().current_scene.name
	var message: String = "[%s] [%s] ERROR - %s" % [logger_name, scene_name, log_text_string]
	print(message)
	if (write_to_notifications):
		NotificationManager.write(message, notification_icon, false, true)
