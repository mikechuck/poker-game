extends VBoxContainer
class_name GameDetailsContainer

const GAME_DETAILS_SCENE = preload("res://scenes/UI/game_details.tscn")

func _ready():
	pass
	
func create_games_list(games_list: Array[Contracts.GameRecord]):
	for game: Contracts.GameRecord in games_list:
		var game_details_instance: GameDetails = GAME_DETAILS_SCENE.instantiate()
		game_details_instance.set_details(game)
		add_child(game_details_instance)
