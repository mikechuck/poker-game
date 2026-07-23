extends Node

@onready var auth_manager =  get_tree().current_scene.get_node("AuthManager")
@onready var _is_server = OS.has_feature("server")
@onready var _is_landing_scene = get_tree().current_scene.name == "Landing"
@onready var _is_main_scene = get_tree().current_scene.name == "Main"
@onready var _is_game_scene = get_tree().current_scene.name == "Game"

func _ready() -> void:
	Log.message("Initializing scene %s" % get_tree().current_scene.name)
	
	if _is_server and !_is_game_scene:
		navigate_to_game_scene()
		
func navigate_to_main():
	Log.message("Navigating to Main")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")
	
func navigate_to_landing():
	Log.message("Navigating to Landing")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/landing.tscn")
	
func navigate_to_game_scene() -> void:
	Log.message("Navigating to Game")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/game.tscn")

func navigate_to_login():
	var login_url = "%s/login?client_id=%s&response_type=code&scope=email+openid&redirect_uri=%s" % [auth_manager.LOGIN_URL, auth_manager.CLIENT_ID, auth_manager.REDIRECT_URI]
	var eval_string: String = "window.location.href = '" + login_url + "';"
	JavaScriptBridge.eval(eval_string)
