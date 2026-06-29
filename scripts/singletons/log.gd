extends Node

var logger_name = "Client"

func _init() -> void:
	if OS.has_feature("server"):
		logger_name = "Server"

func write(log_text: String) -> void:
	var scene_name = get_tree().current_scene.name
	print("[%s] [%s] - %s" % [logger_name, scene_name, log_text])
