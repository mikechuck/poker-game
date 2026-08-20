extends RefCounted
class_name ConnectedPlayer

var peer_id: int = 0
var account_id: String = ""
var is_host: bool = false
var is_spectating: bool = true
var player_total_cash: int = 0
var player_name: String = ""
var player_color: String = ""
var friend_code: String = ""
var account_hands_played: int = 0
var account_hands_won: int = 0

func clone() -> ConnectedPlayer:
	var player_clone: ConnectedPlayer = ConnectedPlayer.new()
	player_clone.peer_id = peer_id
	player_clone.account_id = account_id
	player_clone.is_host = is_host
	player_clone.is_spectating = is_spectating
	player_clone.player_total_cash = player_total_cash
	player_clone.player_color = player_color
	player_clone.friend_code = friend_code
	player_clone.account_hands_played = account_hands_played
	player_clone.account_hands_won = account_hands_won
	player_clone.player_name = player_name
	return player_clone

func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"account_id": account_id,
		"is_host": is_host,
		"is_spectating": is_spectating,
		"player_total_cash": player_total_cash,
		"player_color": player_color,
		"friend_code": friend_code,
		"account_hands_played": account_hands_played,
		"account_hands_won": account_hands_won,
		"player_name": player_name
	}
	
static func from_dict(dict: Dictionary) -> ConnectedPlayer:
	var instance: ConnectedPlayer = ConnectedPlayer.new()
	instance.peer_id = dict.get("peer_id")
	instance.account_id = dict.get("account_id")
	instance.is_host = dict.get("is_host")
	instance.is_spectating = dict.get("is_spectating")
	instance.player_total_cash = dict.get("player_total_cash")
	instance.player_color = dict.get("player_color")
	instance.friend_code = dict.get("friend_code")
	instance.account_hands_played = dict.get("account_hands_played")
	instance.account_hands_won = dict.get("account_hands_won")
	instance.player_name = dict.get("player_name")
	return instance
