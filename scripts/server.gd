extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var peer = ENetMultiplayerPeer.new()
	var port = 8081
	var max_players = 10
	peer.create_server(port, max_players)
	multiplayer.multiplayer_peer = peer
	
	# Signals for player connections
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	print("Server started on port ", + port)
	
func _on_player_connected(id):
	print("Player connected: ", id)
	
func _on_player_disconnected(id):
	print("Player disconnected: ", id)
