extends Node
class_name CardData

var id: String
var number: int
var value: String
var suit: String
var show: bool = false
var is_delt: bool = false

func to_dict() -> Dictionary:
	return {
		"id": id,
		"number": number,
		"value": value,
		"suit": suit,
		"show": show,
		"is_delt": is_delt
	}
	
static func from_dict(dict: Dictionary) -> CardData:
	var instance = CardData.new()
	instance.id = dict.get("id")
	instance.number = dict.get("number")
	instance.value = dict.get("value")
	instance.suit = dict.get("suit")
	instance.show = dict.get("show")
	instance.is_delt = dict.get("is_delt")
	return instance
