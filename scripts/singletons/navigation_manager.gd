extends Node

@onready var _is_server = OS.has_feature("server")
@onready var _is_landing_scene = get_tree().current_scene.name == "Landing"
@onready var _is_main_scene = get_tree().current_scene.name == "Main"
@onready var _is_game_scene = get_tree().current_scene.name == "Game"

func _ready() -> void:
	if _is_server and !_is_game_scene:
		navigate_to_game_scene()
		
func navigate_to_main():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")
	
func navigate_to_landing():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/landing.tscn")
	
func navigate_to_game_scene() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/game.tscn")

func navigate_to_login():
	var login_url = "%s/login?client_id=%s&response_type=code&scope=email+openid&redirect_uri=%s" % [AuthManager.LOGIN_URL, AuthManager.CLIENT_ID, AuthManager.REDIRECT_URI]
	var eval_string: String = "window.location.href = '" + login_url + "';"
	JavaScriptBridge.eval(eval_string)
