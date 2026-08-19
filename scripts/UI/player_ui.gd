extends Control
class_name PlayerUI

### Scenes
@export var card_scene: PackedScene = preload("res://scenes/UI/card.tscn")

### Managers
@onready var game_manager: GameSceneManager = get_parent().get_node("GameManager")
@onready var client_manager: ClientManager = get_parent().get_node("ClientManager")
@onready var server_manager: ServerManager = get_parent().get_node("ServerManager")

### UI nodes
@onready var player_actions_pre_game_host_node: Control = $PlayerActionsPreHandHost
@onready var player_actions_pre_game_guest_node: Control = $PlayerActionsPreHandGuest
@onready var player_actions_ante_node: Control = $PlayerActionsAnte
@onready var player_actions_game_node: Control = $PlayerActionsGame
@onready var player_actions_hand_over_node: Control = $PlayerActionsHandOver
@onready var ready_toggle_guest: CheckButton = $PlayerActionsPreHandGuest/Ready/ReadyButton
@onready var ready_toggle_host: CheckButton = $PlayerActionsPreHandHost/Ready/ReadyButton
@onready var status_message: RichTextLabel = $StatusMessage/Text
@onready var hole_cards_node: Control = $HoleCards
@onready var start_button_node: Button = $PlayerActionsPreHandHost/Start/StartButton
@onready var bet_input_value: int = 0
@onready var check_button: Button = $PlayerActionsGame/Check/CheckButton
@onready var raise_button: Button = $PlayerActionsGame/Bet/RaiseButton
@onready var call_button: Button = $PlayerActionsGame/Call/CallButton
@onready var fold_button: Button = $PlayerActionsGame/Fold/FoldButton
@onready var ante_button: Button = $PlayerActionsAnte/Ante/AnteButton
@onready var game_state_label: RichTextLabel = $Debug/Container/GameState

func _ready() -> void:
	game_manager.game_state_data_updated_signal.connect(_on_game_state_data_updated)
	
func _on_game_state_data_updated(old_game_state_data: GameStateData, new_game_state_data: GameStateData):
	set_status_message()
	if (old_game_state_data.connected_players != new_game_state_data.connected_players):
		handle_connected_players_updated()
	if (old_game_state_data.game_state != new_game_state_data.game_state):
		handle_game_state_change()
	if (old_game_state_data.player_seats != new_game_state_data.player_seats):
		handle_player_seats_updated(old_game_state_data.player_seats, new_game_state_data.player_seats)
	if (old_game_state_data.player_turn != new_game_state_data.player_turn):
		handle_player_turn_updated()
		
	game_state_label.text = "Game state: %s" % GameState.State.keys()[game_manager.game_state_data.game_state]

func handle_connected_players_updated() -> void:
	set_player_buttons()
	set_player_data()

func handle_game_state_change() -> void:
	set_player_buttons()

func handle_player_seats_updated(old_player_seats: Dictionary[int, PlayerSeat], new_player_seats: Dictionary[int, PlayerSeat]) -> void:
	for seat: PlayerSeat in new_player_seats.values():
		if seat.peer_id == multiplayer.get_unique_id():
			ready_toggle_guest.button_pressed = seat.is_ready
			ready_toggle_host.button_pressed = seat.is_ready
	update_hole_cards()

func handle_player_turn_updated() -> void:
	set_player_buttons()
	
func set_status_message() -> void:
	status_message.visible = false
	match game_manager.game_state_data.game_state:
		GameState.State.BetHole, GameState.State.BetFlop, GameState.State.BetTurn, GameState.State.BetRiver:
			if (is_client_turn()):
				status_message.visible = true
				set_status_text("Your turn")
		GameState.State.HandOver:
			if (is_client_winner()):
				status_message.visible = true
				set_status_text("YOU WON")
			else:
				status_message.visible = false
	
func set_player_buttons() -> void:
	player_actions_pre_game_host_node.visible = false
	player_actions_pre_game_guest_node.visible = false
	player_actions_ante_node.visible = false
	player_actions_game_node.visible = false
	player_actions_hand_over_node.visible = false
	start_button_node.disabled = false
	# Match on game state to decide which buttons to show
	match game_manager.game_state_data.game_state:
		GameState.State.PreHand:
			var player_data: ConnectedPlayer = game_manager.client_get_player_data(DataStore.account_data.accountId)
			if (!player_data.is_spectating):
				if (player_data.is_host):
					player_actions_pre_game_host_node.visible = true
					# Only enable start button if all players are ready
					for seat in game_manager.game_state_data.player_seats.values():
						if seat.peer_id != 0 && !seat.is_ready:
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
						ante_button.text = "Bet $%s" % GameStateData.default_small_blind
					if (current_turn_player_seat_data.is_big_blind):
						ante_button.text = "Bet $%s" % GameStateData.default_big_blind
				else:
					set_bet_buttons()
		GameState.State.BetFlop, GameState.State.BetTurn, GameState.State.BetRiver:
			if is_client_turn():
				set_bet_buttons()
		GameState.State.HandOver:
			player_actions_hand_over_node.visible = is_client_host()

func set_bet_buttons() -> void:
	var current_turn_player_seat_data: PlayerSeat = get_current_turn_seat_data()
	player_actions_game_node.visible = true
	call_button.disabled = false
	check_button.disabled = false
	if game_manager.game_state_data.current_bet_value == 0:
		raise_button.text = "Bet"
	else:
		raise_button.text = "Raise"
	# Set the minimum bet input to the difference of player's current bet and the table bet
	if game_manager.game_state_data.current_bet_value == current_turn_player_seat_data.bet_value:
		# We can check but not call
		call_button.disabled = true
	if game_manager.game_state_data.current_bet_value > current_turn_player_seat_data.bet_value:
		# We can call but not check
		check_button.disabled = true
	
func update_hole_cards() -> void:
	for player_seat: PlayerSeat in game_manager.game_state_data.player_seats.values():
		if player_seat.peer_id == game_manager.client_get_player_data(DataStore.account_data.accountId).peer_id:
			if player_seat.hole_cards.size() > 0:
				for i in range(2):
					var card_data = player_seat.hole_cards[i]
					var card_instance: Card = card_scene.instantiate()
					var hole_card_spot: Sprite2D = get_node("HoleCards/HoleCardSpot%s" % [i])
					card_instance.value = card_data.value
					card_instance.suit = card_data.suit
					card_instance.position = hole_card_spot.position
					card_instance.scale = hole_card_spot.scale
					hole_cards_node.add_child(card_instance)
					card_instance.add_to_group("hole_cards")
			else:
				for card in get_tree().get_nodes_in_group("hole_cards"):
					card.queue_free()
					#hole_cards_node.remove_child(card)
				
func set_player_data() -> void:
	## Debug fields
	game_state_label.text = "Game state: %s" % GameState.State.keys()[game_manager.game_state_data.game_state]
	
func is_client_turn() -> bool:
	if (game_manager.game_state_data.player_turn != 0):
		var player_data: ConnectedPlayer = game_manager.client_get_player_data(DataStore.account_data.accountId)
		return game_manager.game_state_data.player_seats[game_manager.game_state_data.player_turn].peer_id == player_data.peer_id
	else:
		return false
		
func is_client_host() -> bool:
	return game_manager.game_state_data.connected_players[multiplayer.get_unique_id()].is_host
		
func is_client_winner() -> bool:
	return game_manager.game_state_data.winner_peer_id == multiplayer.get_unique_id()

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
#
### PlayerActionsPreHand
func _on_ready_button_toggled(toggled_on: bool) -> void:
	server_manager.set_ready_status.rpc_id(1, toggled_on)

func _on_start_button_pressed() -> void:
	server_manager.player_action_taken.rpc_id(1, PlayerTurnAction.Action.StartGame)

### PlayerActionsAnte
func _on_fold_button_pressed() -> void:
	server_manager.player_action_taken.rpc_id(1, PlayerTurnAction.Action.Fold)
	
func _on_ante_button_pressed() -> void:
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
	
func _on_start_new_hand_button_pressed() -> void:
	server_manager.start_new_hand.rpc_id(1)
	
func _on_goto_lobby_button_pressed() -> void:
	server_manager.goto_lobby.rpc_id(1)
	
	
## End button signal methods
