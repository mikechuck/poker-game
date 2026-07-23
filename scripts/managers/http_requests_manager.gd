extends Node
class_name HttpRequestsManager

@onready var auth_manager: AuthManager =  get_tree().current_scene.get_node("AuthManager")

func get_headers():
	var id_token: String = auth_manager.get_id_token()
	return [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
func get_account_data(callback: Callable):
	var path: String = "/account"
	auth_manager.api_request(
		path,
		HTTPClient.METHOD_GET,
		callback
	)

func create_game(callback: Callable):
	var path: String = "/game"
	var reqeustBody = {
		blind = 10
	}
	
	auth_manager.api_request(
		path,
		HTTPClient.METHOD_PUT,
		callback,
		JSON.stringify(reqeustBody)
	)
	
func get_game(game_id: String, callback: Callable):
	var path: String = "/game?gameId=%s" % game_id.uri_encode()
	auth_manager.api_request(
		path,
		HTTPClient.METHOD_GET,
		callback
	)

func get_games(callback: Callable):
	var path: String = "/games"
	auth_manager.api_request(
		path,
		HTTPClient.METHOD_GET,
		callback
	)
	
func update_game(game_id: String, game_status, callback: Callable):
	var path: String = "/game?gameId=%s" % game_id.uri_encode()
	var reqeustBody = {
		gameStatus = game_status
	}
	
	auth_manager.api_request(
		path,
		HTTPClient.METHOD_POST,
		callback,
		JSON.stringify(reqeustBody)
	)
	
# Server methods
# game_id, game_status = null, port = null, add_players: Array[int] = [], remove_players: Array[int] = []
func server_update_game(params: Dictionary, callback: Callable = func(): pass):
	var game_id: String = params["game_id"]
	var path: String = "/game?gameId=%s" % game_id.uri_encode()
	var requestBody = {
		gameStatus = params["game_status"],
		port = params["port"],
		addPlayers = params["add_players"],
		removePlayers = params["remove_players"]
	}
	
	auth_manager.server_api_request(
		path,
		HTTPClient.METHOD_POST,
		callback,
		JSON.stringify(requestBody)
	)
	
