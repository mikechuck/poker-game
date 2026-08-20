extends Node

var logger_name: String = "Client"
var is_server: bool = false

func _init() -> void:
	if OS.has_feature("server"):
		logger_name = "Server"
		is_server = true

func message(log_text: Variant, notification_icon: String = "🤖", write_to_notifications: bool = true) -> void:
	var log_text_string: String = JSON.stringify(log_text)
	var scene_name = get_tree().current_scene.name
	var text: String = "[%s] [%s] MESSAGE - %s" % [logger_name, scene_name, log_text_string]
	
	# Due to the verbosity of the server binary, print err to ensure logs come through
	if is_server:
		printerr(text)
	else:
		print(text)
		
	if (write_to_notifications):
		NotificationManager.write(text, notification_icon)
		
func warning(log_text: Variant, notification_icon: String = "⚠️", write_to_notifications: bool = true) -> void:
	var log_text_string: String = JSON.stringify(log_text)
	var scene_name = get_tree().current_scene.name
	var text: String = "[%s] [%s] WARNING - %s" % [logger_name, scene_name, log_text_string]
	
	# Due to the verbosity of the server binary, print err to ensure logs come through
	if is_server:
		printerr(text)
	else:
		print(text)
	
	if (write_to_notifications):
		NotificationManager.write(text, notification_icon, true)

func error(log_text: String, notification_icon: String = "⛔", write_to_notifications: bool = true) -> void:
	var log_text_string: String = JSON.stringify(log_text)
	var scene_name = get_tree().current_scene.name
	var text: String = "[%s] [%s] ERROR - %s" % [logger_name, scene_name, log_text_string]
	printerr(text)
	if (write_to_notifications):
		NotificationManager.write(text, notification_icon, false, true)
