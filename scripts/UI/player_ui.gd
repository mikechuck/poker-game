extends Control

var game_manager = null
var server_manager = null
var player_actions_pre_game_host = null
var player_actions_pre_game_guest = null
var player_actions_game = null
var ready_toggle = null

func _ready() -> void:
	game_manager = get_parent().get_node("GameManager")
	server_manager = get_parent().get_node("ServerManager")
	game_manager.connected_players_updated_signal.connect(_on_connected_players_updated)
	game_manager.game_state_change_signal.connect(_on_game_state_change_event)
	player_actions_pre_game_host = $PlayerActionsPreGameHost
	player_actions_pre_game_guest = $PlayerActionsPreGameGuest
	player_actions_game = $PlayerActionsGame

func _on_connected_players_updated(old_connected_players, new_connected_players):
	set_player_buttons() # Player might change host status, etc

func _on_game_state_change_event(old_game_state, new_game_state) -> void:
	print("Game state has changed from %s to %s" % [old_game_state, new_game_state])
	set_player_buttons()
	
func set_player_buttons():
	match game_manager.current_game_state:
		GameState.State.PreGame:
			if (game_manager.player_data.is_spectating):
				player_actions_pre_game_host.visible = false
				player_actions_pre_game_guest.visible = false
			elif (game_manager.player_data.is_host):
				var start_button = $PlayerActionsPreGameHost/Start/StartButton
				var all_players_ready = true
				player_actions_pre_game_host.visible = true
				player_actions_pre_game_guest.visible = false
				for player in game_manager.connected_players.values():
					if !player.is_spectating && !player.is_ready:
						all_players_ready = false
				if all_players_ready && game_manager.player_data.is_host:
					start_button.disabled = false
				else:
					start_button.disabled = true
			else:
				player_actions_pre_game_host = false
				player_actions_pre_game_guest = true
		GameState.State.Shuffle:
			print("Showing shuffle UI text....")
			pass # do nothing?
	
func set_player_data(new_player_data):
	var player_name_node = $PlayerName/Value
	var player_is_host_node = $IsHost/Value
	player_name_node.clear()
	player_name_node.append_text(str(game_manager.player_data.id))
	player_is_host_node.clear()
	player_is_host_node.append_text(str(game_manager.player_data.is_host))

func _on_ready_button_toggled(toggled_on: bool) -> void:
	server_manager.set_ready_status.rpc_id(1, toggled_on)

func _on_start_button__down() -> void:
	server_manager.start_game.rpc_id(1)
