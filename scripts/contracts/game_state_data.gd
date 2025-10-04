extends Node
class_name GameStateData

var game_state = GameState.State.PreHand
var player_turn: int = 0
var player_seats: Dictionary[int, PlayerSeat] = {}
# The following fields never get cleared, they are set by networking functions
var host_player_id: int = 0
var connected_players: Dictionary[int, ConnectedPlayer] = {}

func reset_game_state() -> void:
	game_state = GameState.State.PreHand
	player_turn = 0
	player_seats = {}

func to_dict() -> Dictionary:
	return {
		"game_state": game_state,
		"player_turn": player_turn,
		"player_seats": Serializer.serialize_player_seats(player_seats),
		"host_player_id": host_player_id,
		"connected_players": Serializer.serialize_connected_players(connected_players)
	}

static func from_dict(dict: Dictionary) -> GameStateData:
	var instance = GameStateData.new()
	instance.game_state = dict.get("game_state")
	instance.player_turn = dict.get("player_turn")
	instance.player_seats = Serializer.deserialize_player_seats(dict.get("player_seats"))
	instance.host_player_id = dict.get("host_player_id")
	instance.connected_players = Serializer.deserialize_connected_players(dict.get("connected_players"))
	return instance
