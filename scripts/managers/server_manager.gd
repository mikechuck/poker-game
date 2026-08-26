extends Node
class_name ServerManager

var game_manager: GameSceneManager
var client_manager: ClientManager
var GAME_ID: String
var PORT: int = 12000
const IDLE_TIMEOUT_SECONDS: float = 300.0

@onready var idle_timer : Timer = Timer.new()


func _ready() -> void:
	# Don't call managers that are lower on the stack from _ready(), they won't exist yet
	game_manager = get_parent().get_node("GameManager")
	client_manager = get_parent().get_node("ClientManager")


func start_server():
	var args = OS.get_cmdline_args()
	
	for arg in args:
		if arg.begins_with("--gameId"):
			GAME_ID = arg.split("=")[1]
		if arg.begins_with("--port="):
			PORT = int(arg.split("=")[1])
		if arg.begins_with("--apiToken="):
			AuthManager.SERVER_API_TOKEN = arg.split("=")[1]
			
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Log.message("Started server at wss://localhost:%s for game id %s..." % [PORT, GAME_ID])
	update_server_startup_info()
	
	# Start idle timer so we can shutdown the server if no one is playing
	idle_timer.wait_time = IDLE_TIMEOUT_SECONDS
	idle_timer.timeout.connect(_on_idle_timeout)
	add_child(idle_timer)
	idle_timer.start()
	
	
func _on_peer_connected(peer_id: int):
	var connected_player = ConnectedPlayer.new()
	connected_player.peer_id = peer_id
	connected_player.player_total_cash = GameStateData.default_starting_cash
	game_manager.game_state_data.connected_players[peer_id] = connected_player
	
	var ws_multiplayer_peer := multiplayer.multiplayer_peer as WebSocketMultiplayerPeer
	var peer: WebSocketPeer = ws_multiplayer_peer.get_peer(peer_id)
	if peer:
		var requested_url: String = peer.get_requested_url()
		var account_id: String = _get_query_param(requested_url, "verified_account_id")
		connected_player.account_id = account_id
		var account_data: Contracts.AccountRecord = await HttpRequestsManager.server_get_account_data(account_id)
		if (account_data):
			connected_player.player_name = account_data.playerName
			connected_player.player_color = account_data.playerColor
			connected_player.friend_code = account_data.friendCode
			connected_player.account_hands_won = account_data.handsWon
			connected_player.account_hands_played = account_data.handsPlayed
			print("Peer %d connected with account id %s" % [peer_id, account_id])
	else:
		Log.message("test?")

	# If this was the first player to connect, set it as host player
	if (game_manager.game_state_data.host_peer_id == 0):
		game_manager.game_state_data.host_peer_id = connected_player.peer_id
		connected_player.is_host = true
		
	# Update the db record with the new player ID
	var update_request: Dictionary = {
		"game_id": GAME_ID,
		"add_players": [connected_player.account_id]
	}
	var response_code: int = await HttpRequestsManager.server_update_game(update_request)
		
	client_manager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())
	Log.message("Number of players connected: %s" % [game_manager.game_state_data.connected_players.size()])
	
	
func _on_peer_disconnected(id):
	var disconnecting_player: ConnectedPlayer = game_manager.game_state_data.connected_players.get(id)
	Log.message("Player %s disconnected" % disconnecting_player.account_id)
	game_manager.game_state_data.connected_players.erase(id)
	
	if disconnecting_player.is_host:
		if (game_manager.game_state_data.connected_players.values().size() > 0):
			var new_host: ConnectedPlayer = game_manager.game_state_data.connected_players.values()[0]
			game_manager.game_state_data.host_peer_id = new_host.peer_id
			Log.message("New host id: %s" % new_host.account_id)
		else:
			Log.message("Host left, no players left in the game")
			game_manager.game_state_data.host_peer_id = 0
			game_manager.game_state_data.game_state = GameState.State.PreHand
	elif game_manager.game_state_data.connected_players.values().size() == 0:
		game_manager.game_state_data.host_peer_id = 0
		game_manager.game_state_data.game_state = GameState.State.PreHand
		
	# Clear the player from the seat
	for seat in game_manager.game_state_data.player_seats.values():
		if seat.peer_id == id:
			seat.peer_id = 0
			seat.player_node = null
		
	# TODO: don't reset hand, have some sort of grace period for reconnections.
	# What do we do about rage quitting? 
	if game_manager.game_state_data.connected_players.size() == 0:
		game_manager.reset_hand()
		
	var update_request: Dictionary = {
		"game_id": GAME_ID,
		"remove_players": [disconnecting_player.account_id]
	}
	var response_code: int = await HttpRequestsManager.server_update_game(update_request)
	
	client_manager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())
	Log.message("Number of players connected: %s" % [game_manager.game_state_data.connected_players.size()])
	
	# If no players are in the game, start the idle timeout shutdown
	if (game_manager.game_state_data.connected_players.size() == 0):
		idle_timer.start()
		
		
func update_server_startup_info() -> void:
	var update_request: Dictionary = {
		"game_id": GAME_ID,
		"game_status": Contracts.GameStatus.ACTIVE,
		"port": PORT
	}
	HttpRequestsManager.server_update_game(update_request)
	
#func update_db_player_connected() -> void:
	#http_request_manager.server_update_game(GAME_ID, )
		
		
func _on_idle_timeout() -> void:
	# If no players are in the game after the timeout, end the game
	if (game_manager.game_state_data.connected_players.size() == 0):
		var update_request: Dictionary = {
			"game_id": GAME_ID,
			"game_status": Contracts.GameStatus.ENDED,
			"port": PORT
		}
		
		var response_code: int = await HttpRequestsManager.server_update_game(update_request)
		if response_code != 200:
			Log.error("Error updating game instance from server.")
		Log.message("Game server instance shutting down. Goodbye.")
		get_tree().quit()
		
func _get_query_param(url: String, param_name: String) -> String:
	var query_start: int = url.find("?")
	if query_start == -1:
		return ""
	var query_string = url.substr(query_start + 1)
	var pairs = query_string.split("&")
	for pair in pairs:
		var key_value = pair.split("=")
		if key_value.size() == 2 and key_value[0] == param_name:
			return key_value[1].uri_decode()
	return ""

### RPC Functions

@rpc("reliable", "any_peer")
func request_game_state_publish():
	client_manager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())


@rpc("reliable", "any_peer")
func request_seat(seat_number: int):
	var client_id: int = multiplayer.get_remote_sender_id()
	game_manager.assign_player_to_seat(client_id, seat_number)
	

@rpc("reliable", "any_peer")
func leave_seat():
	var client_id: int = multiplayer.get_remote_sender_id()
	game_manager.remove_player_from_seat(client_id)
	
	
@rpc("reliable", "any_peer")
func set_ready_status(is_ready: bool):
	game_manager.server_get_player_seat().is_ready = is_ready
	client_manager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())
		
		
@rpc("reliable", "any_peer")
func player_action_taken(player_action: int, action_value: int = 0):
	Log.message("Player action taken | player_action: %s | action_value: %s" % [player_action, action_value])
	game_manager.player_action_taken(player_action, action_value)
	
	
@rpc("reliable", "any_peer")
func start_new_hand() -> void:
	game_manager.start_new_hand()
	
	
@rpc("reliable", "any_peer")
func goto_lobby() -> void:
	game_manager.goto_lobby()


@rpc("reliable", "any_peer")
func heartbeat_server(account_id: String) -> void:
	Log.message("Received heartbeat from client | AcountId: %s" % account_id)


### Helper functions

func set_player_seats():
	for i in range(1, 9):
		var player_seat = PlayerSeat.new()
		player_seat.seat_index = i
		player_seat.peer_id = 0
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

	
