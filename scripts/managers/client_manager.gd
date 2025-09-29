extends Node

var game_manager
var server_manager
var player_ui_instance

func _ready() -> void:
	# Don't call managers that are lower on the stack from _ready(), they won't exist yet
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
	server_manager.request_player_data.rpc_id(1)

func _on_connection_failed():
	print("Connection to server failed.")
	
func _on_disconnected():
	print("Disconnected from server.")
	
### RPC Functions

@rpc("reliable", "authority")
func assign_player_data(player):
	game_manager.player_data = ConnectedPlayer.from_dict(player)
	player_ui_instance.set_player_data(game_manager.player_data)
	server_manager.request_seat.rpc_id(1, 1)
	game_manager.emit_signal("connected_players_updated_signal", game_manager.connected_players)
	
@rpc("reliable", "call_remote")
func update_connected_players_list(new_connected_players_list):
	if (game_manager.player_data != null):
		for connected_player in new_connected_players_list.values():
			if connected_player.id == multiplayer.get_unique_id():
				game_manager.player_data = connected_player
		game_manager.connected_players = game_manager.deserialize_connected_players(new_connected_players_list)
		game_manager.emit_signal("connected_players_updated_signal", game_manager.connected_players)

@rpc("reliable", "call_remote")
func update_player_seats_list(new_player_seats):
	# Player has not finished setup process while another player connected,
	# can't do anything with this data yet in that case
	if (game_manager.player_data != null):
		game_manager.player_seats = game_manager.deserialize_player_seats(new_player_seats)
		game_manager.emit_signal("player_seats_updated_signal", game_manager.player_seats)
		
@rpc("reliable", "call_remote")
func game_started():
	game_manager.emit_signal("game_started_signal")
