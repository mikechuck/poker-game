extends Control

@onready var http_request = $LoginButton/HTTPRequest

func _ready() -> void:
	var auth_code = AuthManager.get_url_parameter("code")
	if (AuthManager.has_auth_tokens()):
		navigate_to_main()
	elif auth_code != "":
		exchange_code_for_tokens(auth_code)
	else:
		AuthManager.clean_url()
		AuthManager.clear_local_storage()
	
func exchange_code_for_tokens(code: String):
	var url = "https://%s/oauth2/token" % AuthManager.COGNITO_DOMAIN
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	
	var body = HTTPClient.new().query_string_from_dict({
		"grant_type": "authorization_code",
		"client_id": AuthManager.CLIENT_ID,
		"code": code,
		"redirect_uri": AuthManager.REDIRECT_URI
	})
	
	var response = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if response != OK:
		print("An error occurred in the HTTP request, check logs for more details")
		
func navigate_to_main():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _on_login_button_pressed() -> void:
	if OS.has_feature("web"):
		var login_url = "https://%s/login?client_id=%s&response_type=code&scope=email+openid&redirect_uri=%s" % [AuthManager.COGNITO_DOMAIN, AuthManager.CLIENT_ID, AuthManager.REDIRECT_URI]
		JavaScriptBridge.eval("window.location.href = '" + login_url + "';")
	else:
		print("Can't redirect to login url, user is not on web environment")

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("Got network response from Cognito")
	AuthManager.clean_url() # Remove anything from the url so we don't re-trigger the token exchange
	
	if result != HTTPRequest.RESULT_SUCCESS || response_code != 200:
		print("Error signing into account. Result: %s | ResponseCode: %s" % [result, response_code])
		AuthManager.clear_local_storage()
		return
		
	# Handle success
	AuthManager.set_auth_tokens_from_auth_response(body)
	print("Login succes! Check local storage for tokens")
	navigate_to_main()
