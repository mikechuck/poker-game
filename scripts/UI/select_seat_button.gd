extends Button

var game_manager
var server_manager

func _ready() -> void:
	game_manager = get_tree().root.get_node("Root/GameManager")
	server_manager = get_tree().root.get_node("Root/ServerManager")

func _on_pressed() -> void:
	var seat_button_node = get_parent()
	server_manager.request_seat.rpc_id(1, seat_button_node.seat_number)
