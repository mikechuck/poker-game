extends Node
class_name ClientManager

@onready var game_manager: GameSceneManager = get_parent().get_node("GameManager")
@onready var server_manager: ServerManager = get_parent().get_node("ServerManager")
@onready var heartbeat_timer : Timer = Timer.new()


func _ready() -> void:
	if (!OS.has_feature("server")):
		# Start idle timer for server heartbeats
		heartbeat_timer.wait_time = 10
		heartbeat_timer.one_shot = true
		heartbeat_timer.timeout.connect(_on_heartbeat_timeout)
		add_child(heartbeat_timer)
		heartbeat_timer.start()


func disconnect_from_server() -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func _on_heartbeat_timeout() -> void:
	Log.message("sending heartbeat to server")
	server_manager.heartbeat_server.rpc_id(1, DataStore.account_data.accountId)

	
### RPC Functions
	
@rpc("reliable", "call_remote", "authority")
func update_game_state_data(game_state_data: Dictionary):
	Log.message("Game state updated: %s" % game_state_data.game_state)
	var deserialized_game_state_data: GameStateData = GameStateData.from_dict(game_state_data)
	var old_game_state_data: GameStateData = game_manager.game_state_data.clone()
	game_manager.game_state_data = deserialized_game_state_data
	game_manager.emit_signal("game_state_data_updated_signal", old_game_state_data, deserialized_game_state_data)
