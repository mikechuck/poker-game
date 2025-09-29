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
	game_manager.connected_players_updated_signal.connect(_on_connected_players_updated)
	game_manager.game_state_change_signal.connect(_on_game_state_change)
	var seats_in_group = get_tree().get_nodes_in_group("seats")
	for seat in seats_in_group:
		var seat_id = seat.seat_number
		seat_nodes[seat_id] = seat

func _draw() -> void:
	screen_origin = get_viewport_rect().size / 2

func _on_game_state_change(old_game_state, new_game_state):
	print("table got new game state")
	for seat in seat_nodes.values():
		seat.visible = false
		
func _on_connected_players_updated(old_connected_players, new_connected_players):
	for connected_player in new_connected_players.values():
		for player_seat in player_seats.values():
			if (connected_player.id == player_seat.player_id):
				pass
				#player_seat.player_node.get_node("CashAmount").text = "$100"
		#if connected_player.id == game_manager.player_data.id:
			#print("matched player")
			#player_data = connected_player
			##$Player/PlayerCard/CashAmount.text = "$100"
	
func _on_player_seats_updated(old_player_seats, new_player_seats):
	var poker_table = $PokerTable
	
	# Clear player seats first
	for seat_id in player_seats.keys():
		if (player_seats[seat_id].player_node != null):
			remove_child(player_seats[seat_id].player_node)
			player_seats[seat_id].player_node = null
		seat_nodes[seat_id].visible = true
	
	# Then spawn any players and hide seat buttons
	for seat_id in new_player_seats.keys():
		var seat_data = new_player_seats[seat_id]
		var seat_node = seat_nodes[seat_id]
		if seat_data.player_id != 0:
			var player_instance = player_scene.instantiate()
			# Need to transform seat position coords from local scale to global scale (0.4 -> 1)
			player_instance.position = (poker_table.scale * seat_node.position)
			player_instance.player_id = seat_data.player_id
			seat_data.player_node = player_instance
			add_child(player_instance)
			seat_nodes[seat_id].visible = false
			
	# Set new data
	player_seats = new_player_seats
