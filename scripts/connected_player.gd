extends Node
class_name ConnectedPlayer

var id: int = 0
var is_host: bool = false
var is_ready: bool = false
var starting_cash: int = 0
var current_cash: int = 0

func to_dict() -> Dictionary:
	return {
		"id": id,
		"is_host": is_host,
		"is_ready": is_ready,
		"starting_cash": starting_cash,
		"current_cash": current_cash
	}
	
static func from_dict(dict: Dictionary) -> ConnectedPlayer:
	var instance = ConnectedPlayer.new()
	instance.id = dict.get("id")
	instance.is_host = dict.get("is_host")
	instance.is_ready = dict.get("is_ready")
	instance.starting_cash = dict.get("starting_cash")
	instance.current_cash = dict.get("current_cash")
	return instance
