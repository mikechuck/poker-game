extends Node
class_name ConnectedPlayer

var id: int = 0
var is_host: bool = false
var is_ready: bool = false

func to_dict() -> Dictionary:
	return {
		"id": id,
		"is_host": is_host,
		"is_ready": is_ready
	}
	
static func from_dict(dict: Dictionary) -> ConnectedPlayer:
	var instance = ConnectedPlayer.new()
	instance.id = dict.get("id")
	instance.is_host = dict.get("is_host")
	instance.is_ready = dict.get("is_ready")
	return instance
