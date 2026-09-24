extends Node

@onready var game_manager: GameSceneManager = get_parent().get_node_or_null("GameManager")
@onready var server_manager: ServerManager = get_parent().get_node_or_null("ServerManager")
@onready var heartbeat_timer : Timer = Timer.new()

# Unlike ServerManager, this ClientManager class is a global singleton so we can
# perform connections/disconnections from the main scene if need be. Because of this,
# it's possible that game_manager or server_manager are null, so do null checks

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
	get_tree().node_added.connect(_on_node_added)

# This triggers whenever nodes are added/removed in the scene tree
# Use this to re-initialize manager variables when the scene changes
func _on_node_added(node: Node) -> void:
	if node.name == "Game":
		node.ready.connect(_on_game_scene_ready.bind(node), CONNECT_ONE_SHOT)
		
func _on_game_scene_ready(game_node: Node) -> void:
	# Setup Game scene managers
	game_manager = game_node.get_node("GameManager")
	server_manager = game_node.get_node("ServerManager")
	
	# Setup heartbeat timer to keep tcp connection alive
	if (!OS.has_feature("server")):
		Log.message("Setting up heartbeat timer")
		heartbeat_timer.wait_time = 10
		heartbeat_timer.timeout.connect(_on_heartbeat_timeout)
		add_child(heartbeat_timer)
		heartbeat_timer.start()
	
func connect_to_server(port: int, join_token: String, game_id: String):
	Log.toast("Connecting to game...")
	var connection_url: String = "wss://%s/game/%s?joinToken=%s&gameId=%s" % [AuthManager.BASE_URL, port, join_token, game_id]
	var max_retries: int = 3
	
	for attempt in range(max_retries):
		multiplayer.multiplayer_peer = null
		var peer:= WebSocketMultiplayerPeer.new()
		var err := peer.create_client(connection_url)
		if err == OK:
			multiplayer.multiplayer_peer = peer
			DataStore.game_code = game_id
			break;
		else:
			# Short delay before the next attempt
			if attempt < max_retries - 1:
				await get_tree().create_timer(0.2).timeout


func disconnect_from_server() -> void:
	DataStore.game_code = ""
	if (multiplayer.multiplayer_peer):
		multiplayer.multiplayer_peer.close()


func _on_heartbeat_timeout() -> void:
	Log.message("Sending heartbeat to server...")
	if (server_manager != null):
		server_manager.heartbeat_server.rpc_id(1, DataStore.account_data.accountId)


func _on_connected():
	Log.toast("Connected to game!")
	NavigationManager.navigate_to_game_scene()


func _on_connection_failed():
	Log.toast("Connection to server failed.")

	
func _on_disconnected():
	Log.toast("Disconnected from server.")
	multiplayer.multiplayer_peer = null
	NavigationManager.navigate_to_main()


func _on_peer_disconnected(id: int):
	Log.message("Peer %s has disconnected from the game" % id)


func _on_peer_connected(id: int): 
	Log.message("Peer %s has connected to the game" % id)

	
### RPC Functions
	
@rpc("reliable", "call_remote", "authority")
func update_game_state_data(game_state_data: Dictionary):
	Log.message("got state update")
	if (game_manager == null):
		# Not sure if this is possible, but check anyway
		Log.error("Game manager node doesn't exist, something went wrong")
		return;
	
	var deserialized_game_state_data: GameStateData = GameStateData.from_dict(game_state_data)
	var old_game_state_data: GameStateData = game_manager.game_state_data.clone()
	game_manager.game_state_data = deserialized_game_state_data
	game_manager.emit_signal("game_state_data_updated_signal", old_game_state_data, deserialized_game_state_data)
