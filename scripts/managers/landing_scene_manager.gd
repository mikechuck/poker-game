extends Control

@onready var auth_manager = $AuthManager
		
func _on_login_button_pressed() -> void:
	if OS.has_feature("web"):
		auth_manager.navigate_to_login()
	else:
		print("Can't redirect to login url, user is not on web environment")
