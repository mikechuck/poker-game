extends Node

var game_manager
var client_manager

func _ready() -> void:
	# Don't call managers that are lower on the stack from _ready(), they won't exist yet
	game_manager = get_parent().get_node("GameManager")
	client_manager = get_parent().get_node("ClientManager")

func start_server():
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_server(game_manager.server_port)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Started server at ws://localhost:%s ..." % [game_manager.server_port])
	
func _on_peer_connected(id):
	var connected_player = ConnectedPlayer.new()
	connected_player.id = id
	connected_player.starting_cash = game_manager.default_starting_cash
	connected_player.current_cash = game_manager.default_starting_cash
	game_manager.connected_players[id] = connected_player
	# If this was the first player to connect, set it as host player
	if (game_manager.host_player == null):
		game_manager.host_player = connected_player
		connected_player.is_host = true
	# For some reason, need to send to existing clients AND new client, maybe they don't exist in the stack yet
	client_manager.update_connected_players_list.rpc(game_manager.serialize_connected_players())
	client_manager.update_connected_players_list.rpc(id, game_manager.serialize_connected_players())
	print("Number of players connected: %s" % [game_manager.connected_players.size()])
	
func _on_peer_disconnected(id):
	var disconnecting_player = game_manager.connected_players.get(id)
	game_manager.connected_players.erase(id)
	if disconnecting_player.is_host:
		if (game_manager.connected_players.values().size() > 0):
			var new_host_id = game_manager.connected_players.keys()[0]
			game_manager.host_player = game_manager.connected_players.get(new_host_id)
		else:
			game_manager.host_player = null
			game_manager.current_game_state = GameState.State.PreGame
	# Clear the player from the seat
	for seat in game_manager.player_seats.values():
		if seat.player_id == id:
			seat.player_id = 0
			seat.player_node = null
	client_manager.update_connected_players_list.rpc(game_manager.serialize_connected_players())
	client_manager.update_player_seats_list.rpc(game_manager.serialize_player_seats())
	print("Number of players connected: %s" % [game_manager.connected_players.size()])

### RPC Functions

@rpc("reliable", "any_peer")
func request_seat(seat_number: int):
	var client_id = multiplayer.get_remote_sender_id()
	# Check to see if seat is already filled
	seat_number = game_manager.get_next_free_seat(seat_number)
	# First remove them from their current seat then put them in the new seat
	var desired_seat = game_manager.player_seats.get(seat_number)
	for seat in game_manager.player_seats.values():
		if (seat.player_id == client_id):
			seat.player_id = 0
	desired_seat.player_id = client_id
	game_manager.player_seats[seat_number] = desired_seat
	game_manager.connected_players[client_id].is_spectating = false
	client_manager.update_connected_players_list.rpc(game_manager.serialize_connected_players())
	client_manager.update_player_seats_list.rpc(game_manager.serialize_player_seats())
	
@rpc("reliable", "any_peer")
func set_ready_status(is_ready: bool):
	game_manager.connected_players[multiplayer.get_remote_sender_id()].is_ready = is_ready
	client_manager.update_connected_players_list.rpc(game_manager.serialize_connected_players())
	
@rpc("reliable", "any_peer")
func start_game():
	var requestor_id = multiplayer.get_remote_sender_id()
	# Ensure all players are ready before starting
	var all_players_ready = true
	for player in game_manager.connected_players.values():
		if !player.is_spectating && !player.is_ready:
			all_players_ready = false
	if (game_manager.host_player.id == requestor_id &&
		game_manager.current_game_state == GameState.State.PreGame &&
		all_players_ready):
		#set_game_state(GameState.State.Shuffle)
		game_manager.step_next_game_state()

### Helper functions

func set_player_seats():
	for i in range(1, 9):
		var player_seat = PlayerSeat.new()
		player_seat.player_id = 0
		game_manager.player_seats[i] = player_seat
	
