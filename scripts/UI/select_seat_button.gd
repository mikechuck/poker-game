extends Button
class_name SeatSelectButton

var game_manager: GameSceneManager
var server_manager: ServerManager

func _ready() -> void:
	game_manager = get_tree().root.get_node("Game/GameManager")
	server_manager = get_tree().root.get_node("Game/ServerManager")

func _on_pressed() -> void:
	var seat_button_node: SeatButton = get_parent()
	server_manager.request_seat.rpc_id(1, seat_button_node.seat_number)
