extends Node
class_name GameStateData

var game_state = GameState.State.PreHand
var player_turn: int = 0
var player_seats: Dictionary[int, PlayerSeat] = {}
var pot_value: int = 0
var current_bet_value: int = 0
var last_bet_raise_player_id: int = 0
var board_cards: Array[CardData] = []
var winner_player_id: int = 0
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
	winner_player_id = 0
	for player_seat: PlayerSeat in player_seats.values():
		player_seat.reset_hand_data()
		
func clone() -> GameStateData:
	var game_state_clone: GameStateData = GameStateData.new()
	game_state_clone.game_state = game_state
	game_state_clone.player_turn = player_turn
	game_state_clone.pot_value = pot_value
	game_state_clone.current_bet_value = current_bet_value
	game_state_clone.last_bet_raise_player_id = last_bet_raise_player_id
	game_state_clone.winner_player_id = winner_player_id
	game_state_clone.host_player_id = host_player_id
	for seat_id: int in player_seats.keys():
		game_state_clone.player_seats[seat_id] = player_seats[seat_id].clone()
	for card: CardData in board_cards:
		game_state_clone.board_cards.append(card.clone())
	for player_id: int in connected_players.keys():
		game_state_clone.connected_players[player_id] = connected_players[player_id].clone()
	return game_state_clone

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
		"board_cards": Serializer.serialize_cards(board_cards),
		"winner_player_id": winner_player_id
	}

static func from_dict(dict: Dictionary) -> GameStateData:
	var instance: GameStateData = GameStateData.new()
	var player_seats_dict: Dictionary = dict.get("player_seats")
	var connected_players_dict: Dictionary = dict.get("connected_players")
	var board_cards_array: Array[Dictionary] = dict.get("board_cards")
	instance.game_state = dict.get("game_state")
	instance.player_turn = dict.get("player_turn")
	instance.player_seats = Serializer.deserialize_player_seats(player_seats_dict)
	instance.pot_value = dict.get("pot_value")
	instance.current_bet_value = dict.get("current_bet_value")
	instance.host_player_id = dict.get("host_player_id")
	instance.connected_players = Serializer.deserialize_connected_players(connected_players_dict)
	instance.last_bet_raise_player_id = dict.get("last_bet_raise_player_id")
	instance.board_cards = Serializer.deserialize_cards(board_cards_array)
	instance.winner_player_id = dict.get("winner_player_id")
	return instance
