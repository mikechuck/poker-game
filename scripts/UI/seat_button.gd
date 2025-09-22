extends Node2D

var seat_number = 0
var button_node

func _ready():
	#button_node = $SeatButton/SelectSeatButton
	pass

func set_seat_number(number):
	seat_number = number
