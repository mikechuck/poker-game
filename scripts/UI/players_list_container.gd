extends Node
class_name PlayersListContainer

@export var game_player_details: PackedScene = preload("res://scenes/UI/game_player_details.tscn")
@onready var player_details_container_node = $MarginContainer/MarginContainer/Table/ScrollContainer/PlayerDetailsContainer
@onready var game_manager: GameSceneManager = get_tree().root.get_node("Game/GameManager")

func _ready():
	game_manager.game_state_data_updated_signal.connect(_on_game_state_data_change)

func set_players_list(connected_players: Dictionary[String, ConnectedPlayer]):
	var player_rows: Array[Node] = player_details_container_node.get_children()
	for player_row: Node in player_rows:
		player_row.queue_free()
	
	for player: ConnectedPlayer in connected_players.values():
		var player_details_instance: GamePlayerDetails = game_player_details.instantiate()
		player_details_container_node.add_child(player_details_instance)
		player_details_instance.set_player_details(player)

func _on_game_state_data_change(old_game_state_data: GameStateData, new_game_state_data: GameStateData):
	set_players_list(new_game_state_data.connected_players)
