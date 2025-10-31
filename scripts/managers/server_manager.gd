extends Node

var game_manager
var client_manager

func _ready() -> void:
	# Don't call managers that are lower on the stack from _ready(), they won't exist yet
	game_manager = get_parent().get_node("GameManager")
	client_manager = get_parent().get_node("ClientManager")

func start_server():
	var args = OS.get_cmdline_args()
	var server_port = args.find("port")
	if server_port == -1:
		server_port = 8083
	print("port %s" % server_port)
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_server(server_port)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Started server at ws://localhost:%s ..." % [server_port])
	
func _on_peer_connected(id):
	print("Player %s connected" % id)
	var connected_player = ConnectedPlayer.new()
	connected_player.id = id
	# Don't set default balance - wait for client to provide actual balance from API
	# Set to -1 to indicate balance not loaded yet
	connected_player.account_total_cash = -1
	game_manager.game_state_data.connected_players[id] = connected_player
	# If this was the first player to connect, set it as host player
	if (game_manager.game_state_data.host_player_id == 0):
		game_manager.game_state_data.host_player_id = connected_player.id
		connected_player.is_host = true
	print("Number of players connected: %s" % [game_manager.game_state_data.connected_players.size()])
	# Client will call register_player_auth RPC to send JWT token, then server fetches balance
	
func _on_peer_disconnected(id):
	var disconnecting_player = game_manager.game_state_data.connected_players.get(id)
	game_manager.game_state_data.connected_players.erase(id)
	if disconnecting_player.is_host:
		if (game_manager.game_state_data.connected_players.values().size() > 0):
			var new_host_id = game_manager.game_state_data.connected_players.keys()[0]
			game_manager.game_state_data.host_player_id = new_host_id
		else:
			game_manager.game_state_data.host_player_id = 0
			game_manager.game_state_data.game_state = GameState.State.PreHand
	elif game_manager.game_state_data.connected_players.values().size() == 0:
		game_manager.game_state_data.host_player_id = 0
		game_manager.game_state_data.game_state = GameState.State.PreHand
		
	# Clear the player from the seat
	for seat in game_manager.game_state_data.player_seats.values():
		if seat.player_id == id:
			seat.player_id = 0
			seat.player_node = null
	if game_manager.game_state_data.connected_players.size() == 0:
		game_manager.reset_hand()
	client_manager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())
	print("Number of players connected: %s" % [game_manager.game_state_data.connected_players.size()])

### RPC Functions

@rpc("reliable", "any_peer")
func register_player_auth(jwt_token: String):
	"""
	RPC called by client to register their JWT token with the server.
	Server will extract user_id and fetch balance from chips-api.
	
	Args:
		jwt_token: The JWT access token from the client
	"""
	var client_id = multiplayer.get_remote_sender_id()
	var connected_player = game_manager.game_state_data.connected_players.get(client_id)
	
	if connected_player == null:
		print("ERROR: Could not find connected player with id %s" % client_id)
		return
	
	if jwt_token.is_empty():
		print("ERROR: Empty JWT token received from client %s" % client_id)
		_disconnect_player_with_error(client_id, "Invalid authentication token")
		return
	
	# Extract user_id from JWT
	var user_id = JWTUtils.extract_user_id_from_token(jwt_token)
	if user_id.is_empty():
		print("ERROR: Failed to extract user_id from JWT token for client %s" % client_id)
		_disconnect_player_with_error(client_id, "Failed to extract user_id from token")
		return
	
	# Store JWT and user_id
	connected_player.jwt_token = jwt_token
	connected_player.user_id = user_id
	print("Registered player %s with user_id %s" % [client_id, user_id])
	
	# Fetch balance from chips-api using the stored JWT
	_fetch_player_balance_from_api(client_id)

func _fetch_player_balance_from_api(client_id: int):
	"""
	Fetch player balance from chips-api using stored JWT token.
	Called after player registers their JWT via register_player_auth RPC.
	
	Args:
		client_id: The multiplayer peer ID of the connected player
	"""
	var connected_player = game_manager.game_state_data.connected_players.get(client_id)
	if connected_player == null:
		print("ERROR: Could not find connected player with id %s" % client_id)
		return
	
	if connected_player.jwt_token.is_empty() or connected_player.user_id.is_empty():
		print("ERROR: Missing JWT token or user_id for client %s" % client_id)
		_disconnect_player_with_error(client_id, "Authentication data missing")
		return
	
	var chips_api_service = get_parent().get_node("ChipsApiService")
	print("Fetching balance from chips-api for player %s (user_id: %s)" % [client_id, connected_player.user_id])
	
	chips_api_service.get_chips(connected_player.user_id, connected_player.jwt_token, func(result: int, response_code: int, chips: int):
		if result == 0 and response_code == 200:
			if chips >= 0:
				# Success - update player balance
				var old_balance = connected_player.account_total_cash
				connected_player.account_total_cash = chips
				print("Fetched balance for player %s: %s (was %s)" % [client_id, chips, old_balance])
				
				# If player is already seated, update their hand_cash too
				for seat in game_manager.game_state_data.player_seats.values():
					if seat.player_id == client_id:
						if old_balance == -1:
							seat.hand_cash = chips
							print("Set seat hand_cash to %s for player %s (initial balance)" % [chips, client_id])
						else:
							var balance_diff = chips - old_balance
							seat.hand_cash += balance_diff
							print("Adjusted seat hand_cash by %s for player %s" % [balance_diff, client_id])
						break
				
				# Update all clients with the new balance
				client_manager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())
			else:
				print("ERROR: Invalid chips balance returned from API: %s" % chips)
				_disconnect_player_with_error(client_id, "Invalid balance from API")
		elif response_code == 404:
			# User doesn't exist yet, create them with 0 balance
			print("User %s not found in API, creating user record with 0 balance" % connected_player.user_id)
			var initial_balance = 0
			chips_api_service.update_chips(connected_player.user_id, initial_balance, connected_player.jwt_token, func(update_result: int, update_code: int):
				if update_result == 0 and update_code == 200:
					print("Created user in API with balance 0")
					var old_balance = connected_player.account_total_cash
					connected_player.account_total_cash = initial_balance
					
					# If player is already seated, update their hand_cash too
					for seat in game_manager.game_state_data.player_seats.values():
						if seat.player_id == client_id:
							if old_balance == -1:
								seat.hand_cash = initial_balance
							else:
								var balance_diff = initial_balance - old_balance
								seat.hand_cash += balance_diff
							break
					
					client_manager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())
				else:
					print("ERROR: Failed to create user in API (HTTP %s)" % update_code)
					_disconnect_player_with_error(client_id, "Failed to create user account")
			)
		else:
			print("ERROR: Failed to fetch balance from API (HTTP %s, result: %s)" % [response_code, result])
			_disconnect_player_with_error(client_id, "Failed to fetch balance from API")
	)

func _disconnect_player_with_error(client_id: int, error_message: String):
	"""
	Disconnect a player due to an error.
	
	Args:
		client_id: The multiplayer peer ID to disconnect
		error_message: Error message to log
	"""
	print("ERROR: Disconnecting player %s - %s" % [client_id, error_message])
	# Remove player from connected players
	game_manager.game_state_data.connected_players.erase(client_id)
	# Clear player from seat
	for seat in game_manager.game_state_data.player_seats.values():
		if seat.player_id == client_id:
			seat.player_id = 0
			seat.player_node = null
	# Close the peer connection
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.disconnect_peer(client_id)

@rpc("reliable", "any_peer")
func request_game_state_publish():
	client_manager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())

@rpc("reliable", "any_peer")
func request_seat(seat_number: int):
	var client_id = multiplayer.get_remote_sender_id()
	game_manager.assign_player_to_seat(client_id, seat_number)
	
@rpc("reliable", "any_peer")
func set_ready_status(is_ready: bool):
	game_manager.server_get_player_seat().is_ready = is_ready
	client_manager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())
		
@rpc("reliable", "any_peer")
func player_action_taken(player_action: int, action_value = null):
	game_manager.player_action_taken(player_action, action_value)
	
@rpc("reliable", "any_peer")
func start_new_hand() -> void:
	game_manager.start_new_hand()
	
@rpc("reliable", "any_peer")
func goto_lobby() -> void:
	game_manager.goto_lobby()

### Helper functions

func set_player_seats():
	for i in range(1, 9):
		var player_seat = PlayerSeat.new()
		player_seat.seat_index = i
		player_seat.player_id = 0
		game_manager.game_state_data.player_seats[i] = player_seat
		

### Debug rpc methods

@rpc("reliable", "any_peer")
func call_debug_start_game() -> void:
	game_manager.debug_goto_start_game()
	
@rpc("reliable", "any_peer")
func call_debug_deal_flop() -> void:
	game_manager.debug_goto_deal_flop()
	
@rpc("reliable", "any_peer")
func call_debug_end_step() -> void:
	game_manager.debug_goto_end_step()

	
