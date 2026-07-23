extends Node
class_name CardData

var id: String
var number: int
var value: String
var suit: String

func clone() -> CardData:
	var card_clone: CardData = CardData.new()
	card_clone.id = id
	card_clone.number = number
	card_clone.value = value
	card_clone.suit = suit
	return card_clone

func to_dict() -> Dictionary:
	return {
		"id": id,
		"number": number,
		"value": value,
		"suit": suit,
	}
	
static func from_dict(dict: Dictionary) -> CardData:
	var instance: CardData = CardData.new()
	var instance_id: String = dict.get("id")
	var instance_number: int = dict.get("id")
	var instance_value: String = dict.get("value")
	var instance_suit: String = dict.get("suit")
	instance.id = instance_id
	instance.number = instance_number
	instance.value = instance_value
	instance.suit = instance_suit
	return instance
