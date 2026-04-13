extends Node

@onready var get_account_http_request = $GetAccount
@onready var auth_manager = $"../AuthManager"

func get_headers():
	var id_token = auth_manager.get_id_token()
	print("id token:", id_token)
	return [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
func get_account_data(callback: Callable):
	var url = auth_manager.API_URL + "/account"
	print("getting account data")
	get_account_http_request.request_completed.connect(
		func(result, response_code, headers, body):
			print("got back account data")
			if (result == 401):
				auth_manager.refresh_tokens(func(refresh_response_code):
					if refresh_response_code == 200:
						get_account_data(callback)
					)
			else:
				callback.call(JSON.parse_string(body.get_string_from_utf8()))
	)
	get_account_http_request.request(url, get_headers(), HTTPClient.METHOD_GET)
