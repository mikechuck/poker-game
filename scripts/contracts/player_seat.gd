extends Node
class_name PlayerSeat

var player_id: int = 0
var player_node: Node2D
var hole_cards: Array[CardData] = []
var is_folded: bool = false
var is_big_blind: bool = false
var is_small_blind: bool = false

func to_dict() -> Dictionary:
	var cards: Array[Dictionary] = []
	for card in hole_cards:
		cards.append(card.to_dict())
		
	return {
		"player_id": player_id,
		"player_node": player_node,
		"hole_cards": cards,
		"is_folded": is_folded,
		"is_big_blind": is_big_blind,
		"is_small_blind": is_small_blind
	}

static func from_dict(dict) -> PlayerSeat:
	var instance = PlayerSeat.new()
	instance.player_id = dict.get("player_id")
	instance.player_node = dict.get("player_node")
	instance.is_folded = dict.get("is_folded")
	instance.is_big_blind = dict.get("is_big_blind")
	instance.is_small_blind = dict.get("is_small_blind")
	
	var cards: Array[CardData] = []
	for card in dict.get("hole_cards"):
		cards.append(CardData.from_dict(card))
	instance.hole_cards = cards
	
	return instance
