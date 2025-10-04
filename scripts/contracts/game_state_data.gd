extends Node
class_name GameStateData

var game_state = GameState.State.PreHand
var player_turn: int = 0
var player_seats: Dictionary[int, PlayerSeat] = {}
var big_blind_complete: bool = false
var small_blind_complete: bool = false
var pot_value: int = 0
# The following fields never get cleared, they are set by networking functions
var host_player_id: int = 0
var connected_players: Dictionary[int, ConnectedPlayer] = {}

func reset_game_state() -> void:
	game_state = GameState.State.PreHand
	player_turn = 0
	player_seats = {}
	big_blind_complete = false
	small_blind_complete = false
	pot_value = 0

func to_dict() -> Dictionary:
	return {
		"game_state": game_state,
		"player_turn": player_turn,
		"player_seats": Serializer.serialize_player_seats(player_seats),
		"big_blind_complete": big_blind_complete,
		"small_blind_complete": small_blind_complete,
		"pot_value": pot_value, 
		"host_player_id": host_player_id,
		"connected_players": Serializer.serialize_connected_players(connected_players)
	}

static func from_dict(dict: Dictionary) -> GameStateData:
	var instance = GameStateData.new()
	instance.game_state = dict.get("game_state")
	instance.player_turn = dict.get("player_turn")
	instance.player_seats = Serializer.deserialize_player_seats(dict.get("player_seats"))
	instance.big_blind_complete = dict.get("big_blind_complete")
	instance.small_blind_complete = dict.get("small_blind_complete")
	instance.pot_value = dict.get("pot_value")
	instance.host_player_id = dict.get("host_player_id")
	instance.connected_players = Serializer.deserialize_connected_players(dict.get("connected_players"))
	return instance
