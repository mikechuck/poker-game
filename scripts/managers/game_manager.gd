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

func reset_hand() -> void:
	game_state_data.reset_game_state()
	deck_manager.shuffle_deck()

func assign_player_to_seat(client_id, seat_number) -> void:
	# Check to see if seat is already filled
	seat_number = get_next_free_seat(seat_number)
	# First remove them from their current seat then put them in the new seat
	var desired_seat = game_state_data.player_seats.get(seat_number)
	for seat in game_state_data.player_seats.values():
		if (seat.player_id == client_id):
			seat.player_id = 0
	desired_seat.player_id = client_id
	desired_seat.hand_cash = GameStateData.default_starting_cash
	game_state_data.player_seats[seat_number] = desired_seat
	game_state_data.connected_players[client_id].is_spectating = false
	client_manager.update_game_state_data.rpc(game_state_data.to_dict())

### Game cycle methods
func step_next_game_state():
	print("Stepping to next game state from %s" % GameState.State.find_key(game_state_data.game_state))
	game_state_data.current_bet_value = 0
	game_state_data.last_bet_raise_player_id = 0
	game_state_data.player_turn = 1
	for seat in game_state_data.player_seats.values():
		seat.bet_value = 0
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
			check_skip_this_state()
		GameState.State.BetHole:
			var next_game_state: GameState.State = GameState.State.DealFlop
			game_state_data.game_state = next_game_state
			client_manager.update_game_state_data.rpc(game_state_data.to_dict())
			state_deal_flop_cards()
		GameState.State.DealFlop:
			var next_game_state: GameState.State = GameState.State.BetFlop
			game_state_data.game_state = next_game_state
			client_manager.update_game_state_data.rpc(game_state_data.to_dict())
		GameState.State.BetFlop:
			var next_game_state: GameState.State = GameState.State.DealTurn
			game_state_data.game_state = next_game_state
			client_manager.update_game_state_data.rpc(game_state_data.to_dict())
			state_deal_turn_card()
		GameState.State.DealTurn:
			var next_game_state: GameState.State = GameState.State.BetTurn
			game_state_data.game_state = next_game_state
			client_manager.update_game_state_data.rpc(game_state_data.to_dict())
			check_skip_this_state()
		GameState.State.BetTurn:
			var next_game_state: GameState.State = GameState.State.DealRiver
			game_state_data.game_state = next_game_state
			client_manager.update_game_state_data.rpc(game_state_data.to_dict())
			state_deal_river_card()
		GameState.State.DealRiver:
			var next_game_state: GameState.State = GameState.State.BetRiver
			game_state_data.game_state = next_game_state
			client_manager.update_game_state_data.rpc(game_state_data.to_dict())
			check_skip_this_state()
		GameState.State.BetRiver:
			var next_game_state: GameState.State = GameState.State.HandOver
			game_state_data.game_state = next_game_state
			client_manager.update_game_state_data.rpc(game_state_data.to_dict())
			state_end_step()
	
func state_setup_hand():
	# New shuffled deck
	deck_manager.shuffle_deck()
	# Reset all player data
	for player_seat in game_state_data.player_seats.values():
		player_seat.reset_hand_data()
	# Reset turn and blinds index
	# Eventually, going to have to decouple first player turn from small blind seat num since those rotate
	# Rotating blinds can be done by accessing old game state data from previous round
	var first_player_seat_index = get_next_player_seat_number(1)
	var second_player_seat_index = get_next_player_seat_number(first_player_seat_index + 1)
	game_state_data.player_seats[first_player_seat_index].is_small_blind = true
	game_state_data.player_seats[second_player_seat_index].is_big_blind = true
	# Update all clients with starting game state
	client_manager.update_game_state_data.rpc(game_state_data.to_dict())
	step_next_game_state()
	
func check_skip_this_state() -> void:
	if get_num_active_players_in_hand() <= 1:
		step_next_game_state()
	
func state_deal_hole_cards():
	for player in game_state_data.player_seats.values():
		if player.player_id:
			var hole_card1: CardData = deck_manager.deal_card()
			var hole_card2: CardData = deck_manager.deal_card()
			player.hole_cards.append(hole_card1)
			player.hole_cards.append(hole_card2)
	# Add a timer between states so users have visual separation
	await get_tree().create_timer(0.5).timeout
	client_manager.update_game_state_data.rpc(game_state_data.to_dict())
	step_next_game_state()
	
func state_deal_flop_cards() -> void:
	game_state_data.board_cards.append(deck_manager.deal_card())
	game_state_data.board_cards.append(deck_manager.deal_card())
	game_state_data.board_cards.append(deck_manager.deal_card())
	# Add a timer between states so users have visual separation
	await get_tree().create_timer(0.5).timeout
	client_manager.update_game_state_data.rpc(game_state_data.to_dict())
	step_next_game_state()
	
func state_deal_turn_card() -> void:
	game_state_data.board_cards.append(deck_manager.deal_card())
	# Add a timer between states so users have visual separation
	await get_tree().create_timer(0.5).timeout
	client_manager.update_game_state_data.rpc(game_state_data.to_dict())
	step_next_game_state()

func state_deal_river_card() -> void:
	game_state_data.board_cards.append(deck_manager.deal_card())
	client_manager.update_game_state_data.rpc(game_state_data.to_dict())
	step_next_game_state()
	
func state_end_step() -> void:
	print("GAME OVER, CALCULATING WINNER")
	var winning_player_seat = find_winning_seat()
	
func find_winning_seat() -> PlayerSeat:
	var highest_hand_value = 0
	var winning_seat: PlayerSeat
	for seat in game_state_data.player_seats.values():
		var hand_value: float = 0
		var full_cards = seat.hole_cards + game_state_data.board_cards
		full_cards.sort_custom(func(a, b):
			return a.number > b.number)
		hand_value += get_high_card(full_cards) * pow(10, HandRanks.Rank.HighCard)
		#hand_value += get_one_pair(sorted_cards) * pow(10, HandRanks.Rank.OnePair)
		print("hand_value: %s" % hand_value)
	return winning_seat
		
func get_high_card(sorted_cards) -> int:
	return sorted_cards[0].number
	
func get_one_pair(sorted_cards) -> int:
	return 1
	
### Player actions
func player_action_taken(player_action: PlayerTurnAction.Action, action_value):
	# match on enum, call individual functions
	match player_action:
		PlayerTurnAction.Action.StartGame:
			player_action_start_game()
		PlayerTurnAction.Action.Fold:
			player_action_folded()
		PlayerTurnAction.Action.Ante:
			player_action_ante()
		PlayerTurnAction.Action.Bet:
			player_action_bet(action_value)
		PlayerTurnAction.Action.Check:
			pass
		PlayerTurnAction.Action.Call:
			player_action_call()
	increment_player_turn()

func player_action_start_game() -> void:
	var requestor_id = multiplayer.get_remote_sender_id()
	# Ensure all players are ready before starting
	var all_players_ready = true
	for seat in game_state_data.player_seats.values():
		if seat.player_id != 0 && !seat.is_ready:
			all_players_ready = false
	if (game_state_data.host_player_id == requestor_id &&
		game_state_data.game_state == GameState.State.PreHand &&
		all_players_ready):
		step_next_game_state()
	
func player_action_folded():
	var requestor_id = multiplayer.get_remote_sender_id()
	for player_seat in game_state_data.player_seats.values():
		if (player_seat.player_id == requestor_id):
			player_seat.is_folded = true
			
func player_action_ante():
	var player_seat = server_get_player_seat()
	var bet_value
	if player_seat.is_small_blind:
		bet_value = GameStateData.default_small_blind
	else:
		bet_value = GameStateData.default_big_blind
	player_seat.hand_cash -= bet_value
	player_seat.bet_value += bet_value
	game_state_data.pot_value += bet_value
	game_state_data.current_bet_value = bet_value
	game_state_data.last_bet_raise_player_id = player_seat.player_id
	
func player_action_bet(bet_value):
	var player_seat = server_get_player_seat()
	player_seat.hand_cash -= bet_value
	player_seat.bet_value += bet_value
	game_state_data.pot_value += bet_value
	if player_seat.bet_value > game_state_data.current_bet_value:
		game_state_data.last_bet_raise_player_id = player_seat.player_id
		game_state_data.current_bet_value = player_seat.bet_value
		
func player_action_call():
	var call_value = game_state_data.current_bet_value
	var player_seat = server_get_player_seat()
	var bet_value_difference = call_value - player_seat.bet_value
	player_seat.hand_cash -= bet_value_difference
	player_seat.bet_value += bet_value_difference
	game_state_data.pot_value += bet_value_difference

		
###################################### Helper Functions #############################################

func increment_player_turn() -> void:
	var current_player_turn = game_state_data.player_turn
	var next_player_turn = get_next_active_player_turn()
	var next_player_data = game_state_data.player_seats.get(next_player_turn)
	
	if get_num_active_players_in_hand() <= 1:
		step_next_game_state()
	# It's come all around the table without a raise, move onto next game state
	if next_player_data.player_id == game_state_data.last_bet_raise_player_id:
		game_state_data.player_turn = 1
		step_next_game_state()
	else:
		game_state_data.player_turn = next_player_turn
		client_manager.update_game_state_data.rpc(game_state_data.to_dict())
		
func get_next_active_player_turn() -> int:
	var next_turn = get_next_seat_number_in_range(game_state_data.player_turn)
	return get_next_active_player_seat_number(next_turn)

# Num of players in the hand that have not folded and can still bet
func get_num_active_players_in_hand() -> int:
	var num_active_players = 0
	for seat in game_state_data.player_seats.values():
		if seat.player_id && !seat.is_folded && seat.hand_cash != 0:
			num_active_players += 1
	return num_active_players

# Num of players in the hand that have not folded
func get_num_players_in_hand() -> int:
	var num_active_players = 0
	for player in game_state_data.player_seats.values():
		if !player.is_folded && player.hand_cash != 0:
			num_active_players += 1
	return num_active_players

func get_next_player_seat_number(seat_number) -> int:
	var desired_seat = game_state_data.player_seats.get(seat_number)
	if (desired_seat.player_id == 0):
		seat_number = get_next_seat_number_in_range(seat_number)
		seat_number = get_next_player_seat_number(seat_number)
	return seat_number
	
func get_next_active_player_seat_number(seat_number) -> int:
	var desired_seat = game_state_data.player_seats.get(seat_number)
	if (desired_seat.player_id == 0 || desired_seat.is_folded || desired_seat.hand_cash == 0):
		seat_number = get_next_seat_number_in_range(seat_number)
		seat_number = get_next_active_player_seat_number(seat_number)
	return seat_number
	
func get_next_free_seat(seat_number) -> int:
	var desired_seat = game_state_data.player_seats.get(seat_number)
	if (!desired_seat || desired_seat.player_id != 0):
		seat_number = get_next_seat_number_in_range(seat_number)
		seat_number = get_next_free_seat(seat_number)
	return seat_number
	
func get_next_seat_number_in_range(seat_number) -> int:
	return ((seat_number) % 8) + 1

# To be used on the client only
func client_get_player_data() -> ConnectedPlayer:
	for player in game_state_data.connected_players.values():
		if player.id == multiplayer.get_unique_id():
			return player
	return null
	
# To be used on the server only
func server_get_player_seat() -> PlayerSeat:
	for player in game_state_data.player_seats.values():
		if player.player_id == multiplayer.get_remote_sender_id():
			return player
	return null


## Debug helpers

func debug_goto_deal_flop() -> void:
	reset_hand()
	for player in game_state_data.connected_players.values():
		assign_player_to_seat(player.id, 1)
	for player_seat in game_state_data.player_seats.values():
		player_seat.is_ready = true
	step_next_game_state()
	for player_seat in game_state_data.player_seats.values():
		if player_seat.player_id != 0:
			player_seat.bet_value = GameStateData.default_big_blind
			player_seat.hand_cash -= GameStateData.default_big_blind
			game_state_data.pot_value += GameStateData.default_big_blind
	step_next_game_state()
	
func debug_goto_end_step() -> void:
	debug_goto_deal_flop()
	step_next_game_state()
	step_next_game_state()
	step_next_game_state()
