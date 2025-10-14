extends Node
class_name CardData

var id: String
var number: int
var value: String
var suit: String

func clone() -> CardData:
	var card_clone = CardData.new()
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
	var instance = CardData.new()
	instance.id = dict.get("id")
	instance.number = dict.get("number")
	instance.value = dict.get("value")
	instance.suit = dict.get("suit")
	return instance
