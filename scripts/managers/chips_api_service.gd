extends Node

const HTTPUtils = preload("res://scripts/utilities/http_utils.gd")
const JWTUtils = preload("res://scripts/utilities/jwt_utils.gd")

const CHIPS_API_BASE_URL = "https://api.ultralight.dev"
const GET_CHIPS_ENDPOINT = "/chips/"
const PUT_CHIPS_ENDPOINT = "/chips"

const AUTH_SERVER_URL = "https://api.ultralight.dev/auth"
const CLIENT_ID = "ultralight-default-client"

func get_chips_url(user_id: String) -> String:
	return CHIPS_API_BASE_URL + GET_CHIPS_ENDPOINT + user_id

func put_chips_url() -> String:
	return CHIPS_API_BASE_URL + PUT_CHIPS_ENDPOINT

func get_chips(client_id: int, callback: Callable) -> void:
	_get_player_token_and_call(client_id, func(token: String):
		var connected_player = _get_connected_player(client_id)
		var user_id = connected_player.user_id
		var url = get_chips_url(user_id)
		var http_request = HTTPUtils.get_request_with_auth(url, token, func(result: int, response_code: int, response_headers: PackedStringArray, response_body: PackedByteArray):
			if response_code == 200:
				var json = JSON.new()
				json.parse(response_body.get_string_from_utf8())
				var data = json.data
				var chips = data.get("chips_balance", 0)
				callback.call(0, response_code, chips)
			elif response_code == 401:
				_renew_and_retry_get_chips(client_id, callback)
		)
		_add_http_request_to_tree(http_request)
	)

func _renew_and_retry_get_chips(client_id: int, callback: Callable):
	_renew_player_token(client_id, func(renew_success: bool, new_token: String):
		var connected_player = _get_connected_player(client_id)
		var user_id = connected_player.user_id
		var url = get_chips_url(user_id)
		var http_request = HTTPUtils.get_request_with_auth(url, new_token, func(result: int, response_code: int, response_headers: PackedStringArray, response_body: PackedByteArray):
			var json = JSON.new()
			json.parse(response_body.get_string_from_utf8())
			var data = json.data
			var chips = data.get("chips_balance", 0)
			callback.call(0, response_code, chips)
		)
		_add_http_request_to_tree(http_request)
	)

func update_chips(client_id: int, chips_balance: int, callback: Callable) -> void:
	_get_player_token_and_call(client_id, func(token: String):
		var connected_player = _get_connected_player(client_id)
		var user_id = connected_player.user_id
		
		var now = Time.get_datetime_dict_from_system()
		var datetime_str = "%04d-%02d-%02dT%02d:%02d:%02dZ" % [now.year, now.month, now.day, now.hour, now.minute, now.second]
		
		var json_data = {
			"user_id": user_id,
			"chips_balance": chips_balance,
			"created_at": datetime_str,
			"updated_at": datetime_str
		}
		
		var json_string = JSON.stringify(json_data)
		var url = put_chips_url()
		var http_request = HTTPUtils.put_json_request_with_auth(url, token, json_string, func(result: int, response_code: int, response_headers: PackedStringArray, response_body: PackedByteArray):
			if response_code == 200:
				callback.call(0, response_code)
			elif response_code == 401:
				_renew_and_retry_update_chips(client_id, chips_balance, callback)
		)
		_add_http_request_to_tree(http_request)
	)

func _renew_and_retry_update_chips(client_id: int, chips_balance: int, callback: Callable):
	_renew_player_token(client_id, func(renew_success: bool, new_token: String):
		var connected_player = _get_connected_player(client_id)
		var user_id = connected_player.user_id
		
		var now = Time.get_datetime_dict_from_system()
		var datetime_str = "%04d-%02d-%02dT%02d:%02d:%02dZ" % [now.year, now.month, now.day, now.hour, now.minute, now.second]
		
		var json_data = {
			"user_id": user_id,
			"chips_balance": chips_balance,
			"created_at": datetime_str,
			"updated_at": datetime_str
		}
		
		var json_string = JSON.stringify(json_data)
		var url = put_chips_url()
		var http_request = HTTPUtils.put_json_request_with_auth(url, new_token, json_string, func(result: int, response_code: int, response_headers: PackedStringArray, response_body: PackedByteArray):
			callback.call(0, response_code)
		)
		_add_http_request_to_tree(http_request)
	)

func _add_http_request_to_tree(http_request: HTTPRequest):
	add_child(http_request)
	await get_tree().process_frame
	var pending = http_request.get_meta("_pending_request", null)
	if pending != null:
		var method = pending.get("method", HTTPClient.METHOD_GET)
		var body = pending.get("body", "")
		if body != "":
			http_request.request(pending.url, pending.headers, method, body)
		else:
			http_request.request(pending.url, pending.headers, method)
		http_request.remove_meta("_pending_request")

func _get_connected_player(client_id: int):
	var game_manager = get_parent().get_node_or_null("GameManager")
	if game_manager == null:
		return null
	return game_manager.game_state_data.connected_players.get(client_id)

func _get_player_token_and_call(client_id: int, callback: Callable):
	var connected_player = _get_connected_player(client_id)
	if connected_player.jwt_token.is_empty():
		return
	
	if not JWTUtils.is_token_expired(connected_player.jwt_token):
		callback.call(connected_player.jwt_token)
		return
	
	_renew_player_token(client_id, func(success: bool, new_token: String):
		callback.call(new_token)
	)

func _renew_player_token(client_id: int, callback: Callable) -> void:
	var connected_player = _get_connected_player(client_id)
	if connected_player.jwt_token.is_empty():
		return
	
	var token_url = AUTH_SERVER_URL + "/oauth/token"
	var form_data = {
		"grant_type": "renew",
		"token": connected_player.jwt_token,
		"client_id": CLIENT_ID
	}
	
	var http_request = HTTPUtils.post_form_request(token_url, form_data, func(result: int, response_code: int, response_headers: PackedStringArray, response_body: PackedByteArray):
		if response_code == 200:
			var json = JSON.new()
			json.parse(response_body.get_string_from_utf8())
			var data = json.data
			if data.has("access_token"):
				var new_token = str(data["access_token"])
				connected_player.jwt_token = new_token
				callback.call(true, new_token)
	)
	_add_http_request_to_tree(http_request)
