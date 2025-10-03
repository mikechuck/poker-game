extends Node2D

### Networking fields
var is_server = false
const server_ip_address = "0.0.0.0"
const server_port = 8083

### Scenes
@export var player_scene: PackedScene = preload("res://scenes/player.tscn")
@export var player_ui_scene: PackedScene = preload("res://scenes/UI/player_ui.tscn")

### Instantiated scenes
var player_ui_instance = null

### Managers
var server_manager
var client_manager
var deck_manager

### Signals
signal connected_players_updated_signal(old_connected_playes, new_connected_players)
signal player_seats_updated_signal(old_player_seats, new_player_seats)
signal current_player_turn_updated_signal(player_turn)
signal game_state_change_signal(old_game_state, new_game_state)

### UI Fields
var screen_origin
var single_angle = PI / 4
var table_radius = 225

### Server fields
var default_starting_cash = 100
var default_big_blind = 10
var default_small_blind = 5

var game_state_data: GameStateData

### Poker logic fields
#var current_game_state = GameState.State.PreHand
#var starting_player_turn: int = 0
#var current_player_turn: int = 0
#var connected_players: Dictionary[int, ConnectedPlayer] = {}
var player_seats: Dictionary[int, PlayerSeat] = {}
var host_player: ConnectedPlayer = null

### Client fields
var player_data: ConnectedPlayer = null

### Start lifecycle methods

func _ready() -> void:
	server_manager = get_parent().get_node("ServerManager")
	client_manager = get_parent().get_node("ClientManager")
	deck_manager = get_parent().get_node("DeckManager")
	
	var args = OS.get_cmdline_args()
	if (args.find("server_mode") >= 0):
		is_server = true
		screen_origin = Vector2.ZERO # Adjust for screen size on client only
		server_manager.start_server()
		server_manager.set_player_seats()
	else:
		is_server = false
		screen_origin = get_viewport_rect().size / 2
		player_ui_instance = get_parent().find_child("PlayerUI")
		client_manager.connect_to_server()
	
### End lifecycle methods

### Game cycle methods
func step_next_game_state():
	var previous_game_state = game_state_data.current_game_state
	match game_state_data.current_game_state:
		GameState.State.PreHand:
			var next_game_state: GameState.State = GameState.State.SetupHand
			game_state_data.current_game_state = next_game_state
			client_manager.game_state_change.rpc(previous_game_state, next_game_state)
			state_setup_hand()
		GameState.State.SetupHand:
			var next_game_state: GameState.State = GameState.State.DealHole
			game_state_data.current_game_state = next_game_state
			client_manager.game_state_change.rpc(previous_game_state, next_game_state)
			state_deal_hole_cards()
		GameState.State.DealHole:
			var next_game_state: GameState.State = GameState.State.Ante
			game_state_data.current_game_state = next_game_state
			client_manager.game_state_change.rpc(previous_game_state, next_game_state)
			state_start_ante_turns()
		GameState.State.Ante:
			var next_game_state: GameState.State = GameState.State.DealFlop
			game_state_data.current_game_state = next_game_state
			client_manager.game_state_change.rpc(previous_game_state, next_game_state)
	
func state_setup_hand():
	# New shuffled deck
	deck_manager.shuffle_deck()
	# Reset all player data
	for player_seat in player_seats.values():
		player_seat.reset_hand_data()
	# Reset turn index
	for i in range(1, player_seats.keys().size() + 1):
		if player_seats[i].player_id != 0:
			game_state_data.starting_player_turn = i
			game_state_data.current_player_turn = i
			break;
	# Set initiate blind states
	var small_blind_seat_num: int = game_state_data.starting_player_turn
	# Setup small blind
	for i in range(small_blind_seat_num, player_seats.keys().size() + 1):
		if player_seats[i].player_id != 0:
			player_seats[i].is_small_blind = true
			small_blind_seat_num = i
			break
	# Setup big blind
	for i in range(small_blind_seat_num + 1, player_seats.keys().size() + 1):
		if player_seats[i].player_id != 0:
			player_seats[i].is_big_blind = true
			break;
	# Update all clients with starting game state
	client_manager.update_current_player_turn.rpc(game_state_data.current_player_turn)
	client_manager.update_player_seats_list.rpc(Serializer.serialize_player_seats(player_seats))
	step_next_game_state()
	
func state_deal_hole_cards():
	for player in player_seats.values():
		if player.player_id:
			var hole_card1: CardData = deck_manager.deal_card()
			var hole_card2: CardData = deck_manager.deal_card()
			player.hole_cards.append(hole_card1)
			player.hole_cards.append(hole_card2)
	client_manager.update_player_seats_list.rpc(Serializer.serialize_player_seats(player_seats))
	step_next_game_state()
	
func state_start_ante_turns() -> void:
	pass
		
###################################### Helper Functions #############################################
	
func get_next_free_seat(seat_number):
	var desired_seat = player_seats.get(seat_number)
	if (desired_seat.player_id != 0):
		seat_number = (seat_number + 1) % 8
		desired_seat = player_seats.get(seat_number)
		seat_number = get_next_free_seat(seat_number)
	return seat_number
