extends Node2D
class_name SeatButton

@export var seat_number = 0
@onready var button_node: Button = $SeatButton

func _ready():
	add_to_group("seats")
	pass

func set_seat_visible(is_visible: bool):
	button_node.visible = is_visible
