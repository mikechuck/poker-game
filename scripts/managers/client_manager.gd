extends Node2D

var game_manager
var server_manager
var has_registered_auth = false

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
		# Already connected, register auth now
		call_deferred("_register_player_auth")

func _on_connected_to_server():
	"""Called when client successfully connects to server"""
	print("Client connected to server, sending JWT token...")
	_register_player_auth()

func _register_player_auth():
	"""Send JWT token to server for authentication and balance fetching"""
	if server_manager == null:
		print("ERROR: Server manager not available")
		return
	
	var jwt_token = AccessTokenService.get_token()
	if jwt_token.is_empty():
		print("ERROR: No JWT token available - cannot proceed without authentication")
		_handle_auth_error("User not authenticated - no token available")
		return
	
	# Send JWT token to server (server will extract user_id and fetch balance)
	if not has_registered_auth:
		has_registered_auth = true
		print("Sending JWT token to server for authentication...")
		server_manager.register_player_auth.rpc_id(1, jwt_token)
	else:
		print("DEBUG: Already registered auth, skipping")

func _handle_auth_error(error_message: String):
	"""Handle authentication errors - show error and disconnect"""
	print("ERROR: %s" % error_message)
	# TODO: Show error to user in UI
	# For now, just disconnect from server
	if multiplayer.multiplayer_peer != null:
		print("Disconnecting from server due to auth error")
		disconnect_from_sever()

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
