extends Node2D

var game_manager
var server_manager
var has_registered_balance = false

func _ready() -> void:
	# Don't call managers that are lower on the stack from the _ready() method, they won't exist yet
	game_manager = get_parent().get_node("GameManager")
	server_manager = get_parent().get_node("ServerManager")
	
	# Connect to multiplayer signals
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	
	# Check if already connected (connection might have happened before scene loaded)
	if multiplayer.is_server():
		# This is server, don't register
		return
	elif multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		# Already connected, register balance now
		call_deferred("_register_player_balance")

func _on_connected_to_server():
	"""Called when client successfully connects to server"""
	print("Client connected to server, fetching balance...")
	_register_player_balance()

func _register_player_balance():
	"""Fetch player balance from API and register with server"""
	var user_id = AccessTokenService.get_user_id()
	if user_id.is_empty():
		print("No user_id available, using default balance")
		# Register with default balance
		var default_balance = GameStateData.default_starting_cash
		server_manager.register_player_with_balance.rpc_id(1, "", default_balance)
		return
	
	# Fetch balance from chips-api
	var chips_api_service = get_parent().get_node("ChipsApiService")
	chips_api_service.get_chips(user_id, _on_balance_fetched.bind(user_id))

func _on_balance_fetched(user_id: String, result: int, response_code: int, chips: int):
	"""Callback when balance is fetched from API"""
	var balance_to_use = GameStateData.default_starting_cash
	
	if result == 0 and response_code == 200:
		balance_to_use = chips
		print("Fetched balance from API: %s" % chips)
	elif response_code == 404:
		# User doesn't exist yet, create them with default balance
		print("User not found in API, creating with default balance")
		var chips_api_service = get_parent().get_node("ChipsApiService")
		chips_api_service.update_chips(user_id, GameStateData.default_starting_cash, func(update_result: int, update_code: int):
			if update_result == 0 and update_code == 200:
				print("Created user in API with default balance")
			balance_to_use = GameStateData.default_starting_cash
			# Register with server
			if not has_registered_balance:
				has_registered_balance = true
				server_manager.register_player_with_balance.rpc_id(1, user_id, balance_to_use)
		)
		return
	else:
		print("Error fetching balance (HTTP %s), using default" % response_code)
	
	# Register with server
	if not has_registered_balance:
		has_registered_balance = true
		server_manager.register_player_with_balance.rpc_id(1, user_id, balance_to_use)

func disconnect_from_sever() -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	
### RPC Functions
	
@rpc("reliable", "call_remote", "authority")
func update_game_state_data(game_state_data: Dictionary):
	print("Game state: %s" % game_state_data.game_state)
	var deserialized_game_state_data = GameStateData.from_dict(game_state_data)
	var old_game_state_data = game_manager.game_state_data.clone()
	game_manager.game_state_data = deserialized_game_state_data
	game_manager.emit_signal("game_state_data_updated_signal", old_game_state_data, deserialized_game_state_data)
