extends Node

var game_manager
var client_manager
var GAME_ID
var PORT = 12000
const IDLE_TIMEOUT_SECONDS : float = 3000.0 # 5 minute timeout

@onready var idle_timer : Timer = Timer.new()
@onready var http_request_manager =  get_tree().current_scene.get_node("HttpRequests")
@onready var auth_manager =  get_tree().current_scene.get_node("AuthManager")

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
			auth_manager.SERVER_API_TOKEN = arg.split("=")[1]
			
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
	idle_timer.one_shot = true
	idle_timer.timeout.connect(_on_idle_timeout)
	add_child(idle_timer)
	idle_timer.start()
	
func _on_peer_connected(id):
	Log.message("Player %s connected" % id)
	var connected_player = ConnectedPlayer.new()
	connected_player.id = id
	connected_player.account_total_cash = GameStateData.default_starting_cash
	game_manager.game_state_data.connected_players[id] = connected_player
	
	# If this was the first player to connect, set it as host player
	if (game_manager.game_state_data.host_player_id == 0):
		game_manager.game_state_data.host_player_id = connected_player.id
		connected_player.is_host = true
		
	# Update the db record with the new player ID
	var update_request = {
		"game_id": GAME_ID,
		"add_players": [id]
	}
	http_request_manager.server_update_game(update_request, func (response_code, data): pass)
		
	client_manager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())
	Log.message("Number of players connected: %s" % [game_manager.game_state_data.connected_players.size()])
	
func _on_peer_disconnected(id):
	Log.message("Player %s disconnected" % id)
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
		
	var update_request = {
		"game_id": GAME_ID,
		"remove_players": [id]
	}
	http_request_manager.server_update_game(update_request)
	
	client_manager.update_game_state_data.rpc(game_manager.game_state_data.to_dict())
	Log.message("Number of players connected: %s" % [game_manager.game_state_data.connected_players.size()])
	
	# If no players are in the game, start the idle timeout shutdown
	if (game_manager.game_state_data.connected_players.size() == 0):
		Log.message("Room is empty. Starting shutdown timer...")
		idle_timer.start()
		
func update_server_startup_info() -> void:
	var update_request: Dictionary = {
		"game_id": GAME_ID,
		"game_status": Globals.Enums.GameStatus.STARTED,
		"port": PORT
	}
	http_request_manager.server_update_game(update_request)
	
func update_db_player_connected() -> void:
	http_request_manager.server_update_game(GAME_ID, )
		
func _on_idle_timeout() -> void:
	# If no players are in the game after the timeout, end the game
	Log.message("checking if game is empty")
	if (game_manager.game_state_data.connected_players.size() == 0):
		Log.message("game is empty, update db shutting down")
		var update_request: Dictionary = {
			"game_id": GAME_ID,
			"game_status": Globals.Enums.GameStatus.ENDED,
			"port": PORT
		}
		
		http_request_manager.server_update_game(update_request, func(response_code, data):
			Log.message("Game server instance shutting down. Goodbye.")
			get_tree().quit()
		)

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

	
