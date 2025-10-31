extends Node

## ChipsApiService - Service for interacting with chips-api backend

const HTTPUtils = preload("res://scripts/utilities/http_utils.gd")

const CHIPS_API_BASE_URL = "https://y27u211sxl.execute-api.us-east-1.amazonaws.com"
const GET_CHIPS_ENDPOINT = "/chips/"
const PUT_CHIPS_ENDPOINT = "/chips"

func get_chips_url(user_id: String) -> String:
	return CHIPS_API_BASE_URL + GET_CHIPS_ENDPOINT + user_id

func put_chips_url() -> String:
	return CHIPS_API_BASE_URL + PUT_CHIPS_ENDPOINT

## Get player chips balance
func get_chips(user_id: String, jwt_token: String, callback: Callable) -> void:
	"""
	Get player's chips balance from the API.
	
	Args:
		user_id: The user's UUID
		jwt_token: The JWT token for authentication
		callback: Callable that receives (result: int, response_code: int, chips: int)
		
	Callback parameters:
		result: HTTPRequest result (0 = success)
		response_code: HTTP status code
		chips: Player's chips balance (-1 on error)
	"""
	if user_id.is_empty():
		callback.call(1, 400, -1)
		return
	
	if jwt_token.is_empty():
		print("Error: No JWT token provided for chips API")
		callback.call(1, 401, -1)
		return
	
	var url = get_chips_url(user_id)
	var http_request = HTTPUtils.get_request_with_auth(url, jwt_token, func(result: int, response_code: int, response_headers: PackedStringArray, response_body: PackedByteArray):
		if result == HTTPRequest.RESULT_SUCCESS:
			if response_code == 200:
				var json = JSON.new()
				var parse_result = json.parse(response_body.get_string_from_utf8())
				if parse_result == OK:
					var data = json.data
					var chips_raw = data.get("chips_balance", -1)
					
					# Convert to int (API may return float)
					var chips = -1
					if chips_raw != -1:
						if chips_raw is float:
							chips = int(chips_raw)
						elif chips_raw is int:
							chips = chips_raw
						else:
							chips = int(chips_raw)
					
					if chips == -1:
						print("ERROR: chips_balance not found in response data! Available keys: %s" % data.keys())
						callback.call(1, response_code, -1)
					else:
						callback.call(0, response_code, chips)
				else:
					print("Error parsing chips response: ", response_body.get_string_from_utf8())
					callback.call(1, response_code, -1)
			else:
				print("Error fetching chips: HTTP %s" % response_code)
				callback.call(1, response_code, -1)
		else:
			print("Network error fetching chips: ", result)
			callback.call(1, 0, -1)
	)
	_add_http_request_to_tree(http_request)

func _add_http_request_to_tree(http_request: HTTPRequest):
	"""Add HTTPRequest to tree and execute pending request"""
	add_child(http_request)
	
	# Wait one frame to ensure node is fully in tree
	await get_tree().process_frame
	
	# Execute pending request if one exists
	var pending = http_request.get_meta("_pending_request", null)
	if pending != null:
		var method = pending.get("method", HTTPClient.METHOD_GET)
		var body = pending.get("body", "")
		if body != "":
			http_request.request(pending.url, pending.headers, method, body)
		else:
			http_request.request(pending.url, pending.headers, method)
		http_request.remove_meta("_pending_request")

## Update player chips balance
func update_chips(user_id: String, chips_balance: int, jwt_token: String, callback: Callable) -> void:
	"""
	Update player's chips balance in the API.
	
	Args:
		user_id: The user's UUID
		chips_balance: The new chips balance
		jwt_token: The JWT token for authentication
		callback: Callable that receives (result: int, response_code: int)
		
	Callback parameters:
		result: HTTPRequest result (0 = success)
		response_code: HTTP status code
	"""
	if user_id.is_empty():
		callback.call(1, 400)
		return
	
	if jwt_token.is_empty():
		print("Error: No JWT token provided for chips API")
		callback.call(1, 401)
		return
	
	if chips_balance < 0:
		print("Error: chips_balance cannot be negative")
		callback.call(1, 400)
		return
	
	# Create JSON body
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
	var http_request = HTTPUtils.put_json_request_with_auth(url, jwt_token, json_string, func(result: int, response_code: int, response_headers: PackedStringArray, response_body: PackedByteArray):
		if result == HTTPRequest.RESULT_SUCCESS:
			if response_code == 200:
				callback.call(0, response_code)
			else:
				print("Error updating chips: HTTP %s - %s" % [response_code, response_body.get_string_from_utf8()])
				callback.call(1, response_code)
		else:
			print("Network error updating chips: ", result)
			callback.call(1, 0)
	)
	_add_http_request_to_tree(http_request)

