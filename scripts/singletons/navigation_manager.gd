extends Node

func _ready() -> void:
	var isServer: bool = OS.has_feature("server")
	var isLandingScene: bool = get_tree().current_scene.name == "Landing"
	var isMainScene: bool = get_tree().current_scene.name == "Main"
	var isGameScene: bool = get_tree().current_scene.name == "Game"
	
	Log.write("Initializing scene %s" % get_tree().current_scene.name)
	
	if isServer and !isGameScene:
		navigate_to_game_scene()
		
func navigate_to_main():
	Log.write("Navigating to Main")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")
	
func navigate_to_landing():
	Log.write("Navigating to Landing")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/landing.tscn")
	
func navigate_to_game_scene() -> void:
	Log.write("Navigating to Game")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/game.tscn")
