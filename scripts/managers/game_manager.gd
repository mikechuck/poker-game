extends Node2D

### Networking fields
var is_server = false
const server_ip_address = "0.0.0.0"
const server_port = 8083

### Scenes
@export var player_scene: PackedScene = preload("res://scenes/player.tscn")
@export var player_ui_scene: PackedScene = preload("res://scenes/UI/player_ui.tscn")
@export var card_scene: PackedScene = preload("res://scenes/UI/card.tscn")

### Instantiated scenes
var player_ui_instance = null

### Managers
var server_manager
var client_manager

### Signals
signal connected_players_updated_signal(old_connected_playes, new_connected_players)
signal player_seats_updated_signal(old_player_seats, new_player_seats)
signal game_state_change_signal(old_game_state, new_game_state)

### UI Fields
var screen_origin
var single_angle = PI / 4
var table_radius = 225

### Server fields
var host_player: ConnectedPlayer = null
var connected_players: Dictionary[int, ConnectedPlayer] = {}
var player_seats: Dictionary[int, PlayerSeat] = {}
var default_starting_cash = 100
var current_game_state = GameState.State.PreGame

### Client fields
var player_data = null

### Start lifecycle methods

func _ready() -> void:
	server_manager = get_parent().get_node("ServerManager")
	client_manager = get_parent().get_node("ClientManager")
	
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
		queue_redraw()
		
func _process(delta: float) -> void:
	pass

func _draw() -> void:
	pass
	
### End lifecycle methods

### Game cycle methods
func step_next_game_state():
	match current_game_state:
		GameState.State.PreGame:
			current_game_state = GameState.State.DealHole
			client_manager.game_state_change.rpc(GameState.State.PreGame, GameState.State.DealHole)
			deal_hole_cards()
		GameState.State.DealHole:
			current_game_state = GameState.State.Ante
			client_manager.game_state_change.rpc(GameState.State.DealHole, GameState.State.Ante)

func deal_hole_cards():
	var card_instance = card_scene.instantiate()
	card_instance.load_card_image("2", "D")
	add_child(card_instance)
	pass
		
###################################### Helper Functions #############################################

# Converts a dict of custom objects to dict of generic objects
func serialize_player_seats() -> Dictionary:
	var player_seats_dict = {}
	for player_id in player_seats:
		player_seats_dict[player_id] = player_seats[player_id].to_dict()
	return player_seats_dict
	
func deserialize_player_seats(new_player_seats) -> Dictionary[int, PlayerSeat]:
	var deserialized_player_seats: Dictionary[int, PlayerSeat] = {}
	for id in new_player_seats.keys():
		deserialized_player_seats[id] = PlayerSeat.from_dict(new_player_seats[id])
	return deserialized_player_seats
	
func serialize_connected_players() -> Dictionary:
	var connected_players_dict = {}
	for player_id in connected_players:
		connected_players_dict[player_id] = connected_players[player_id].to_dict()
	return connected_players_dict
	
func deserialize_connected_players(new_connected_players) -> Dictionary[int, ConnectedPlayer]:
	var deserialized_connected_players: Dictionary[int, ConnectedPlayer] = {}
	for id in new_connected_players.keys():
		deserialized_connected_players[id] = ConnectedPlayer.from_dict(new_connected_players[id])
	return deserialized_connected_players
	
func get_next_free_seat(seat_number):
	var desired_seat = player_seats.get(seat_number)
	if (desired_seat.player_id != 0):
		seat_number = (seat_number + 1) % 8
		desired_seat = player_seats.get(seat_number)
		seat_number = get_next_free_seat(seat_number)
	return seat_number
