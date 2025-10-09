extends Node
class_name GameStateData

var game_state = GameState.State.PreHand
var player_turn: int = 0
var player_seats: Dictionary[int, PlayerSeat] = {}
var pot_value: int = 0
var current_bet_value: int = 0
var last_bet_raise_player_id: int = 0
var board_cards: Array[CardData] = []
# The following fields never get cleared, they are set by networking functions
var host_player_id: int = 0
var connected_players: Dictionary[int, ConnectedPlayer] = {}

# Default fields
static var default_starting_cash = 100
static var default_big_blind = 10
static var default_small_blind = 5

func reset_game_state() -> void:
	game_state = GameState.State.PreHand
	player_turn = 0
	pot_value = 0
	current_bet_value = 0
	last_bet_raise_player_id = 0
	board_cards = []
	for player_seat in player_seats.values():
		player_seat.reset_hand_data()

func to_dict() -> Dictionary:
	return {
		"game_state": game_state,
		"player_turn": player_turn,
		"player_seats": Serializer.serialize_player_seats(player_seats),
		"pot_value": pot_value, 
		"current_bet_value": current_bet_value,
		"host_player_id": host_player_id,
		"connected_players": Serializer.serialize_connected_players(connected_players),
		"last_bet_raise_player_id": last_bet_raise_player_id,
		"board_cards": Serializer.serialize_cards(board_cards)
	}

static func from_dict(dict: Dictionary) -> GameStateData:
	var instance = GameStateData.new()
	instance.game_state = dict.get("game_state")
	instance.player_turn = dict.get("player_turn")
	instance.player_seats = Serializer.deserialize_player_seats(dict.get("player_seats"))
	instance.pot_value = dict.get("pot_value")
	instance.current_bet_value = dict.get("current_bet_value")
	instance.host_player_id = dict.get("host_player_id")
	instance.connected_players = Serializer.deserialize_connected_players(dict.get("connected_players"))
	instance.last_bet_raise_player_id = dict.get("last_bet_raise_player_id")
	instance.board_cards = Serializer.deserialize_cards(dict.get("board_cards"))
	return instance
