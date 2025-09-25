extends Control

var player_data = null
var game_manager = null
var player_actions_pre_game = null
var player_actions_game = null
var start_button = null
var ready_toggle = null

func _ready() -> void:
	game_manager = get_parent().get_node("GameManager")
	game_manager.connected_players_updated_signal.connect(_on_connected_players_updated)
	game_manager.game_started_signal.connect(_on_game_start_event)
	start_button = $PlayerActionsPreGame/Start/StartButton
	player_actions_pre_game = $PlayerActionsPreGame
	player_actions_game = $PlayerActionsGame

func _on_connected_players_updated(new_connected_players):
	var all_players_ready = true
	for new_player_data in new_connected_players.values():
		if !new_player_data.is_ready:
			all_players_ready = false
		if player_data.id == new_player_data.id:
			player_data = new_player_data
			
	print("all_players_ready? %s" % [all_players_ready])
	if all_players_ready && player_data.is_host:
		start_button.disabled = false
	else:
		start_button.disabled = true

func _on_game_start_event() -> void:
	player_actions_pre_game.visible = false
	player_actions_game.visible = true
	
func _on_game_over_event() -> void:
	player_actions_pre_game.visible = true
	player_actions_game.visible = false
		
		
func set_player_data(new_player_data):
	player_data = new_player_data
	var player_name_node = $PlayerName/Value
	var player_is_host_node = $IsHost/Value
	player_name_node.clear()
	player_name_node.append_text(str(player_data.id))
	player_is_host_node.clear()
	player_is_host_node.append_text(str(player_data.is_host))


func _on_ready_button_toggled(toggled_on: bool) -> void:
	game_manager.client_set_ready_status.rpc_id(1, toggled_on)


func _on_start_button__down() -> void:
	game_manager.client_start_game.rpc_id(1)
