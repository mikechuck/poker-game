extends Control

@export var player_scene: PackedScene = preload("res://scenes/player.tscn")
@export var seat_select_button_scene: PackedScene = preload("res://scenes/UI/seat_button.tscn")
@export var card_scene: PackedScene = preload("res://scenes/UI/card.tscn")

var game_manager
var poker_table_position
var screen_origin
var table_radius = 225
var player_seats: Dictionary[int, PlayerSeat]
var seat_nodes: Dictionary[int, Node]
var player_data: ConnectedPlayer
var board_card_scale: float = 0.8

@onready var poker_table_node = $PokerTable
@onready var pot_value_node = $PokerTable/Pot/Value
@onready var board_cards_node = $PokerTable/Cards

func _ready() -> void:
	game_manager = get_parent().get_node("GameManager")
	game_manager.game_state_data_updated_signal.connect(_on_game_state_data_change)
	var seats_in_group = get_tree().get_nodes_in_group("seats")
	for seat in seats_in_group:
		var seat_id = seat.seat_number
		seat_nodes[seat_id] = seat

func _on_game_state_data_change(old_game_state_data, new_game_state_data):
	handle_game_state_updated()
	handle_player_seats_updated()
	handle_player_turn_updated()
	handle_board_cards_updated()
	if (old_game_state_data.connected_players != new_game_state_data.connected_players):
		handle_connected_players_updated(old_game_state_data.connected_players, new_game_state_data.connected_players)

func handle_game_state_updated():
	for seat in seat_nodes.values():
		if game_manager.game_state_data.game_state == GameState.State.PreHand:
			seat.visible = true
		else:
			seat.visible = false
			
func handle_connected_players_updated(old_connected_players, new_connected_players):
	pass
	
func handle_player_seats_updated():
	for player_seat in game_manager.game_state_data.player_seats.values():
		if (multiplayer.get_unique_id() == player_seat.player_id && player_seat.player_node):
			player_seat.player_node.get_node("PlayerCard/CashAmount").text = "$" + str(player_seat.hand_cash)
	redraw_table_players()

func handle_player_turn_updated():
	redraw_table_players()
	
func handle_board_cards_updated():
	var board_cards = game_manager.game_state_data.board_cards
	# clear cards first, then redraw
	for card in get_tree().get_nodes_in_group("board_cards"):
			board_cards_node.remove_child(card)
	if (board_cards.size() > 0):
		for i in range(5):
			var card_spot = board_cards_node.get_node("DealerCardSpot" + str(i + 1))
			if i < board_cards.size():
				var card_data = board_cards[i]
				var card_instance = card_scene.instantiate()
				card_instance.value = card_data.value
				card_instance.suit = card_data.suit
				card_instance.position = card_spot.position
				card_instance.scale = Vector2(board_card_scale, board_card_scale)
				board_cards_node.add_child(card_instance)
				card_spot.visible = false
				card_instance.add_to_group("board_cards")
			else:
				card_spot.visible = true
	else:
		for i in range(5):
			board_cards_node.get_node("DealerCardSpot" + str(i + 1)).visible = true
		
func redraw_table_players():
	# Set pot value
	if (game_manager.game_state_data.game_state != GameState.State.PreHand):
		pot_value_node.visible = true
		pot_value_node.text = "Pot: $%s" % [game_manager.game_state_data.pot_value]
	else:
		pot_value_node.visible = false
	
	# Clear player seats first
	for seat_id in player_seats.keys():
		if (player_seats[seat_id].player_node != null):
			remove_child(player_seats[seat_id].player_node)
			player_seats[seat_id].player_node = null
		if (game_manager.game_state_data.game_state == GameState.State.PreHand):
			seat_nodes[seat_id].visible = true
	
	# Then spawn any players and hide seat buttons
	player_seats = game_manager.game_state_data.player_seats
	for seat_id in player_seats.keys():
		var seat_data = player_seats[seat_id]
		var seat_node = seat_nodes[seat_id]
		if seat_data.player_id != 0:
			var player_instance = player_scene.instantiate()
			# Need to transform seat position coords from local scale to global scale (0.4 -> 1)
			player_instance.position = (poker_table_node.scale * seat_node.position)
			player_instance.player_id = seat_data.player_id
			player_instance.is_player_turn = game_manager.game_state_data.player_turn == seat_id
			player_instance.hand_cash = seat_data.hand_cash
			player_instance.bet_value = seat_data.bet_value
			player_instance.is_folded = seat_data.is_folded
			player_instance.is_big_blind = seat_data.is_big_blind
			player_instance.is_small_blind = seat_data.is_small_blind
			player_instance.hole_cards = seat_data.hole_cards
			player_instance.is_winner = game_manager.game_state_data.winner_player_id == seat_data.player_id
			seat_data.player_node = player_instance
			add_child(player_instance)
			seat_nodes[seat_id].visible = false
	
