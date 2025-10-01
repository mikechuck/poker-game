extends Control

### Scenes
@export var card_scene: PackedScene = preload("res://scenes/UI/card.tscn")

var game_manager = null
var server_manager = null

### UI nodes
var player_actions_pre_game_host_node = null
var player_actions_pre_game_guest_node = null
var player_actions_ante_node = null
var player_actions_game_node = null
var ready_toggle = null
var status_message = null
var hole_cards_node = null
var hole_card_instances

func _ready() -> void:
	game_manager = get_parent().get_node("GameManager")
	server_manager = get_parent().get_node("ServerManager")
	game_manager.connected_players_updated_signal.connect(_on_connected_players_updated)
	game_manager.player_seats_updated_signal.connect(_on_player_seats_updated)
	game_manager.current_player_turn_updated_signal.connect(_on_player_turn_updated)
	game_manager.game_state_change_signal.connect(_on_game_state_change_event)
	player_actions_pre_game_host_node = $PlayerActionsPreGameHost
	player_actions_pre_game_guest_node = $PlayerActionsPreGameGuest
	player_actions_ante_node = $PlayerActionsAnte
	player_actions_game_node = $PlayerActionsGame
	status_message = $StatusMessage/Text
	hole_cards_node = $HoleCards

func _on_connected_players_updated(old_connected_players, new_connected_players):
	set_player_buttons()
	set_player_data()

func _on_game_state_change_event(old_game_state, new_game_state) -> void:
	print("Game state has changed from %s to %s" % [old_game_state, new_game_state])
	set_player_buttons()

func _on_player_seats_updated(old_player_seats, new_player_seats) -> void:
	# Hole cards are kept in player_seats data, use this to update the hold cards UI
	update_hole_cards()

func _on_player_turn_updated(player_turn) -> void:
	set_player_buttons()
	
func _on_ready_button_toggled(toggled_on: bool) -> void:
	server_manager.set_ready_status.rpc_id(1, toggled_on)

func _on_start_button__down() -> void:
	server_manager.start_game.rpc_id(1)
	
func set_player_buttons():
	status_message.visible = false
	match game_manager.current_game_state:
		GameState.State.PreGame:
			if (game_manager.player_data.is_spectating):
				player_actions_pre_game_host_node.visible = false
				player_actions_pre_game_guest_node.visible = false
			elif (game_manager.player_data.is_host):
				var start_button = $PlayerActionsPreGameHost/Start/StartButton
				var all_players_ready = true
				player_actions_pre_game_host_node.visible = true
				player_actions_pre_game_guest_node.visible = false
				for player in game_manager.connected_players.values():
					if !player.is_spectating && !player.is_ready:
						all_players_ready = false
				if all_players_ready && game_manager.player_data.is_host:
					start_button.disabled = false
				else:
					start_button.disabled = true
			else:
				player_actions_pre_game_host_node.visible = false
				player_actions_pre_game_guest_node.visible = true
		GameState.State.Shuffle:
			player_actions_pre_game_host_node.visible = false
			player_actions_pre_game_guest_node.visible = false
			status_message.text = "Shuffling deck..."
			status_message.visible = true
		GameState.State.Ante:
			player_actions_pre_game_host_node.visible = false
			player_actions_pre_game_guest_node.visible = false
			status_message.visible = false
			player_actions_ante_node.visible = false
			if game_manager.current_player_turn > 0:
				if game_manager.player_seats[game_manager.current_player_turn].player_id == game_manager.player_data.id:
					print("your turn!")
					status_message.text = "Your turn"
					status_message.visible = true
					player_actions_ante_node.visible = true
				else:
					print("not your turn")
				

func update_hole_cards():
	for player_seat in game_manager.player_seats.values():
		if player_seat.player_id == game_manager.player_data.id && player_seat.hole_cards.size() > 0:
			for i in range(2):
				var card_data = player_seat.hole_cards[i]
				var card_instance = card_scene.instantiate()
				card_instance.number = card_data.number
				card_instance.suit = card_data.suit
				card_instance.position = get_node("HoleCards/HoleCardSpot%s" % [i]).position
				hole_cards_node.add_child(card_instance)
				
	
func set_player_data():
	var player_name_node = $PlayerName/Value
	var player_is_host_node = $IsHost/Value
	player_name_node.clear()
	player_name_node.append_text(str(game_manager.player_data.id))
	player_is_host_node.clear()
	player_is_host_node.append_text(str(game_manager.player_data.is_host))
	
#func spawn_hold_cards
