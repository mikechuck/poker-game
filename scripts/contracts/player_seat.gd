extends Node
class_name PlayerSeat

var pos: Vector2
var player_id: int = 0
var player_node: Node2D
var hole_cards: Array[CardData] = []

func to_dict() -> Dictionary:
	return {
		"pos": pos,
		"player_id": player_id,
		"player_node": player_node,
		"hole_cards": hole_cards
	}

static func from_dict(dict) -> PlayerSeat:
	var instance = PlayerSeat.new()
	instance.player_id = dict.get("player_id")
	instance.player_node = dict.get("player_node")
	
	var cards: Array[CardData] = []
	for card in dict.get("hole_cards"):
		cards.append(CardData.from_dict(card))
	instance.hole_cards = cards
	
	return instance
