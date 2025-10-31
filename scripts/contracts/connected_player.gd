extends Node
class_name ConnectedPlayer

var id: int = 0
var is_host: bool = false
var is_spectating: bool = true
var account_total_cash: int = 0
var table_cash: int = 0
# Server-side only: JWT token and user_id (not serialized/sent to clients)
var jwt_token: String = ""
var user_id: String = ""

func clone() -> ConnectedPlayer:
	var player_clone = ConnectedPlayer.new()
	player_clone.id = id
	player_clone.is_host = is_host
	player_clone.is_spectating = is_spectating
	player_clone.account_total_cash = account_total_cash
	player_clone.table_cash = table_cash
	player_clone.jwt_token = jwt_token
	player_clone.user_id = user_id
	return player_clone

func to_dict() -> Dictionary:
	return {
		"id": id,
		"is_host": is_host,
		"is_spectating": is_spectating,
		"account_total_cash": account_total_cash,
		"table_cash": table_cash,
		"user_id": user_id 
	}
	
static func from_dict(dict: Dictionary) -> ConnectedPlayer:
	var instance = ConnectedPlayer.new()
	instance.id = dict.get("id")
	instance.is_host = dict.get("is_host")
	instance.is_spectating = dict.get("is_spectating")
	instance.account_total_cash = dict.get("account_total_cash")
	instance.table_cash = dict.get("table_cash")
	instance.user_id = dict.get("user_id", "")  
	return instance
