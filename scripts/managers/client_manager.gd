extends Node

var game_manager

func _ready() -> void:
	# Don't call managers that are lower on the stack from the _ready() method, they won't exist yet
	game_manager = get_parent().get_node("GameManager")
	
func disconnect_from_sever() -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	
### RPC Functions
	
@rpc("reliable", "call_remote", "authority")
func update_game_state_data(game_state_data: Dictionary):
	Logger.log("Game state: %s" % game_state_data.game_state)
	var deserialized_game_state_data = GameStateData.from_dict(game_state_data)
	var old_game_state_data = game_manager.game_state_data.clone()
	game_manager.game_state_data = deserialized_game_state_data
	game_manager.emit_signal("game_state_data_updated_signal", old_game_state_data, deserialized_game_state_data)
