extends Node

@onready var get_account_http_request = $GetAccount
@onready var get_presigned_url_http_request = $GetPresignedUrl
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
	print("Calling GET /game for game id %s" % game_id);
	var path = "/game?gameId=%s" % game_id.uri_encode()
	auth_manager.api_request(
		path,
		HTTPClient.METHOD_GET,
		callback
	)

func get_presigned_url():
	var url = "%s/account/picture/url" % auth_manager.API_URL
	var headers = ["Authorization: Bearer " + auth_manager.get_id_token()]
	get_presigned_url_http_request.request(url, headers, HTTPClient.METHOD_GET)
	
	var response = await get_presigned_url_http_request.request_completed
	var json = JSON.parse_string(response[3].get_string_from_utf8())
	print("presigned url json response: %s" % json)
	#upload_to_s3(json.upload_url, my_image_bytes)
	
