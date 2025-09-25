extends Button

var game_manager

func _ready() -> void:
	game_manager = get_parent().get_parent().get_parent().get_parent().get_node("GameManager")
	

func _on_pressed() -> void:
	var seat_button_node = get_parent()
	print("Seat number pressed: %s" % [seat_button_node.seat_number])
	game_manager.client_request_seat.rpc_id(1, seat_button_node.seat_number)
