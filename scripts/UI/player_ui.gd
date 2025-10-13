extends Control

### Scenes
@export var card_scene: PackedScene = preload("res://scenes/UI/card.tscn")

var check_button = null
var raise_button = null
var call_button = null
var fold_button = null

var game_manager = null
var server_manager = null

### UI nodes
var player_actions_pre_game_host_node = null
var player_actions_pre_game_guest_node = null
var player_actions_ante_node = null
var player_actions_game_node = null
var ready_toggle = null
var status_message = null
var hole_cards_node = null
var start_button_node = null
var bet_input_value = 0

func _ready() -> void:
	game_manager = get_parent().get_node("GameManager")
	server_manager = get_parent().get_node("ServerManager")
	game_manager.game_state_data_updated_signal.connect(_on_game_state_data_updated)
	player_actions_pre_game_host_node = $PlayerActionsPreHandHost
	player_actions_pre_game_guest_node = $PlayerActionsPreHandGuest
	player_actions_ante_node = $PlayerActionsAnte
	player_actions_game_node = $PlayerActionsGame
	status_message = $StatusMessage/Text
	hole_cards_node = $HoleCards
	start_button_node = $PlayerActionsPreHandHost/Start/StartButton
	
	check_button = player_actions_game_node.get_node("Check/CheckButton")
	raise_button = player_actions_game_node.get_node("Bet/RaiseButton")
	call_button = player_actions_game_node.get_node("Call/CallButton")
	fold_button = player_actions_game_node.get_node("Fold/FoldButton")
	
func _on_game_state_data_updated(old_game_state_data, new_game_state_data):
	set_status_message()
	if (old_game_state_data.connected_players != new_game_state_data.connected_players):
		handle_connected_players_updated(old_game_state_data.connected_players, new_game_state_data.connected_players)
	if (old_game_state_data.game_state != new_game_state_data.game_state):
		handle_game_state_change(old_game_state_data.game_state, new_game_state_data.game_state)
	if (old_game_state_data.player_seats != new_game_state_data.player_seats):
		handle_player_seats_updated(old_game_state_data.player_seats, new_game_state_data.player_seats)
	if (old_game_state_data.player_turn != new_game_state_data.player_turn):
		handle_player_turn_updated(old_game_state_data.player_turn, new_game_state_data.player_turn)

func handle_connected_players_updated(old_connected_players, new_connected_players):
	set_player_buttons()
	set_player_data()

func handle_game_state_change(old_game_state, new_game_state) -> void:
	set_player_buttons()

func handle_player_seats_updated(old_player_seats, new_player_seats) -> void:
	update_hole_cards()

func handle_player_turn_updated(old_player_turn, new_player_turn) -> void:
	set_player_buttons()
	
func set_status_message() -> void:
	status_message.visible = false
	match game_manager.game_state_data.game_state:
		GameState.State.BetHole, GameState.State.BetFlop, GameState.State.BetTurn, GameState.State.BetRiver:
			if (is_client_turn()):
				status_message.visible = true
				set_status_text("Your turn")
		GameState.State.HandOver:
			if (true):
				status_message.visible = true
				set_status_text("YOU WON")
	
func set_player_buttons():
	player_actions_pre_game_host_node.visible = false
	player_actions_pre_game_guest_node.visible = false
	player_actions_ante_node.visible = false
	player_actions_game_node.visible = false
	start_button_node.disabled = false
	# Match on game state to decide which buttons to show
	match game_manager.game_state_data.game_state:
		GameState.State.PreHand:
			if (!game_manager.client_get_player_data().is_spectating):
				if (game_manager.client_get_player_data().is_host):
					player_actions_pre_game_host_node.visible = true
					# Only enable start button if all players are ready
					for seat in game_manager.game_state_data.player_seats.values():
						if seat.player_id != 0 && !seat.is_ready:
							start_button_node.disabled = true
				else:
					player_actions_pre_game_guest_node.visible = true
		GameState.State.BetHole:
			var current_turn_player_seat_data = get_current_turn_seat_data()
			if is_client_turn():
				if (current_turn_player_seat_data.is_big_blind || current_turn_player_seat_data.is_small_blind) && current_turn_player_seat_data.bet_value == 0:
					player_actions_ante_node.visible = true
					# Set ante button value based on blind state
					if (current_turn_player_seat_data.is_small_blind):
						player_actions_ante_node.get_node("Ante/AnteButton").text = "Bet $%s" % GameStateData.default_small_blind
					if (current_turn_player_seat_data.is_big_blind):
						player_actions_ante_node.get_node("Ante/AnteButton").text = "Bet $%s" % GameStateData.default_big_blind
				else:
					set_bet_buttons()
		GameState.State.BetFlop, GameState.State.BetTurn, GameState.State.BetRiver:
			if is_client_turn():
				set_bet_buttons()

func set_bet_buttons():
	var current_turn_player_seat_data = get_current_turn_seat_data()
	player_actions_game_node.visible = true
	call_button.disabled = false
	check_button.disabled = false
	if game_manager.game_state_data.current_bet_value == 0:
		raise_button.text = "Bet"
	else:
		raise_button.text = "Raise"
	# Set the minimum bet input to the difference of player's current bet and the table bet
	var bet_diff = game_manager.game_state_data.current_bet_value
	if game_manager.game_state_data.current_bet_value == current_turn_player_seat_data.bet_value:
		# We can check but not call
		call_button.disabled = true
	if game_manager.game_state_data.current_bet_value > current_turn_player_seat_data.bet_value:
		# We can call but not check
		check_button.disabled = true
	
func update_hole_cards():
	for player_seat in game_manager.game_state_data.player_seats.values():
		if player_seat.player_id == game_manager.client_get_player_data().id && player_seat.hole_cards.size() > 0:
			for i in range(2):
				var card_data = player_seat.hole_cards[i]
				var card_instance = card_scene.instantiate()
				var hole_card_spot = get_node("HoleCards/HoleCardSpot%s" % [i])
				card_instance.value = card_data.value
				card_instance.suit = card_data.suit
				card_instance.position = hole_card_spot.position
				card_instance.scale = hole_card_spot.scale
				hole_cards_node.add_child(card_instance)
				
func set_player_data():
	var player_name_node = $PlayerName/Value
	var player_is_host_node = $IsHost/Value
	player_name_node.clear()
	player_name_node.append_text(str(game_manager.client_get_player_data().id))
	player_is_host_node.clear()
	player_is_host_node.append_text(str(game_manager.client_get_player_data().is_host))
	
	## Debug fields
	var game_state_label = $Debug/GameState
	game_state_label.text = "Game state: %s" % GameState.State.keys()[game_manager.game_state_data.game_state]
	
func is_client_turn() -> bool:
	if (game_manager.game_state_data.player_turn != 0):
		return game_manager.game_state_data.player_seats[game_manager.game_state_data.player_turn].player_id == game_manager.client_get_player_data().id
	else:
		return false

func get_current_turn_seat_data() -> PlayerSeat:
	return game_manager.game_state_data.player_seats[game_manager.game_state_data.player_turn]

func set_status_text(text: String) -> void:
	status_message.text = "[font_size=26]" + text + "[/font_size]"
	
### Start button signal methods ###

### Debug buttons

func _on_debug_start_game_pressed() -> void:
	server_manager.call_debug_start_game.rpc_id(1)

func _on_debug_deal_flop_pressed() -> void:
	server_manager.call_debug_deal_flop.rpc_id(1)
	
func _on_debug_end_step_pressed() -> void:
	server_manager.call_debug_end_step.rpc_id(1)

### PlayerActionsPreHand
func _on_ready_button_toggled(toggled_on: bool) -> void:
	server_manager.set_ready_status.rpc_id(1, toggled_on)

func _on_start_button_pressed() -> void:
	server_manager.player_action_taken.rpc_id(1, PlayerTurnAction.Action.StartGame)
	
### PlayerActionsAnte
func _on_fold_button_pressed() -> void:
	server_manager.player_action_taken.rpc_id(1, PlayerTurnAction.Action.Fold)
	
func _on_ante_button_pressed() -> void:
	var bet_amount = 0
	if (get_current_turn_seat_data().is_small_blind):
		bet_amount = GameStateData.default_small_blind
	elif (get_current_turn_seat_data().is_big_blind):
		bet_amount = GameStateData.default_big_blind
	server_manager.player_action_taken.rpc_id(1, PlayerTurnAction.Action.Ante)
	
### PlayerActionsGame

func _on_check_button_pressed() -> void:
	server_manager.player_action_taken.rpc_id(1, PlayerTurnAction.Action.Check)

func _on_call_button_pressed() -> void:
	server_manager.player_action_taken.rpc_id(1, PlayerTurnAction.Action.Call)

func _on_bet_input_changed(value: float) -> void:
	bet_input_value = value
	if bet_input_value > 0:
		raise_button.disabled = false
	else:
		raise_button.disabled = true
	
func _on_bet_button_pressed() -> void:
	server_manager.player_action_taken.rpc_id(1, PlayerTurnAction.Action.Raise, bet_input_value)
	
func _on_show_cards_button_pressed() -> void:
	server_manager.show_player_cards.rpc_id(1)
	
## End button signal methods
