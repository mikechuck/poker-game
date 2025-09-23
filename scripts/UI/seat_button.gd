extends Node2D

@export var seat_number = 0
var button_node

func _ready():
	add_to_group("seats")
	pass

func set_seat_visible(is_visible: bool):
	$SeatButton.visible = is_visible
