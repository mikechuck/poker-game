extends Node2D

var player_data = null

func _ready() -> void:
	pass
	
func set_player_data(new_player_data):
	player_data = new_player_data
	var player_value_node = $PlayerName/Value
	player_value_node.clear()
	player_value_node.append_text(str(player_data.id))
	
