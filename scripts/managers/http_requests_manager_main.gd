extends Node

@onready var get_account_http_request = $GetAccount

func get_headers():
	return [
		"Content-Type: application/x-www-form-urlencoded",
		"Authorization: Bearer %s" % AuthManager.get_id_token()
	]
	
func get_account_data():
	print("Getting account data...")
	var response = get_account_http_request.request(AuthManager.API_URL, get_headers(), HTTPClient.METHOD_GET)
	if response != OK:
		print("An error occurred in the HTTP request, check logs for more details")
		

##### HTTP request callbacks

func _on_get_account_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("GetAccount result code: %s" % result)
