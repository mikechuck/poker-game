extends Node
class_name ConnectedPlayer

var id: int = 0
var is_host: bool = false
var is_spectating: bool = true
var is_ready: bool = false
var account_total_cash: int = 0
var table_cash: int = 0

func to_dict() -> Dictionary:
	return {
		"id": id,
		"is_host": is_host,
		"is_ready": is_ready,
		"is_spectating": is_spectating,
		"account_total_cash": account_total_cash,
		"table_cash": table_cash
	}
	
static func from_dict(dict: Dictionary) -> ConnectedPlayer:
	var instance = ConnectedPlayer.new()
	instance.id = dict.get("id")
	instance.is_host = dict.get("is_host")
	instance.is_spectating = dict.get("is_spectating")
	instance.is_ready = dict.get("is_ready")
	instance.account_total_cash = dict.get("account_total_cash")
	instance.table_cash = dict.get("table_cash")
	return instance
