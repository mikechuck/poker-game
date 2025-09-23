extends Node2D

@export var seat_select_button: PackedScene = preload("res://scenes/UI/seat_button.tscn")

var player_data = null

func _ready() -> void:
	pass
	
func set_player_data(new_player_data):
	player_data = new_player_data
	var player_value_node = $PlayerName/Value
	player_value_node.clear()
	player_value_node.append_text(str(player_data.id))
	
