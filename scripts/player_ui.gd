extends Node2D

var player_id = 0

func _ready() -> void:
	update_player_name(player_id)
	
	
func update_player_name(player_name):
	var player_value_node = $PlayerName/Value
	player_value_node.clear()
	player_value_node.text = str(player_name)
