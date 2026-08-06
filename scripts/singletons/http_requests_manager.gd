extends Node
#class_name HttpRequestsManager

func get_headers() -> Array[String]:
	var id_token: String = AuthManager.get_id_token()
	return [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	
func get_account_data() -> Contracts.AccountRecord:
	var path: String = "/account"
	var http_response: Contracts.HttpResponseWrapper = await AuthManager.api_request(
		path,
		HTTPClient.METHOD_GET
	)
	
	var account_record: Contracts.AccountRecord = Contracts.AccountRecord.new()
	if (http_response.response_code == 200):
		account_record.ParseFromBytes(http_response.response_body)
		return account_record
	return null


func create_game() -> Contracts.GameRecord:
	var path: String = "/game"
	var reqeustBody = {
		blind = 10
	}
	
	var http_response: Contracts.HttpResponseWrapper = await AuthManager.api_request(
		path,
		HTTPClient.METHOD_PUT,
		JSON.stringify(reqeustBody)
	)
	
	var game_record: Contracts.GameRecord = Contracts.GameRecord.new()
	if (http_response.response_code == 200 or http_response.response_code == 202):
		game_record.ParseFromBytes(http_response.response_body)
	return game_record
	
	
func get_game(game_id: String) -> Contracts.GameRecord:
	var path: String = "/game?gameId=%s" % game_id.uri_encode()
	var http_response: Contracts.HttpResponseWrapper = await AuthManager.api_request(
		path,
		HTTPClient.METHOD_GET
	)
	
	var game_record: Contracts.GameRecord = Contracts.GameRecord.new()
	if http_response.response_code == 200:
		game_record.ParseFromBytes(http_response.response_body)
	return game_record


func get_games() -> Array[Contracts.GameRecord]:
	var path: String = "/games"
	var http_response: Contracts.HttpResponseWrapper = await AuthManager.api_request(
		path,
		HTTPClient.METHOD_GET
	)
	
	var games_list: Contracts.GameRecordList = Contracts.GameRecordList.new()
	if (http_response.response_code == 200):
		games_list.ParseFromBytes(http_response.response_body)
	return games_list.records()
	
	
func update_game(game_id: String, game_status: int) -> int:
	var path: String = "/game?gameId=%s" % game_id.uri_encode()
	var reqeustBody = {
		gameStatus = game_status
	}
	
	var http_response: Contracts.HttpResponseWrapper = await AuthManager.api_request(
		path,
		HTTPClient.METHOD_POST,
		JSON.stringify(reqeustBody)
	)
	
	return http_response.response_code
	
# Server methods
# game_id, game_status = null, port = null, add_players: Array[int] = [], remove_players: Array[int] = []
func server_update_game(params: Dictionary) -> int:
	var game_id: String = params["game_id"]
	var path: String = "/game?gameId=%s" % game_id.uri_encode()
	var requestBody = {
		gameStatus = params["game_status"],
		port = params["port"],
		addPlayers = params["add_players"],
		removePlayers = params["remove_players"]
	}
	
	var http_response: Contracts.HttpResponseWrapper = await AuthManager.server_api_request(
		path,
		HTTPClient.METHOD_POST,
		JSON.stringify(requestBody)
	)
	
	Log.message("Update game response code: %s" % http_response.response_code)
	
	return http_response.response_code
	
