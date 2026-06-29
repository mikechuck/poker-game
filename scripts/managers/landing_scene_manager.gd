extends Control

@onready var auth_manager =  get_tree().current_scene.get_node("AuthManager")

func _ready() -> void:
	pass
		
func _on_login_button_pressed() -> void:
	if OS.has_feature("web"):
		NavigationManager.navigate_to_login()
	else:
		Log.write("Can't redirect to login url, user is not on web environment")
