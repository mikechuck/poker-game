extends Node
class_name ClientManager

@onready var game_manager: GameSceneManager = get_parent().get_node("GameManager")
@onready var server_manager: ServerManager = get_parent().get_node("ServerManager")
@onready var heartbeat_timer : Timer = Timer.new()


func _ready() -> void:
	if (!OS.has_feature("server")):
		# Start idle timer for server heartbeats
		heartbeat_timer.wait_time = 10
		heartbeat_timer.timeout.connect(_on_heartbeat_timeout)
		add_child(heartbeat_timer)
		heartbeat_timer.start()
		
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)


func disconnect_from_server() -> void:
	DataStore.game_code = ""
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func _on_heartbeat_timeout() -> void:
	server_manager.heartbeat_server.rpc_id(1, DataStore.account_data.accountId)


func _on_connected():
	Log.message("Connected to game!")
	NavigationManager.navigate_to_game_scene()


func _on_connection_failed():
	Log.message("Connection to server failed.")

	
func _on_disconnected():
	Log.message("Disconnected from server.")
	NavigationManager.navigate_to_main()


func _on_peer_disconnected(id: int):
	Log.message("Peer %s has disconnected from the game" % id)


func _on_peer_connected(id: int): 
	Log.message("Peer %s has connected to the game" % id)

	
### RPC Functions
	
@rpc("reliable", "call_remote", "authority")
func update_game_state_data(game_state_data: Dictionary):
	var deserialized_game_state_data: GameStateData = GameStateData.from_dict(game_state_data)
	var old_game_state_data: GameStateData = game_manager.game_state_data.clone()
	game_manager.game_state_data = deserialized_game_state_data
	game_manager.emit_signal("game_state_data_updated_signal", old_game_state_data, deserialized_game_state_data)
