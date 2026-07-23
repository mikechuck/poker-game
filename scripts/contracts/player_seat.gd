extends Node
class_name PlayerSeat

var seat_index: int = 0
var player_id: int = 0
var player_node: Node2D
var is_ready: bool = false
var hole_cards: Array[CardData] = []
var hand_cash: int = 0
var bet_value: int = 0
var is_folded: bool = false
var is_big_blind: bool = false
var is_small_blind: bool = false
var sorted_hand_cards: Array[CardData] = []
var final_hand_score: int = 0

func reset_hand_data() -> void:
	hole_cards = []
	is_folded = false
	is_big_blind = false
	is_small_blind = false
	bet_value = 0
	final_hand_score = 0
	player_node = null
	is_ready = false
	
func clone() -> PlayerSeat:
	var seat_clone: PlayerSeat = PlayerSeat.new()
	seat_clone.seat_index = seat_index
	seat_clone.player_id = player_id
	seat_clone.player_node = player_node
	seat_clone.is_ready = is_ready
	seat_clone.hand_cash = hand_cash
	seat_clone.bet_value = bet_value
	seat_clone.is_folded = is_folded
	seat_clone.is_big_blind = is_big_blind
	seat_clone.is_small_blind = is_small_blind
	seat_clone.final_hand_score = final_hand_score
	for card: CardData in hole_cards:
		seat_clone.hole_cards.append(card.clone())
	for card: CardData in sorted_hand_cards:
		seat_clone.sorted_hand_cards.append(card.clone())
	return seat_clone

func to_dict() -> Dictionary:
	var cards: Array[Dictionary] = []
	for card in hole_cards:
		cards.append(card.to_dict())
		
	return {
		"seat_index": seat_index,
		"player_id": player_id,
		"player_node": player_node,
		"hole_cards": cards,
		"hand_cash": hand_cash,
		"is_folded": is_folded,
		"is_big_blind": is_big_blind,
		"is_small_blind": is_small_blind,
		"bet_value": bet_value,
		"is_ready": is_ready,
		"final_hand_score": final_hand_score
	}

static func from_dict(dict: Dictionary) -> PlayerSeat:
	var instance = PlayerSeat.new()
	if dict != {}:
		var hole_cards_array: Array[Dictionary] = dict.get("hole_cards")
		instance.seat_index = dict.get("seat_index")
		instance.player_id = dict.get("player_id")
		instance.player_node = dict.get("player_node")
		instance.is_folded = dict.get("is_folded")
		instance.is_big_blind = dict.get("is_big_blind")
		instance.is_small_blind = dict.get("is_small_blind")
		instance.hole_cards = Serializer.deserialize_cards(hole_cards_array)
		instance.hand_cash = dict.get("hand_cash")
		instance.bet_value = dict.get("bet_value")
		instance.is_ready = dict.get("is_ready")
		instance.final_hand_score = dict.get("final_hand_score")
	
	return instance
