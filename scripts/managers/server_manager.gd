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
	
	var user_id = AccessTokenService.get_user_id()
	if user_id != "":
		print("Fetching chips for user_id: ", user_id)
		var chips_api_service = get_node("/root/Game/ChipsApiService")
		chips_api_service.get_chips(user_id, _on_balance_loaded.bind(connected_player, id, user_id))
	else:
		print("No user_id found, using default balance")
		connected_player.account_total_cash = GameStateData.default_starting_cash
		_finalize_player_connection(connected_player, id)
	
func _on_balance_loaded(connected_player: ConnectedPlayer, player_id: int, user_id: String, result: int, response_code: int, chips: int):
	"""
	Callback when chips balance is loaded from API.
	
	Args:
		connected_player: The ConnectedPlayer object
		player_id: The multiplayer ID
		user_id: The user's UUID
		result: HTTPRequest result (0 = success)
		response_code: HTTP status code
		chips: The player's chips balance
	"""
	if result == 0 and response_code == 200:
		connected_player.account_total_cash = chips
		print("Loaded chips for player %s: %s" % [player_id, chips])
		_finalize_player_connection(connected_player, player_id)
	elif response_code == 404:
		# User doesn't exist yet, create them in the API with default balance
		print("User not found in API, creating user: %s" % user_id)
		var chips_api_service = get_node("/root/Game/ChipsApiService")
		chips_api_service.update_chips(user_id, GameStateData.default_starting_cash, _on_user_created.bind(connected_player, player_id))
	else:
		# API error, use default
		connected_player.account_total_cash = GameStateData.default_starting_cash
		print("Error loading chips (HTTP %s), using default balance: %s" % [response_code, GameStateData.default_starting_cash])
		_finalize_player_connection(connected_player, player_id)

func _on_user_created(connected_player: ConnectedPlayer, player_id: int, result: int, response_code: int):
	"""
	Callback when user is created in the API with default balance.
	
	Args:
		connected_player: The ConnectedPlayer object
		player_id: The multiplayer ID
		result: HTTPRequest result (0 = success)
		response_code: HTTP status code
	"""
	if result == 0 and response_code == 200:
		connected_player.account_total_cash = GameStateData.default_starting_cash
		print("Created user in API with default balance: %s" % GameStateData.default_starting_cash)
	else:
		# API error, use default anyway
		connected_player.account_total_cash = GameStateData.default_starting_cash
		print("Error creating user (HTTP %s), using default balance: %s" % [response_code, GameStateData.default_starting_cash])
	
	_finalize_player_connection(connected_player, player_id)

func _finalize_player_connection(connected_player: ConnectedPlayer, player_id: int):
	"""Complete the player connection after balance is loaded"""
	game_manager.game_state_data.connected_players[player_id] = connected_player
	# If this was the first player to connect, set it as host player
	if (game_manager.game_state_data.host_player_id == 0):
		game_manager.game_state_data.host_player_id = connected_player.id
		connected_player.is_host = true
	# Don't send RPC here - the client will request it when ready via request_game_state_publish
	# client_manager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())
	print("Number of players connected: %s" % [game_manager.game_state_data.connected_players.size()])
	
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

	
