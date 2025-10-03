extends Node
class_name GameStateData

var current_game_state = GameState.State.PreHand
var current_player_turn: int = 0
var player_seats: Dictionary[int, PlayerSeat] = {}
# The following fields never get cleared, they are set by networking functions
var host_player: ConnectedPlayer = null
var connected_players: Dictionary[int, ConnectedPlayer] = {}

func reset_game_state() -> void:
	current_game_state = GameState.State.PreHand
	current_player_turn = 0
	player_seats = {}

func to_dict() -> Dictionary:
	return {
		"current_game_state": current_game_state,
		"current_player_turn": current_player_turn,
		"player_seats": Serializer.serialize_player_seats(player_seats),
		"host_player": host_player,
		"connected_players": Serializer.serialize_connected_players(connected_players)
	}

static func from_dict(dict) -> GameStateData:
	var instance = GameStateData.new()
	instance.current_game_state = dict.get("current_game_state")
	instance.current_player_turn = dict.get("current_player_turn")
	instance.player_seats = Serializer.deserialize_player_seats(dict.get("player_seats"))
	instance.host_player = dict.get("host_player")
	instance.connected_players = Serializer.deserialize_connected_players(dict.get("connected_players"))
	return instance
