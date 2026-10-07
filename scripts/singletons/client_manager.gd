extends Node

@onready var game_manager: GameSceneManager = get_parent().get_node_or_null("GameManager")
@onready var server_manager: ServerManager = get_parent().get_node_or_null("ServerManager")
@onready var heartbeat_timer : Timer = Timer.new()

@onready var _is_main_scene = get_tree().current_scene.name == "Main"
@onready var _is_game_scene = get_tree().current_scene.name == "Game"

const HEARTBEAT_INTERVAL_MS: int = 10000
const MAX_RECONNECT_RETRY_ATTEMPTS: int = 5
const RECONNECT_RETRY_DELAY_SEC: float = 2.0
var last_heartbeat_time: int = 0
var is_manually_disconnecting: bool = false
var is_lost_focus: bool = false # For keeping track if the page is in focus or the user is away

# Class-level variables for tracking reconnection attempts. Need to use
# this because we have to rely on _on_connection_failed to see if our attempt failed
var max_connection_attempts: int = 3
var connection_attempt_count: int = 0

# Unlike ServerManager, this ClientManager class is a global singleton so we can
# perform connections/disconnections from the main scene if need be. Because of this,
# it's possible that game_manager or server_manager are null, so do null checks

func _ready() -> void:
	# Setup heartbeat timer + multiplayer signals for client
	if (!OS.has_feature("server")):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_disconnected)
		get_tree().node_added.connect(_on_node_added)


func _notification(type: int) -> void:
	if type == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_on_focus_lost()
	
	if type == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_on_focus_regained()

func _on_focus_lost() -> void:
	is_lost_focus = true

func _on_focus_regained() -> void:
	is_lost_focus = false
	# When tab comes back to focus, if we lost peer connection, trigger the loop immediately
	var peer = multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		if not is_manually_disconnecting and _is_game_scene:
			connect_to_server()


func _on_heartbeat_timeout() -> void:
	var peer = multiplayer.multiplayer_peer
	# Only send a heartbeat if we're connected
	if (_is_game_scene && server_manager != null && (peer != null && peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED)):
		Log.message("Sending heartbeat to server...")
		server_manager.heartbeat_server.rpc_id(1, DataStore.account_data.accountId)


# This triggers whenever nodes are added/removed in the scene tree
# Use this to re-initialize manager variables when the scene changes
func _on_node_added(node: Node) -> void:
	if node.name == "Game":
		_is_game_scene = true
		_is_main_scene = false
		node.ready.connect(_on_game_scene_ready.bind(node), CONNECT_ONE_SHOT)
	if node.name == "Main":
		_is_game_scene = false
		_is_main_scene = true
		# Reset leave flag once we get back to main scene
		is_manually_disconnecting = false


func _on_game_scene_ready(game_node: Node) -> void:
	# Setup Game scene managers
	game_manager = game_node.get_node("GameManager")
	server_manager = game_node.get_node("ServerManager")
	
	# Check if it is already connected
	if !heartbeat_timer.timeout.is_connected(_on_heartbeat_timeout):
		Log.message("Setting up heartbeat timer")
		heartbeat_timer.wait_time = 10
		heartbeat_timer.timeout.connect(_on_heartbeat_timeout)
		add_child(heartbeat_timer)
		heartbeat_timer.start()


func _on_connected():
	Log.toast("Connected to game!")
	Log.message("Finished connecting to the game. Unique peer id is %s" % multiplayer.get_unique_id())
	connection_attempt_count = 0
	# Do I have to set multiplayer.multiplayer_peer here? Or is it set automatically?
	if (_is_main_scene):
		NavigationManager.navigate_to_game_scene()


func _on_connection_failed():
	Log.toast("Connection to server failed.")
	var retry_interval_seconds: int = 3
	# If we haven't run out of tries, delay and try again
	if (_is_game_scene and connection_attempt_count <= max_connection_attempts):
		await get_tree().create_timer(retry_interval_seconds).timeout
		connect_to_server()
	else:
		Log.toast("Failed to connect to server.")
		DataStore.game_data = null
		multiplayer.multiplayer_peer = null
		connection_attempt_count = 0
		if (_is_game_scene):
			NavigationManager.navigate_to_main()


func _on_disconnected():
	Log.toast("Disconnected from server.")
	multiplayer.multiplayer_peer = null
	if is_manually_disconnecting:
		NavigationManager.navigate_to_main()
	# Only start connection retry if the user is active
	elif (not is_lost_focus):
		connect_to_server()


func _on_peer_disconnected(id: int):
	Log.message("Peer %s has disconnected from the game" % id)


func _on_peer_connected(id: int): 
	Log.message("Peer %s has connected to the game" % id)


func connect_to_server():
	var port = DataStore.game_data.port
	var join_token = DataStore.join_token
	var game_id = DataStore.game_data.gameId
	var connection_url: String = "wss://%s/game/%s?joinToken=%s&gameId=%s" % [AuthManager.BASE_URL, port, join_token, game_id]
	
	Log.message("Connection attempt %d of %d..." % [connection_attempt_count, max_connection_attempts])
	multiplayer.multiplayer_peer = null
	var peer := WebSocketMultiplayerPeer.new()
	var response := peer.create_client(connection_url)
	# OK means that the connection was initiated, not that the connection is successful yet
	if response == OK:
		multiplayer.multiplayer_peer = peer
	# Else, something went wrong so we need to go back to the main scene
	else:
		DataStore.game_data = null
		multiplayer.multiplayer_peer = null
		if (_is_game_scene):
			NavigationManager.navigate_to_main()
			
	connection_attempt_count = connection_attempt_count + 1


func leave_game() -> void:
	var peer = multiplayer.multiplayer_peer
	if peer == null:
		NavigationManager.navigate_to_main()
	else:
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			server_manager.leave_game.rpc_id(1)
			is_manually_disconnecting = true
		else:
			NavigationManager.navigate_to_main()


func send_heartbeat() -> void:
	if (server_manager != null):
		Log.message("Sending heartbeat to server...")
		server_manager.heartbeat_server.rpc_id(1, DataStore.account_data.accountId)

	
### RPC Functions
	
@rpc("reliable", "call_remote", "authority")
func update_game_state_data(game_state_data: Dictionary):
	if (game_manager == null):
		# Not sure if this is possible, but check anyway
		Log.error("Game manager node doesn't exist, something went wrong")
		return;
	
	var deserialized_game_state_data: GameStateData = GameStateData.from_dict(game_state_data)
	var old_game_state_data: GameStateData = game_manager.game_state_data.clone()
	game_manager.game_state_data = deserialized_game_state_data
	game_manager.emit_signal("game_state_data_updated_signal", old_game_state_data, deserialized_game_state_data)
