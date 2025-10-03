extends Control

@export var player_scene: PackedScene = preload("res://scenes/player.tscn")
@export var seat_select_button_scene: PackedScene = preload("res://scenes/UI/seat_button.tscn")

var game_manager
var poker_table_position
var screen_origin
var table_radius = 225
var player_seats: Dictionary[int, PlayerSeat]
var seat_nodes: Dictionary[int, Node]
var player_data: ConnectedPlayer

func _ready() -> void:
	game_manager = get_parent().get_node("GameManager")
	game_manager.player_seats_updated_signal.connect(_on_player_seats_updated)
	game_manager.game_state_data.connected_players_updated_signal.connect(_on_connected_players_updated)
	game_manager.game_state_change_signal.connect(_on_game_state_change)
	game_manager.current_player_turn_updated_signal.connect(_on_player_turn_updated)
	var seats_in_group = get_tree().get_nodes_in_group("seats")
	for seat in seats_in_group:
		var seat_id = seat.seat_number
		seat_nodes[seat_id] = seat

func _draw() -> void:
	screen_origin = get_viewport_rect().size / 2

func _on_game_state_change(old_game_state, new_game_state):
	if new_game_state != GameState.State.PreHand:
		for seat in seat_nodes.values():
			seat.visible = false
		
func _on_connected_players_updated(old_connected_players, new_connected_players):
	var current_player = game_manager.game_state_data.connected_players.get(multiplayer.get_unique_id())
	for player_seat in game_manager.player_seats.values():
		if (current_player.id == player_seat.player_id):
			player_seat.player_node.get_node("PlayerCard/CashAmount").text = "$" + str(current_player.current_cash)
	
func _on_player_seats_updated(old_player_seats, new_player_seats):
	player_seats = new_player_seats
	redraw_table_players()
	

func _on_player_turn_updated(player_turn):
	redraw_table_players()
	
func redraw_table_players():
	var poker_table = $PokerTable
	
	# Clear player seats first
	for seat_id in player_seats.keys():
		if (player_seats[seat_id].player_node != null):
			remove_child(player_seats[seat_id].player_node)
			player_seats[seat_id].player_node = null
		seat_nodes[seat_id].visible = true
	
	# Then spawn any players and hide seat buttons
	print("current turn: %s" % [game_manager.game_state_data.current_player_turn])
	for seat_id in player_seats.keys():
		var seat_data = player_seats[seat_id]
		var seat_node = seat_nodes[seat_id]
		if seat_data.player_id != 0:
			var player_instance = player_scene.instantiate()
			# Need to transform seat position coords from local scale to global scale (0.4 -> 1)
			player_instance.position = (poker_table.scale * seat_node.position)
			player_instance.player_id = seat_data.player_id
			player_instance.is_player_turn = game_manager.game_state_data.current_player_turn == seat_data.player_id
			player_instance.current_cash = game_manager.game_state_data.connected_players.get(seat_data.player_id).current_cash
			player_instance.is_folded = seat_data.is_folded
			player_instance.is_big_blind = seat_data.is_big_blind
			player_instance.is_small_blind = seat_data.is_small_blind
			seat_data.player_node = player_instance
			add_child(player_instance)
			seat_nodes[seat_id].visible = false
