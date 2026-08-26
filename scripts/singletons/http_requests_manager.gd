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
		var dict: Dictionary = JSON.parse_string(http_response.response_body.get_string_from_utf8())
		if dict:
			account_record.ParseFromDictionary(dict)
			return account_record
	return null


func create_game(
	buy_in: int = 0,
	blind: int = 10,
	chip_ratio: int = 1,
	privacy: Contracts.GamePrivacy = Contracts.GamePrivacy.PUBLIC) -> Contracts.GameRecord:
	var path: String = "/game"
	var reqeustBody = {
		blindChips = blind,
		buyInChips = buy_in,
		chipRatio = chip_ratio,
		gamePrivacy = privacy
	}
	
	var http_response: Contracts.HttpResponseWrapper = await AuthManager.api_request(
		path,
		HTTPClient.METHOD_PUT,
		JSON.stringify(reqeustBody)
	)
	
	var game_record: Contracts.GameRecord = Contracts.GameRecord.new()
	if (http_response.response_code == 200 or http_response.response_code == 202):
		var dict: Dictionary = JSON.parse_string(http_response.response_body.get_string_from_utf8())
		if dict:
			game_record.ParseFromDictionary(dict)
			return game_record
	return game_record
	
	
func get_game(game_id: String) -> Contracts.GameRecord:
	var path: String = "/game/%s" % game_id.uri_encode()
	var http_response: Contracts.HttpResponseWrapper = await AuthManager.api_request(
		path,
		HTTPClient.METHOD_GET
	)
	
	var game_record: Contracts.GameRecord = Contracts.GameRecord.new()
	if http_response.response_code == 200:
		var dict: Dictionary = JSON.parse_string(http_response.response_body.get_string_from_utf8())
		if dict:
			game_record.ParseFromDictionary(dict)
	return game_record


func get_games() -> Array[Contracts.GameRecord]:
	var path: String = "/games"
	var http_response: Contracts.HttpResponseWrapper = await AuthManager.api_request(
		path,
		HTTPClient.METHOD_GET
	)
	
	var games_list: Contracts.GameRecordList = Contracts.GameRecordList.new()
	if (http_response.response_code == 200):
		var dict: Dictionary = JSON.parse_string(http_response.response_body.get_string_from_utf8())
		if dict:
			games_list.ParseFromDictionary(dict)
	return games_list.records()
	
	
func update_game(game_id: String, game_status: int) -> int:
	var path: String = "/game/%s" % game_id.uri_encode()
	var reqeustBody = {
		gameStatus = game_status
	}
	
	var http_response: Contracts.HttpResponseWrapper = await AuthManager.api_request(
		path,
		HTTPClient.METHOD_POST,
		JSON.stringify(reqeustBody)
	)
	
	return http_response.response_code
	
func join_game(game_id: String) -> String:
	var path: String = "/game/%s/join" % game_id.uri_encode()
	var http_response: Contracts.HttpResponseWrapper = await AuthManager.api_request(
		path,
		HTTPClient.METHOD_POST
	)
	
	# Return the join game code so the client can send it to the server after connecting
	if (http_response.response_code == 200):
		return http_response.response_body.get_string_from_utf8()
	return ""
	
# Server methods
# game_id, game_status = null, port = null, add_players: Array[int] = [], remove_players: Array[int] = []
func server_update_game(params: Dictionary) -> int:
	var game_id: String = params.get("game_id", "")
	var path: String = "/server/game/%s" % game_id.uri_encode()
	var requestBody = {
		gameStatus = params.get("game_status"),
		port = params.get("port"),
		addPlayers = params.get("add_players"),
		removePlayers = params.get("remove_players")
	}
	
	var http_response: Contracts.HttpResponseWrapper = await AuthManager.server_api_request(
		path,
		HTTPClient.METHOD_POST,
		JSON.stringify(requestBody)
	)
	
	return http_response.response_code
	

func server_get_account_data(account_id: String) -> Contracts.AccountRecord:
	var path: String = "/server/account/%s" % account_id
	var http_response: Contracts.HttpResponseWrapper = await AuthManager.server_api_request(
		path,
		HTTPClient.METHOD_GET
	)
	
	var account_record: Contracts.AccountRecord = Contracts.AccountRecord.new()
	if (http_response.response_code == 200):
		var dict: Dictionary = JSON.parse_string(http_response.response_body.get_string_from_utf8())
		if dict:
			account_record.ParseFromDictionary(dict)
			return account_record
	return null
