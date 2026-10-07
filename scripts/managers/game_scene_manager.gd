extends Node2D
class_name GameSceneManager

### Networking fields
var is_server: bool = false

### Scenes
@export var player_scene: PackedScene = preload("res://scenes/UI/player.tscn")
@export var player_ui_scene: PackedScene = preload("res://scenes/UI/player_ui.tscn")

### Instantiated scenes
var player_ui_instance: PlayerUI = null

### Managers
@onready var server_manager: ServerManager = get_parent().get_node("ServerManager")
@onready var deck_manager: DeckManager = get_parent().get_node("DeckManager")
@onready var players_list_node: PlayersListContainer = get_parent().get_node("PlayersList")

### Signals
signal game_state_data_updated_signal(old_game_state_data, new_game_state_data)

### UI Fields
var screen_origin: Vector2
var single_angle: float = PI / 4
var table_radius: int = 225

### Server fields
var game_state_data: GameStateData = GameStateData.new()
@onready var idle_timer : Timer = Timer.new()
var idle_timeout_sec: int = 300

### Start lifecycle methods


func _ready() -> void:
	call_deferred("run_after_tree_load")
	
	# Start idle timer so we can shutdown the server if no one is playing
	idle_timer.wait_time = idle_timeout_sec
	idle_timer.timeout.connect(_on_idle_timeout)
	add_child(idle_timer)
	idle_timer.start()
	

func _on_idle_timeout() -> void:
	# If no players are in the game after the timeout, end the game
	if (game_state_data.connected_players.size() == 0):
		var update_request: Dictionary = {
			"game_id": server_manager.GAME_ID,
			"game_status": Contracts.GameStatus.ENDED,
			"port": server_manager.PORT
		}
		
		var response_code: int = await HttpRequestsManager.server_update_game(update_request)
		if response_code != 200:
			Log.error("Error updating game instance from server.")
		Log.message("Game server instance shutting down. Goodbye.")
		get_tree().quit()
	
	
# Make sure all the other managers are ready (auth, http, etc)
func run_after_tree_load():
	if (OS.has_feature("server")):
		is_server = true
		screen_origin = Vector2.ZERO # Adjust for screen size on client only
		server_manager.start_server()
		server_manager.set_player_seats()
	else:
		is_server = false
		screen_origin = get_viewport_rect().size / 2
		player_ui_instance = get_parent().find_child("PlayerUI")
		server_manager.request_game_state_publish.rpc_id(1)
		
	
	
### End lifecycle methods

func reset_game() -> void:
	game_state_data.reset()
	deck_manager.shuffle_deck()
	ClientManager.update_game_state_data.rpc(game_state_data.to_dict())


func reset_hand() -> void:
	game_state_data.new_hand()
	deck_manager.shuffle_deck()
	ClientManager.update_game_state_data.rpc(game_state_data.to_dict())


func assign_player_to_seat(client_id: int, seat_number: int) -> void:
	# Check to see if seat is already filled
	seat_number = get_next_free_seat(seat_number)
	# First remove them from their current seat then put them in the new seat
	var player_data: ConnectedPlayer = game_state_data.try_get_connected_player_data(client_id)
	var desired_seat: PlayerSeat = game_state_data.player_seats.get(seat_number)
	for seat: PlayerSeat in game_state_data.player_seats.values():
		if (seat.account_id == player_data.account_id):
			seat.clear_seat_data()
	desired_seat.account_id = player_data.account_id
	desired_seat.hand_cash = GameStateData.default_starting_cash
	game_state_data.player_seats[seat_number] = desired_seat
	game_state_data.connected_players[player_data.account_id].is_spectating = false
	ClientManager.update_game_state_data.rpc(game_state_data.to_dict())


func remove_player_from_seat(client_id: int) -> void:
	var player_data: ConnectedPlayer = game_state_data.try_get_connected_player_data(client_id)
	for seat: PlayerSeat in game_state_data.player_seats.values():
		if (seat.account_id == player_data.account_id):
			seat.clear_seat_data()
	game_state_data.connected_players[player_data.account_id].is_spectating = true
	ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
	

func remove_player_from_game(peer_id: int) -> void:
	remove_player_from_seat(peer_id)
	var disconnecting_player: ConnectedPlayer = game_state_data.try_get_connected_player_data(peer_id)
	game_state_data.connected_players.erase(disconnecting_player.account_id)
	Log.message("Removing player %s from game (peer_id %s" % [disconnecting_player.account_id, peer_id])
	
	if game_state_data.host_account_id == disconnecting_player.account_id:
		var new_host: ConnectedPlayer = game_state_data.connected_players.values()[0]
		game_state_data.host_account_id = new_host.account_id
		new_host.is_host = true
		Log.message("New host id: %s" % new_host.account_id)
		
	var update_request: Dictionary = {
		"game_id": server_manager.GAME_ID,
		"remove_players": [disconnecting_player.account_id]
	}
	var response_code: int = await HttpRequestsManager.server_update_game(update_request)
	
	ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
	Log.message("Number of players connected: %s" % [game_state_data.connected_players.size()])
	
	# If no players are in the game, start the idle timeout shutdown
	if (game_state_data.connected_players.size() == 0):
		reset_game()
		idle_timer.start()


func set_player_as_left(client_id: int):
	var leaving_player_data: ConnectedPlayer = game_state_data.try_get_connected_player_data(client_id)
	leaving_player_data.player_state = ConnectedPlayer.PlayerState.LEFT
	for seat in game_state_data.player_seats.values():
		if seat.account_id == leaving_player_data.account_id:
			seat.has_left = true
	
	# If leaving player is host, assign a new host
	if game_state_data.host_account_id == leaving_player_data.account_id:
		for player: ConnectedPlayer in game_state_data.connected_players.values():
			if player.player_state != ConnectedPlayer.PlayerState.LEFT:
				game_state_data.host_account_id = player.account_id
				player.is_host = true
				Log.message("New host id: %s" % player.account_id)
				break
		Log.message("No connected players eligible to be host, setting to empty")
		game_state_data.host_account_id = ""


### Game cycle methods
func step_next_game_state():
	# Add a timer between states so users have visual separation
	#await get_tree().create_timer(0.5).timeout
	game_state_data.current_bet_value = 0
	game_state_data.last_bet_raise_account_id = ""
	game_state_data.player_turn = get_next_active_player_seat_number(0)
	
	for seat: PlayerSeat in game_state_data.player_seats.values():
		seat.bet_value = 0
	match game_state_data.game_state:
		GameState.State.PreHand:
			var next_game_state: GameState.State = GameState.State.SetupHand
			game_state_data.game_state = next_game_state
			ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
			state_setup_hand()
		GameState.State.SetupHand:
			var next_game_state: GameState.State = GameState.State.DealHole
			game_state_data.game_state = next_game_state
			ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
			state_deal_hole_cards()
		GameState.State.DealHole:
			var next_game_state: GameState.State = GameState.State.BetHole
			game_state_data.game_state = next_game_state
			ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
			check_skip_this_state()
		GameState.State.BetHole:
			var next_game_state: GameState.State = GameState.State.DealFlop
			game_state_data.game_state = next_game_state
			ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
			state_deal_flop_cards()
		GameState.State.DealFlop:
			var next_game_state: GameState.State = GameState.State.BetFlop
			game_state_data.game_state = next_game_state
			ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
			check_skip_this_state()
		GameState.State.BetFlop:
			var next_game_state: GameState.State = GameState.State.DealTurn
			game_state_data.game_state = next_game_state
			ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
			state_deal_turn_card()
		GameState.State.DealTurn:
			var next_game_state: GameState.State = GameState.State.BetTurn
			game_state_data.game_state = next_game_state
			ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
			check_skip_this_state()
		GameState.State.BetTurn:
			var next_game_state: GameState.State = GameState.State.DealRiver
			game_state_data.game_state = next_game_state
			ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
			state_deal_river_card()
		GameState.State.DealRiver:
			var next_game_state: GameState.State = GameState.State.BetRiver
			game_state_data.game_state = next_game_state
			ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
			check_skip_this_state()
		GameState.State.BetRiver:
			var next_game_state: GameState.State = GameState.State.HandOver
			game_state_data.game_state = next_game_state
			ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
			state_end_step()
		GameState.State.HandOver:
			var next_game_state: GameState.State = GameState.State.PreHand
			game_state_data.game_state = next_game_state
			state_run_prehand_checks()
			ClientManager.update_game_state_data.rpc(game_state_data.to_dict())


func state_run_prehand_checks():
	Log.message("Running PreHand checks on players")
	# Check for IDLE or LEFT players, remove them from their seat or the game entirely
	for connected_player: ConnectedPlayer in game_state_data.connected_players.values():
		Log.message("Running prehand checks for player %s - %s" % [connected_player.account_id, connected_player.player_name])
		if connected_player.player_state == ConnectedPlayer.PlayerState.IDLE:
			# If the player has been idle for more than 5 minutes, remove them from the game
			if (connected_player.player_idle_start_timestamp_ms + 300000) > int(Time.get_unix_time_from_system() * 1000):
				Log.message("PreHand Check - Player %s has been idle for too long, removing them from the game" % connected_player.player_name)
				remove_player_from_game(connected_player.peer_id)
			else:
				Log.message("PreHand Check - Player %s is idle, removing them from their seat" % connected_player.player_name)
				remove_player_from_seat(connected_player.peer_id)
		
		if connected_player.player_state == ConnectedPlayer.PlayerState.LEFT:
			Log.message("PreHand Check - Player %s has LEFT, removing them from the game" % connected_player.player_name)
			remove_player_from_game(connected_player.peer_id)
			
	#reset_hand()
	ClientManager.update_game_state_data.rpc(game_state_data.to_dict())


func state_setup_hand():
	# New shuffled deck
	deck_manager.shuffle_deck()
	# Reset all player data
	for player_seat: PlayerSeat in game_state_data.player_seats.values():
		player_seat.reset_hand_data()
	# Reset turn and blinds index
	# Eventually, going to have to decouple first player turn from small blind seat num since those rotate
	# Rotating blinds can be done by accessing old game state data from previous round
	var first_player_seat_index: int = get_next_active_player_seat_number(1)
	var second_player_seat_index: int = get_next_active_player_seat_number(first_player_seat_index + 1)
	game_state_data.player_seats[first_player_seat_index].is_small_blind = true
	game_state_data.player_seats[second_player_seat_index].is_big_blind = true
	# Update all clients with starting game state
	ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
	step_next_game_state()
	
	
func check_skip_this_state() -> void:
	if get_num_active_players_in_hand() <= 1 and game_state_data.game_state != GameState.State.PreHand:
		Log.message("NO ACTIVE PLAYERS, CONTINUING TO NEXT GAME STATE")
		step_next_game_state()
	
	
func state_deal_hole_cards():
	for player: Player in game_state_data.player_seats.values():
		if player.account_id != "":
			var hole_card1: CardData = deck_manager.deal_card()
			var hole_card2: CardData = deck_manager.deal_card()
			player.hole_cards.append(hole_card1)
			player.hole_cards.append(hole_card2)
	ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
	step_next_game_state()
	
	
func state_deal_flop_cards() -> void:
	game_state_data.board_cards.append(deck_manager.deal_card())
	game_state_data.board_cards.append(deck_manager.deal_card())
	game_state_data.board_cards.append(deck_manager.deal_card())
	# Add a timer between states so users have visual separation
	await get_tree().create_timer(0.5).timeout
	ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
	step_next_game_state()
	
	
func state_deal_turn_card() -> void:
	game_state_data.board_cards.append(deck_manager.deal_card())
	# Add a timer between states so users have visual separation
	await get_tree().create_timer(0.5).timeout
	ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
	step_next_game_state()


func state_deal_river_card() -> void:
	game_state_data.board_cards.append(deck_manager.deal_card())
	ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
	step_next_game_state()
	
	
func state_end_step() -> void:
	game_state_data.winner_account_id = game_state_data.connected_players.values()[0].account_id
	# Add the new balance to the winner
	for seat: PlayerSeat in game_state_data.player_seats.values():
		if seat.account_id == game_state_data.winner_account_id:
			seat.hand_cash += game_state_data.pot_value
	game_state_data.connected_players[game_state_data.winner_account_id].player_total_cash += game_state_data.pot_value
	ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
	
	
func find_winning_seat() -> PlayerSeat:
	var highest_hand_value: int = 0
	var winning_seat: PlayerSeat
	var player_scores: Dictionary[int, int]
	for seat: PlayerSeat in game_state_data.player_seats.values():
		if seat.account_id == "": continue # only evaluate score for filled seats
		var hand_value: float = 0
		var full_cards: Array[CardData] = seat.hole_cards + game_state_data.board_cards
		full_cards.sort_custom(func(a, b):
			return a.number > b.number)
		Log.message("Player hand: [%s%s, %s%s, %s%s, %s%s, %s%s]" % [full_cards[0].value, full_cards[0].suit, full_cards[1].value, full_cards[1].suit, full_cards[2].value, full_cards[2].suit, full_cards[3].value, full_cards[3].suit, full_cards[4].value, full_cards[4].suit])
		# Keep track of the remaining cards once we find the players score, might need to evaluate kickers
		seat.sorted_hand_cards = full_cards
		# Optimistically get the highest hand score, break once found
		hand_value = deck_manager.find_highest_hand_value(seat.sorted_hand_cards)
	return winning_seat
	
	
### Player actions
func player_action_taken(player_action: PlayerTurnAction.Action, action_value: int):
	# Ensure action can only be taken by the player who's turn it is
	if player_action == PlayerTurnAction.Action.StartGame:
		var player_data: ConnectedPlayer = game_state_data.try_get_connected_player_data(multiplayer.get_remote_sender_id())
		if player_data.account_id != game_state_data.host_account_id:
			Log.error("Player %s tried to perform the action %s but they are not allowed!" % [player_data.account_id, player_action])
			return
	else:
		var client_seat_index: int = game_state_data.try_get_player_seat_index(multiplayer.get_remote_sender_id())
		if client_seat_index != game_state_data.player_turn:
			Log.error("Player %s tried to perform the action %s but they are not allowed!" % [client_seat_index, player_action])
			return
		
	# match on enum, call individual functions
	match player_action:
		PlayerTurnAction.Action.StartGame:
			player_action_start_game()
		PlayerTurnAction.Action.Fold:
			player_action_folded()
			increment_player_turn()
		PlayerTurnAction.Action.Ante:
			player_action_ante()
			increment_player_turn()
		PlayerTurnAction.Action.Raise:
			player_action_raise(action_value)
			increment_player_turn()
		PlayerTurnAction.Action.Check:
			player_action_check()
			increment_player_turn()
		PlayerTurnAction.Action.Call:
			player_action_call()
			increment_player_turn()
			
			
func player_action_start_game() -> void:
	var requestor_id: int = multiplayer.get_remote_sender_id()
	var account_data: ConnectedPlayer = game_state_data.try_get_connected_player_data(requestor_id)
	# Ensure all players are ready before starting
	var all_players_ready: bool = true
	for seat: PlayerSeat in game_state_data.player_seats.values():
		if seat.account_id != "" && !seat.is_ready:
			all_players_ready = false
	if (game_state_data.host_account_id == account_data.account_id &&
		game_state_data.game_state == GameState.State.PreHand &&
		all_players_ready):
		step_next_game_state()
	
	
func player_action_folded():
	var requestor_id: int = multiplayer.get_remote_sender_id()
	var account_data: ConnectedPlayer = game_state_data.try_get_connected_player_data(requestor_id)
	for player_seat: PlayerSeat in game_state_data.player_seats.values():
		if (player_seat.account_id == account_data.account_id):
			player_seat.is_folded = true
		
			
func player_action_ante():
	var player_seat: PlayerSeat = server_get_player_seat()
	var bet_value: int = 0
	if player_seat.is_small_blind:
		bet_value = GameStateData.default_small_blind
	else:
		bet_value = GameStateData.default_big_blind
	player_seat.hand_cash -= bet_value
	player_seat.bet_value += bet_value
	game_state_data.pot_value += bet_value
	game_state_data.current_bet_value = bet_value
	game_state_data.last_bet_raise_account_id = player_seat.account_id


func player_action_check() -> void:
	if (game_state_data.last_bet_raise_account_id == ""):
		var peer_id: int = multiplayer.get_remote_sender_id()
		var account_id: String = game_state_data.try_get_connected_player_data(peer_id).account_id
		game_state_data.last_bet_raise_account_id = account_id


func player_action_raise(bet_value: int):
	var player_seat: PlayerSeat = server_get_player_seat()
	var difference_raise: int = game_state_data.current_bet_value - player_seat.bet_value + bet_value
	player_seat.hand_cash -= difference_raise
	player_seat.bet_value += difference_raise
	game_state_data.pot_value += bet_value
	if player_seat.bet_value > game_state_data.current_bet_value:
		game_state_data.last_bet_raise_account_id = player_seat.account_id
		game_state_data.current_bet_value = player_seat.bet_value
		
		
func player_action_call():
	var call_value: int = game_state_data.current_bet_value
	var player_seat: PlayerSeat = server_get_player_seat()
	var bet_value_difference: int = call_value - player_seat.bet_value
	player_seat.hand_cash -= bet_value_difference
	player_seat.bet_value += bet_value_difference
	game_state_data.pot_value += bet_value_difference
	if player_seat.bet_value > game_state_data.current_bet_value:
		game_state_data.last_bet_raise_account_id = player_seat.account_id
		game_state_data.current_bet_value = player_seat.bet_value
		
		
# Called during HandOver from host
func start_new_hand() -> void:
	step_next_game_state()
	reset_hand()
	step_next_game_state()
	
	
# Called during HandOver from host
func goto_lobby() -> void:
	step_next_game_state()

		
###################################### Helper Functions #############################################


func increment_player_turn() -> void:
	var next_player_turn: int = get_next_active_player_turn()
	var next_player_data: PlayerSeat = game_state_data.player_seats.get(next_player_turn)
	
	if get_num_active_players_in_hand() <= 1:
		step_next_game_state()
	# It's come all around the table without a raise, move onto next game state
	elif next_player_data.account_id == game_state_data.last_bet_raise_account_id:
		step_next_game_state()
	else:
		game_state_data.player_turn = next_player_turn
		ClientManager.update_game_state_data.rpc(game_state_data.to_dict())
		
		
func get_next_active_player_turn() -> int:
	var next_turn: int = get_next_seat_number_in_range(game_state_data.player_turn)
	return get_next_active_player_seat_number(next_turn)


# Num of players in the hand that have not folded and can still bet
# Ensure that any "active" players are not in a LEFT connection state,
# They don't count as active even if their seat is
func get_num_active_players_in_hand() -> int:
	var num_active_players: int = 0
	for seat: PlayerSeat in game_state_data.player_seats.values():
		if seat.account_id != "":
			var player_data: ConnectedPlayer = game_state_data.connected_players.get(seat.account_id)
			if (player_data == null): continue
			if (player_data.player_state == ConnectedPlayer.PlayerState.LEFT): continue
			if !seat.is_folded && seat.hand_cash != 0:
				num_active_players += 1
	return num_active_players


# Num of players in the hand that have not folded
func get_num_players_in_hand() -> int:
	var num_active_players: int = 0
	for player: PlayerSeat in game_state_data.player_seats.values():
		if !player.is_folded && player.hand_cash != 0:
			num_active_players += 1
	return num_active_players


func get_next_player_seat_number(seat_number: int) -> int:
	var desired_seat: PlayerSeat = game_state_data.player_seats.get(seat_number)
	if (!desired_seat || desired_seat.account_id == ""):
		seat_number = get_next_seat_number_in_range(seat_number)
		#seat_number = get_next_player_seat_number(seat_number)
	return seat_number
	

# An active seat meets these criteria:
# - has a player assigned (account_id set)
# - is not folded
# - has money left to bet
# - is not in a LEFT state in their connected_player data
# Note: we will still give IDLE players a change to reconnect, so their turn still runs
func get_next_active_player_seat_number(seat_number: int) -> int:
	var desired_seat: PlayerSeat = game_state_data.player_seats.get(seat_number)
	var player_left_game: bool = false
	# Check connection status first if a player is sitting here
	if (desired_seat.account_id != ""):
		var player_data: ConnectedPlayer = game_state_data.connected_players.get(desired_seat.account_id)
		if player_data != null:
			player_left_game = player_data.player_state == ConnectedPlayer.PlayerState.LEFT
	# Not an active seat, find the next one
	if (desired_seat.account_id == "" || desired_seat.is_folded || desired_seat.hand_cash == 0 || player_left_game):
		seat_number = get_next_seat_number_in_range(seat_number)
		seat_number = get_next_active_player_seat_number(seat_number)
	return seat_number
	
	
func get_next_free_seat(seat_number: int) -> int:
	var desired_seat: PlayerSeat = game_state_data.player_seats.get(seat_number)
	if (!desired_seat || desired_seat.account_id != ""):
		seat_number = get_next_seat_number_in_range(seat_number)
		seat_number = get_next_free_seat(seat_number)
	return seat_number
	
	
func get_next_seat_number_in_range(seat_number: int) -> int:
	return ((seat_number) % 8) + 1


# To be used on the client only
#func client_get_player_data(account_id: String) -> ConnectedPlayer:
	#for player: ConnectedPlayer in game_state_data.connected_players.values():
		#if player.account_id == account_id:
			#return player
	#Log.error("Can't find player data on server")
	#return null
	
	
# To be used on the server only
func server_get_player_seat() -> PlayerSeat:
	for player: PlayerSeat in game_state_data.player_seats.values():
		var account_data: ConnectedPlayer = game_state_data.try_get_connected_player_data(multiplayer.get_remote_sender_id())
		if player.account_id == account_data.account_id:
			Log.message_formatted("Found player!", player.to_dict())
			return player
			
	Log.message("No player seat found, returning null")
	return null


## Debug helpers


func debug_assign_player_seats() -> void:
	for player: ConnectedPlayer in game_state_data.connected_players.values():
		assign_player_to_seat(player.peer_id, 1)
	for seat: PlayerSeat in game_state_data.player_seats.values():
		if seat.account_id != "":
			seat.is_ready = true


func debug_goto_start_game() -> void:
	reset_hand()
	debug_assign_player_seats()
	step_next_game_state()


func debug_goto_deal_flop() -> void:
	reset_hand()
	debug_assign_player_seats()
	step_next_game_state()
	for player_seat: PlayerSeat in game_state_data.player_seats.values():
		if player_seat.account_id != "":
			player_seat.bet_value = GameStateData.default_big_blind
			player_seat.hand_cash -= GameStateData.default_big_blind
			game_state_data.pot_value += GameStateData.default_big_blind
	step_next_game_state()
	
	
func debug_goto_end_step() -> void:
	debug_goto_deal_flop()
	step_next_game_state()
	step_next_game_state()
	step_next_game_state()
