extends Node
class_name ServerManager

var game_manager: GameSceneManager
var GAME_ID: String
var PORT: int = 12000

func _ready() -> void:
	# Don't call managers that are lower on the stack from _ready(), they won't exist yet
	game_manager = get_parent().get_node("GameManager")


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
	
	
func _on_peer_connected(peer_id: int):
	var ws_multiplayer_peer := multiplayer.multiplayer_peer as WebSocketMultiplayerPeer
	var peer: WebSocketPeer = ws_multiplayer_peer.get_peer(peer_id)
	var connected_player: ConnectedPlayer
	
	# TODO This might act funny if peer is null?
	if peer:
		var requested_url: String = peer.get_requested_url()
		var account_id: String = _get_query_param(requested_url, "verified_account_id")
		
		connected_player = game_manager.game_state_data.connected_players.get(account_id)
		if (connected_player == null):
			var account_data: Contracts.AccountRecord = await HttpRequestsManager.server_get_account_data(account_id)
			if (account_data):
				connected_player = ConnectedPlayer.new()
				connected_player.player_name = account_data.playerName
				connected_player.player_color = account_data.playerColor
				connected_player.account_friend_code = account_data.friendCode
				connected_player.account_hands_won = account_data.handsWon
				connected_player.account_hands_played = account_data.handsPlayed
				connected_player.player_total_cash = GameStateData.default_starting_cash
		
		connected_player.peer_id = peer_id
		connected_player.account_id = account_id
		connected_player.player_state = ConnectedPlayer.PlayerState.ACTIVE
		
		print("Peer %d connected with account id %s" % [peer_id, account_id])

		# If this was the first player to connect, set it as host player
		if (game_manager.game_state_data.host_account_id == ""):
			game_manager.game_state_data.host_account_id = connected_player.account_id
			connected_player.is_host = true
			
		# Update the db record with the new player ID
		var update_request: Dictionary = {
			"game_id": GAME_ID,
			"add_players": [connected_player.account_id]
		}
		var response_code: int = await HttpRequestsManager.server_update_game(update_request)
		game_manager.game_state_data.connected_players[account_id] = connected_player
		ClientManager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())
		Log.message("Number of players connected: %s" % [game_manager.game_state_data.connected_players.size()])


func _on_peer_disconnected(id):
	# If the player is still active in the game, set them to IDLE
	var found_account: bool = false
	for connected_player: ConnectedPlayer in game_manager.game_state_data.connected_players.values():
		if connected_player.peer_id == id && connected_player.player_state == ConnectedPlayer.PlayerState.ACTIVE:
			Log.message("Account %s (peer_id: %s) disconnected, setting to IDLE status" % [connected_player.account_id, connected_player.peer_id])
			found_account = true;
			var player_seat: PlayerSeat = game_manager.server_get_player_seat()
			player_seat.is_ready = false
			connected_player.player_state = ConnectedPlayer.PlayerState.IDLE
			connected_player.player_idle_start_timestamp_ms = int(Time.get_unix_time_from_system() * 1000)
	
	if !found_account:
		Log.message("Peer %s left the game and has been disconnected")
	
	# Run a check to see if any players are still active
	# Continue game forward if we need to skip (i.e. no active or idle players left)
	game_manager.check_skip_this_state()
	ClientManager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())


func update_server_startup_info() -> void:
	var update_request: Dictionary = {
		"game_id": GAME_ID,
		"game_status": Contracts.GameStatus.ACTIVE,
		"port": PORT
	}
	HttpRequestsManager.server_update_game(update_request)


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
func leave_game():
	var client_id: int = multiplayer.get_remote_sender_id()
	if game_manager.game_state_data.game_state == GameState.State.PreHand:
		Log.message("Client %s left the game in pre-hand, removing them from the game")
		game_manager.remove_player_from_game(client_id)
		multiplayer.multiplayer_peer.disconnect_peer(client_id)
	else:
		Log.message("Client %s left the game during a hand")
		game_manager.set_player_as_left(client_id)
		multiplayer.multiplayer_peer.disconnect_peer(client_id)


@rpc("reliable", "any_peer")
func request_game_state_publish():
	if not multiplayer.is_server():
		return
	
	ClientManager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())


@rpc("reliable", "any_peer")
func request_seat(seat_number: int):
	if not multiplayer.is_server():
		return
	
	if game_manager.game_state_data.game_state != GameState.State.PreHand:
		return
	
	var client_id: int = multiplayer.get_remote_sender_id()
	game_manager.assign_player_to_seat(client_id, seat_number)
	

@rpc("reliable", "any_peer")
func leave_seat():
	if not multiplayer.is_server():
		return
		
	if game_manager.game_state_data.game_state != GameState.State.PreHand:
		return
	
	var client_id: int = multiplayer.get_remote_sender_id()
	game_manager.remove_player_from_seat(client_id)
	
	
@rpc("reliable", "any_peer")
func set_ready_status(is_ready: bool):
	if not multiplayer.is_server():
		return
		
	if game_manager.game_state_data.game_state != GameState.State.PreHand:
		return
	
	game_manager.server_get_player_seat().is_ready = is_ready
	ClientManager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())
		
		
@rpc("reliable", "any_peer")
func player_action_taken(player_action: int, action_value: int = 0):
	if not multiplayer.is_server():
		return
	
	game_manager.player_action_taken(player_action, action_value)
	
	
@rpc("reliable", "any_peer")
func start_new_hand() -> void:
	if not multiplayer.is_server():
		return
	
	if game_manager.game_state_data.game_state != GameState.State.HandOver:
		return
	
	game_manager.start_new_hand()
	
	
@rpc("reliable", "any_peer")
func goto_lobby() -> void:
	if not multiplayer.is_server():
		return
		
	if game_manager.game_state_data.game_state != GameState.State.HandOver:
		return
	
	game_manager.goto_lobby()


@rpc("reliable", "any_peer")
func heartbeat_server(account_id: String) -> void:
	if not multiplayer.is_server():
		return
	
	Log.message("Received heartbeat from client | AcountId: %s" % account_id)


### Helper functions

func set_player_seats():
	for i in range(1, 9):
		var player_seat: PlayerSeat = PlayerSeat.new()
		player_seat.seat_index = i
		player_seat.account_id = ""
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
