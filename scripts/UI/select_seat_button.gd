extends Button

func _on_pressed() -> void:
	var seat_button_node = get_parent()
	print("Seat number pressed: %s" % [seat_button_node.seat_number])
