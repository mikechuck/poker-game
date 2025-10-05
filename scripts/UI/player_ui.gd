extends Control

### Scenes
@export var card_scene: PackedScene = preload("res://scenes/UI/card.tscn")

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
	if (is_client_turn()):
		status_message.visible = true
		set_status_text("Your turn")
	else:
		status_message.visible = false
	
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
					for player in game_manager.game_state_data.connected_players.values():
						if !player.is_spectating && !player.is_ready:
							start_button_node.disabled = true
				else:
					player_actions_pre_game_guest_node.visible = true
		GameState.State.BetHole:
			if game_manager.game_state_data.player_turn > 0:
				if is_client_turn():
					var current_turn_player_seat_data = get_current_turn_seat_data()
					player_actions_ante_node.visible = true
					# Set ante button value based on blind state
					if (current_turn_player_seat_data.is_small_blind):
						player_actions_ante_node.get_node("Ante/AnteButton").text = "Bet $%s" % game_manager.default_small_blind
					if (current_turn_player_seat_data.is_big_blind):
						player_actions_ante_node.get_node("Ante/AnteButton").text = "Bet $%s" % game_manager.default_big_blind
		GameState.State.DealFlop:
			if game_manager.game_state_data.player_turn > 0:
				if is_client_turn():
					var current_turn_player_seat_data = get_current_turn_seat_data()
					player_actions_game_node.visible = true
	
func update_hole_cards():
	for player_seat in game_manager.game_state_data.player_seats.values():
		if player_seat.player_id == game_manager.client_get_player_data().id && player_seat.hole_cards.size() > 0:
			for i in range(2):
				var card_data = player_seat.hole_cards[i]
				var card_instance = card_scene.instantiate()
				card_instance.number = card_data.number
				card_instance.suit = card_data.suit
				card_instance.position = get_node("HoleCards/HoleCardSpot%s" % [i]).position
				hole_cards_node.add_child(card_instance)
				
func set_player_data():
	var player_name_node = $PlayerName/Value
	var player_is_host_node = $IsHost/Value
	player_name_node.clear()
	player_name_node.append_text(str(game_manager.client_get_player_data().id))
	player_is_host_node.clear()
	player_is_host_node.append_text(str(game_manager.client_get_player_data().is_host))
	
func is_client_turn() -> bool:
	if (game_manager.game_state_data.player_turn != 0):
		return game_manager.game_state_data.player_seats[game_manager.game_state_data.player_turn].player_id == game_manager.client_get_player_data().id
	else:
		return false

func get_current_turn_seat_data() -> PlayerSeat:
	return game_manager.game_state_data.player_seats[game_manager.game_state_data.player_turn]

func set_status_text(text: String) -> void:
	status_message.text = "[font_size=26]" + text + "[/font_size]"
	
### Button signal methods ###

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
		bet_amount = game_manager.default_small_blind
	elif (get_current_turn_seat_data().is_big_blind):
		bet_amount = game_manager.default_big_blind
	server_manager.player_action_taken.rpc_id(1, PlayerTurnAction.Action.Bet, bet_amount)
