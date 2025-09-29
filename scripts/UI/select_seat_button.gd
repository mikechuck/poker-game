extends Button

var game_manager
var server_manager

func _ready() -> void:
	game_manager = get_parent().get_parent().get_parent().get_parent().get_node("GameManager")
	server_manager = get_parent().get_parent().get_parent().get_parent().get_node("ServerManager")

func _on_pressed() -> void:
	var seat_button_node = get_parent()
	print("Seat number pressed: %s" % [seat_button_node.seat_number])
	server_manager.request_seat.rpc_id(1, seat_button_node.seat_number)
