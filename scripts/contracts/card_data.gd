extends Node
class_name CardData

var id: String
var number: String
var suit: String
var show: bool = false
var is_delt: bool = false

func to_dict() -> Dictionary:
	return {
		"id": id,
		"number": number,
		"suit": suit,
		"show": show
	}
	
static func from_dict(dict: Dictionary) -> CardData:
	var instance = CardData.new()
	instance.id = dict.get("id")
	instance.number = dict.get("number")
	instance.suit = dict.get("suit")
	instance.show = dict.get("show")
	return instance
