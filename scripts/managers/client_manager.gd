extends Node

var game_manager
var server_manager
var player_ui_instance

func _ready() -> void:
	# Don't call managers that are lower on the stack from the _ready() method, they won't exist yet
	game_manager = get_parent().get_node("GameManager")
	server_manager = get_parent().get_node("ServerManager")
	player_ui_instance = get_parent().get_node("PlayerUI")

func connect_to_server():
	print("Connecting to server at ws://localhost:%s ..." % [game_manager.server_port])
	var peer = WebSocketMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null
	peer.create_client("ws://localhost:%s" % [game_manager.server_port])
	multiplayer.multiplayer_peer = peer
	
	# Events
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
	
func _on_connected():
	print("Successfully connected to server")

func _on_connection_failed():
	print("Connection to server failed.")
	
func _on_disconnected():
	print("Disconnected from server.")
	
### RPC Functions
	
@rpc("reliable", "call_remote", "authority")
func update_connected_players_list(new_connected_players_list):
	for connected_player in new_connected_players_list.values():
		if connected_player.id == multiplayer.get_unique_id():
			game_manager.player_data = connected_player
	var deserialized_new_list = game_manager.deserialize_connected_players(new_connected_players_list)
	var old_connected_players = game_manager.connected_players.duplicate()
	game_manager.connected_players = deserialized_new_list
	game_manager.emit_signal("connected_players_updated_signal", old_connected_players, deserialized_new_list)

@rpc("reliable", "call_remote", "authority")
func update_player_seats_list(new_player_seats):
	var deserialized_new_list = game_manager.deserialize_player_seats(new_player_seats)
	var old_player_seats_list = game_manager.player_seats.duplicate()
	game_manager.player_seats = deserialized_new_list
	game_manager.emit_signal("player_seats_updated_signal", old_player_seats_list, deserialized_new_list)
		
@rpc("reliable", "call_remote", "authority")
func game_state_change(old_game_state, new_game_state):
	game_manager.current_game_state = new_game_state
	game_manager.emit_signal("game_state_change_signal", old_game_state, new_game_state)
	
@rpc("reliable", "call_remote", "authority")
func update_current_player_turn(player_turn):
	game_manager.current_player_turn = player_turn
	game_manager.emit_signal("current_player_turn_updated_signal", player_turn)
