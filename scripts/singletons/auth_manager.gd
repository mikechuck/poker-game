extends Node

@onready var get_tokens_http_request = $GetTokens
@onready var refresh_tokens_http_request = $RefreshToken

const CLIENT_ID = "2m5tvbn5p6po69bi8blouda9sc"
const REDIRECT_URI_HOSTED = "https://poker.mikechucktingle.net/"
const REDIRECT_URI_LOCAL = "http://localhost:5173/"
const LOGIN_URL = "https://login.mikechucktingle.net"
const TOKEN_URL = "https://login.mikechucktingle.net/oauth2/token"
var REDIRECT_URI = ""
@export var API_URL = "https://api.mikechucktingle.net"

func _ready() -> void:
	if (OS.has_feature("local")):
		REDIRECT_URI = REDIRECT_URI_LOCAL
		API_URL += "/dev"
	if OS.has_feature("dev"):
		REDIRECT_URI = REDIRECT_URI_HOSTED
		API_URL += "/dev"
	else:
		REDIRECT_URI = REDIRECT_URI_HOSTED
		API_URL += "/prod"
	
	print("Dev mode enabled!")
	print("API url: ", API_URL)
	print("Redirect url: ", REDIRECT_URI)
	
	# Check tokens and code on ready
	print(get_tree().current_scene.name)
	if (get_tree().current_scene.name == "Landing"):
		var auth_code = get_url_parameter("code")
		if auth_code != "":
			exchange_code_for_tokens(auth_code)
		elif has_auth_tokens():
			navigate_to_main()
		else:
			clean_url()
			clear_local_storage()
	else:
		if !has_auth_tokens():
			navigate_to_landing()
			
#### Http request template to manage auth system
#### This should be used for all HTTP requests to our api
func api_request(path: String, method: int, callback: Callable, body: String = "", retry_count: int = 0):
	print("calling api reqeust")
	var url = API_URL + path
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + get_id_token()
	]
	
	http.request_completed.connect(func(result, response_code, response_headers, response_body):
		if (response_code == 401 and retry_count < 1):
			if await refresh_tokens():
				api_request(path, method, callback, body, retry_count + 1)
			else:
				# Something is wrong with our auth, boot user
				navigate_to_landing()
			
			http.queue_free()
			return
		
		var json_data = JSON.parse_string(response_body.get_string_from_utf8())
		callback.call(json_data)
		http.queue_free()
	)
	
	http.request(url, headers, method, body)

#### Navigation methods

func navigate_to_main():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")
	
func navigate_to_landing():
	clear_local_storage()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/landing.tscn")
	
func navigate_to_login():
	print("navigating to login")
	var login_url = "%s/login?client_id=%s&response_type=code&scope=email+openid&redirect_uri=%s" % [LOGIN_URL, CLIENT_ID, REDIRECT_URI]
	JavaScriptBridge.eval("window.location.href = '" + login_url + "';")

#### Cognito methods

func exchange_code_for_tokens(code: String):
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	var body = HTTPClient.new().query_string_from_dict({
		"grant_type": "authorization_code",
		"client_id": CLIENT_ID,
		"code": code,
		"redirect_uri": REDIRECT_URI
	})
	get_tokens_http_request.request(TOKEN_URL, headers, HTTPClient.METHOD_POST, body)
		
func refresh_tokens() -> bool:
	var current_refresh_token = get_refresh_token()
	if (current_refresh_token == ""): return false
	
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	var body = HTTPClient.new().query_string_from_dict({
		"grant_type": "refresh_token",
		"client_id": CLIENT_ID,
		"refresh_token": get_refresh_token(),
	})
	
	var err = refresh_tokens_http_request.request(TOKEN_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("Error sending request, returning to landing page")
		navigate_to_landing()
		return false
	
	var response = await refresh_tokens_http_request.request_completed
	var result = response[0]
	var response_code = response[1]
	var response_body = response[3]
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Network error code, returning to landing page")
		navigate_to_landing()
		return false
		
	if response_code < 200 or response_code > 300:
		print("Error refreshing tokens, returning to landing page")
		navigate_to_landing()
		return false
		
	var json = JSON.parse_string(response_body.get_string_from_utf8())
	var access_token = json["access_token"]
	var id_token = json["id_token"]
	var refresh_token = json["refresh_token"]
	JavaScriptBridge.eval("localStorage.setItem('access_token', '%s')" % access_token)
	JavaScriptBridge.eval("localStorage.setItem('id_token', '%s')" % id_token)
	JavaScriptBridge.eval("localStorage.setItem('refresh_token', '%s')" % refresh_token)
	return true
	
#### Helper methods

func get_url_parameter(param_name: String) -> String:
	if OS.has_feature("web"):
		var js_code = "new URLSearchParams(window.location.search).get('%s')" % param_name
		var result = JavaScriptBridge.eval(js_code)
		if result != null:
			return str(result)
	return ""
	
func clean_url():
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.history.replaceState({}, document.title, '/');")
	
func get_id_token():
	return JavaScriptBridge.eval("localStorage.getItem('id_token')")
	
func get_access_token():
	return JavaScriptBridge.eval("localStorage.getItem('access_token')")
	
func get_refresh_token():
	return JavaScriptBridge.eval("localStorage.getItem('refresh_token')")

func has_auth_tokens():
	var id_token = JavaScriptBridge.eval("localStorage.getItem('id_token')")
	var access_token = JavaScriptBridge.eval("localStorage.getItem('access_token')")
	var refresh_token = JavaScriptBridge.eval("localStorage.getItem('refresh_token')")
	print("has tokens? %s" % (id_token != null && access_token != null && refresh_token != null))
	return id_token != null && access_token != null && refresh_token != null
	
func clear_local_storage():
	JavaScriptBridge.eval("localStorage.removeItem('access_token')")
	JavaScriptBridge.eval("localStorage.removeItem('id_token')")
	JavaScriptBridge.eval("localStorage.removeItem('refresh_token')")

#### Http request callbacks

func _on_get_tokens_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("done getting tokens!")
	clean_url() # Remove anything from the url so we don't re-trigger the token exchange
	
	if result != HTTPRequest.RESULT_SUCCESS || response_code != 200:
		print("Error signing into account. Result: %s | ResponseCode: %s" % [result, response_code])
		clear_local_storage()
		return
		
	# Handle success
	var json = JSON.parse_string(body.get_string_from_utf8())
	var access_token = json["access_token"]
	var id_token = json["id_token"]
	var refresh_token = json["refresh_token"]
	JavaScriptBridge.eval("localStorage.setItem('access_token', '%s')" % access_token)
	JavaScriptBridge.eval("localStorage.setItem('id_token', '%s')" % id_token)
	JavaScriptBridge.eval("localStorage.setItem('refresh_token', '%s')" % refresh_token)
	navigate_to_main()
