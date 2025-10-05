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
signal game_state_data_updated_signal(old_game_state_data, new_game_state_data)

### UI Fields
var screen_origin
var single_angle = PI / 4
var table_radius = 225

### Server fields
var default_starting_cash = 100
var default_big_blind = 10
var default_small_blind = 5
var game_state_data: GameStateData = GameStateData.new()

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
	# Add a timer between states so users don't get confused
	# await get_tree().create_timer(1).timeout
	match game_state_data.game_state:
		GameState.State.PreHand:
			var next_game_state: GameState.State = GameState.State.SetupHand
			game_state_data.game_state = next_game_state
			client_manager.update_game_state_data.rpc(game_state_data.to_dict())
			state_setup_hand()
		GameState.State.SetupHand:
			var next_game_state: GameState.State = GameState.State.DealHole
			game_state_data.game_state = next_game_state
			client_manager.update_game_state_data.rpc(game_state_data.to_dict())
			state_deal_hole_cards()
		GameState.State.DealHole:
			var next_game_state: GameState.State = GameState.State.BetHole
			game_state_data.game_state = next_game_state
			client_manager.update_game_state_data.rpc(game_state_data.to_dict())
		GameState.State.BetHole:
			var next_game_state: GameState.State = GameState.State.DealFlop
			game_state_data.game_state = next_game_state
			client_manager.update_game_state_data.rpc(game_state_data.to_dict())
	
func state_setup_hand():
	# New shuffled deck
	deck_manager.shuffle_deck()
	# Reset all player data
	for player_seat in game_state_data.player_seats.values():
		player_seat.reset_hand_data()
	# Reset turn and blinds index
	# Eventually, going to have to decouple first player turn from small blind seat num since those rotate
	# Rotating blinds can be done by accessing old game state data from previous round
	var first_player_seat_index = get_next_player_seat(1)
	var second_player_seat_index = get_next_player_seat(first_player_seat_index + 1)
	game_state_data.player_turn = first_player_seat_index
	game_state_data.player_seats[first_player_seat_index].is_small_blind = true
	game_state_data.player_seats[second_player_seat_index].is_big_blind = true
	# Update all clients with starting game state
	client_manager.update_game_state_data.rpc(game_state_data.to_dict())
	step_next_game_state()
	
func state_deal_hole_cards():
	for player in game_state_data.player_seats.values():
		if player.player_id:
			var hole_card1: CardData = deck_manager.deal_card()
			var hole_card2: CardData = deck_manager.deal_card()
			player.hole_cards.append(hole_card1)
			player.hole_cards.append(hole_card2)
	client_manager.update_game_state_data.rpc(game_state_data.to_dict())
	step_next_game_state()
	
func state_start_ante_turns() -> void:
	pass
	
### Player actions
func player_action_taken(player_action: PlayerTurnAction.Action, action_value):
	# match on enum, call individual functions
	match player_action:
		PlayerTurnAction.Action.Fold:
			player_action_folded()
		PlayerTurnAction.Action.Bet:
			player_action_bet(action_value)
	increment_player_turn()
	client_manager.update_game_state_data.rpc(game_state_data.to_dict())
	
func player_action_folded():
	var requestor_id = multiplayer.get_remote_sender_id()
	for player_seat in game_state_data.player_seats.values():
		if (player_seat.player_id == requestor_id):
			player_seat.is_folded = true
	
func player_action_bet(bet_value):
	get_client_player_seat().hand_cash -= bet_value
	game_state_data.pot_value += bet_value

		
###################################### Helper Functions #############################################

func increment_player_turn() -> void:
	var current_player_turn = game_state_data.player_turn
	var next_player_turn = get_next_player_seat(current_player_turn + 1)
	print("Current turn: %s, next turn: %s" % [current_player_turn, next_player_turn])
	var next_player_data = game_state_data.player_seats.get(next_player_turn)
	print("next_player_data: %s" % next_player_data)
	# If user is folded or can't bet, increment again.
	# If we end up at the same player, step to next game state.
	#while current_player_turn != next_player_turn:
		#if (next_player_data.is_folded || next_player_data.hand_cash == 0):
			#next_player_turn = get_next_player_seat(next_player_turn + 1)
			#next_player_data = game_state_data.player_seats.get(next_player_turn)
	#
	## Made it all the way around to current player, move onto next game state
	#if (current_player_turn == next_player_turn):
		#step_next_game_state()
	#else:
	game_state_data.player_turn = next_player_turn

# Num of players in the hand that have not folded and can still bet
func get_num_active_players_in_hand() -> int:
	var num_active_players = 0
	for player in game_state_data.player_seats.values():
		if !player.is_folded && !player.is_spectating && player.hand_cash != 0:
			num_active_players += 1
	return num_active_players

# Num of players in the hand that have not folded
func get_num_players_in_hand() -> int:
	var num_active_players = 0
	for player in game_state_data.player_seats.values():
		if !player.is_folded && !player.is_spectating && player.hand_cash != 0:
			num_active_players += 1
	return num_active_players

func get_next_player_seat(seat_number) -> int:
	var desired_seat = game_state_data.player_seats.get(seat_number)
	if (desired_seat.player_id == 0):
		seat_number = get_next_seat_in_range(seat_number)
		seat_number = get_next_player_seat(seat_number)
	return seat_number
	
func get_next_free_seat(seat_number) -> int:
	var desired_seat = game_state_data.player_seats.get(seat_number)
	if (desired_seat.player_id != 0):
		seat_number = get_next_seat_in_range(seat_number)
		desired_seat = game_state_data.player_seats.get(seat_number)
		seat_number = get_next_free_seat(seat_number)
	return seat_number
	
func get_next_seat_in_range(seat_number) -> int:
	return ((seat_number) % 8) + 1
	
func get_client_player_data() -> ConnectedPlayer:
	for player in game_state_data.connected_players.values():
		if player.id == multiplayer.get_unique_id():
			return player
	return null
	
func get_client_player_seat() -> PlayerSeat:
	for player in game_state_data.player_seats.values():
		print("player_id: %s" % player.player_id)
		print("unique_id: %s" % multiplayer.get_unique_id())
		print("sender_id: %s" % multiplayer.get_remote_sender_id())
		if player.player_id == multiplayer.get_unique_id():
			return player
	return null
