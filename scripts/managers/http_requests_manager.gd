extends Node

@onready var auth_manager = $"../AuthManager"

func get_headers():
	var id_token = auth_manager.get_id_token()
	print("id token:", id_token)
	return [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
func get_account_data(callback: Callable):
	print("Calling GET /account")
	var path = "/account"
	auth_manager.api_request(
		path,
		HTTPClient.METHOD_GET,
		callback
	)

func create_game(callback: Callable):
	print("Calling PUT /game")
	var path = "/game"
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
	print("Calling GET /game for game id %s" % game_id)
	var path = "/game?gameId=%s" % game_id.uri_encode()
	auth_manager.api_request(
		path,
		HTTPClient.METHOD_GET,
		callback
	)
	
func update_game(game_id: String, game_status: String, callback: Callable):
	print("Calling POST /game for game id %s" % game_id)
	var path = "/game?gameId=%s" % game_id.uri_encode()
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
func server_update_game(game_id: String, game_status: String, callback: Callable):
	print("[Server] Updating game details for game id %s" % game_id)
	var path = "/game?gameId=%s" % game_id.uri_encode()
	
	var reqeustBody = {
		gameStatus = game_status
	}
	
	auth_manager.server_api_request(
		path,
		HTTPClient.METHOD_POST,
		callback,
		JSON.stringify(reqeustBody)
	)
	
