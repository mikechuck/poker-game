extends Node
class_name PlayerSeat

var pos: Vector2
var player_id: int = 0
var player_node: Node2D

func to_dict() -> Dictionary:
	return {
		"pos": pos,
		"player_id": player_id,
		"player_node": player_node
	}

static func from_dict(dict) -> PlayerSeat:
	var instance = PlayerSeat.new()
	instance.player_id = dict.get("player_id")
	instance.player_node = dict.get("player_node")
	return instance
