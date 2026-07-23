extends Node
class_name AuthManager

@onready var get_tokens_http_request: HTTPRequest = $GetTokens
@onready var refresh_tokens_http_request: HTTPRequest = $RefreshToken

const CLIENT_ID: String = "5nke82c4g3l1256jkhve4vivk3"
const BASE_URL: String = "poker.mikechucktingle.net"
const REDIRECT_URI_HOSTED: String = "https://%s/" % BASE_URL
const REDIRECT_URI_LOCAL: String = "http://localhost:5173/"
const LOGIN_URL: String = "https://auth.mikechucktingle.net"
const TOKEN_URL: String = "https://auth.mikechucktingle.net/oauth2/token"
var REDIRECT_URI: String = ""
var SERVER_API_TOKEN: String = ""

@export var API_URL = "https://api.mikechucktingle.net"
@export var PLAYER_DATA = {}

func _ready() -> void:
	if (OS.has_feature("local")):
		REDIRECT_URI = REDIRECT_URI_LOCAL
		API_URL += "/dev"
		Log.message("Dev mode enabled")
	if OS.has_feature("dev"):
		REDIRECT_URI = REDIRECT_URI_HOSTED
		API_URL += "/dev"
		Log.message("Dev mode enabled")
	else:
		REDIRECT_URI = REDIRECT_URI_HOSTED
		API_URL += "/prod"
		Log.message("Prod mode enabled")
		
	# No need for further setup for server
	if (OS.has_feature("server")):
		return
	
	# Check tokens and code on ready
	if (get_tree().current_scene.name == "Landing"):
		var auth_code: String = get_url_parameter("code")
		if auth_code != "":
			exchange_code_for_tokens(auth_code)
		elif has_auth_tokens():
			NavigationManager.navigate_to_main()
		else:
			clean_url()
			clear_local_storage()
	else:
		if !has_auth_tokens():
			NavigationManager.navigate_to_landing()
			
#### Http request template to manage auth system
#### This should be used for all HTTP requests to our api
func api_request(path: String, method: int, callback: Callable, body: String = "", retry_count: int = 0):
	var url: String = API_URL + path
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + get_id_token()
	]
	
	http.request_completed.connect(func(result, response_code, response_headers, response_body: PackedByteArray):
		if (response_code == 401 and retry_count < 1):
			if await refresh_tokens():
				api_request(path, method, callback, body, retry_count + 1)
			else:
				# Something is wrong with our auth, boot user
				clear_local_storage()
				NavigationManager.navigate_to_landing()
			
			http.queue_free()
			return
		
		var json_data = JSON.parse_string(response_body.get_string_from_utf8())
		callback.call(response_code, json_data)
		http.queue_free()
	)
	
	http.request(url, headers, method, body)
	
# For api calls from the server, uses api token instead of JWT
func server_api_request(path: String, method: int, callback: Callable, body: String = ""):
	var url: String = API_URL + path
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"x-server-token: " + SERVER_API_TOKEN
	]
	
	http.request_completed.connect(func(result, response_code, response_headers, response_body: PackedByteArray):
		if (response_code != 200):
			Log.error("API request failed | Method: %s | Path: %s | Status code: %s | Response: %s" % [
				method,
				path,
				response_code,
				JSON.parse_string(response_body.get_string_from_utf8())
			])
		else:
			Log.message("API request succeeded | Method: %s | Path: %s | Status code: %s | Response: %s" % [
				method,
				path,
				response_code,
				JSON.parse_string(response_body.get_string_from_utf8())
			])
			var json_data = JSON.parse_string(response_body.get_string_from_utf8())
			callback.call(response_code, json_data)
			http.queue_free()
	)
	
	http.request(url, headers, method, body)

#### Cognito methods

func exchange_code_for_tokens(code: String):
	var headers: PackedStringArray = ["Content-Type: application/x-www-form-urlencoded"]
	var body: String = HTTPClient.new().query_string_from_dict({
		"grant_type": "authorization_code",
		"client_id": CLIENT_ID,
		"code": code,
		"redirect_uri": REDIRECT_URI
	})
	get_tokens_http_request.request(TOKEN_URL, headers, HTTPClient.METHOD_POST, body)
		
func refresh_tokens() -> bool:
	var current_refresh_token = get_refresh_token()
	if (current_refresh_token == ""): return false
	
	var headers: PackedStringArray = ["Content-Type: application/x-www-form-urlencoded"]
	var body: String = HTTPClient.new().query_string_from_dict({
		"grant_type": "refresh_token",
		"client_id": CLIENT_ID,
		"refresh_token": get_refresh_token(),
	})
	
	var err = refresh_tokens_http_request.request(TOKEN_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		("Error sending request, returning to landing page")
		NavigationManager.navigate_to_landing()
		return false
	
	var response = await refresh_tokens_http_request.request_completed
	var result = response[0]
	var response_code = response[1]
	var response_body: PackedByteArray = response[3]
	
	if result != HTTPRequest.RESULT_SUCCESS:
		Log.message("Network error code, returning to landing page")
		NavigationManager.navigate_to_landing()
		return false
		
	if response_code < 200 or response_code > 300:
		Log.message("Error refreshing tokens, returning to landing page")
		NavigationManager.navigate_to_landing()
		return false
		
	var json = JSON.parse_string(response_body.get_string_from_utf8())
	var access_token: String = json["access_token"]
	var id_token: String = json["id_token"]
	var refresh_token: String = json["refresh_token"]
	JavaScriptBridge.eval("localStorage.setItem('access_token', '%s')" % access_token)
	JavaScriptBridge.eval("localStorage.setItem('id_token', '%s')" % id_token)
	JavaScriptBridge.eval("localStorage.setItem('refresh_token', '%s')" % refresh_token)
	save_token_to_cookie(access_token)
	return true
	
	
#### TCP connections

# Create cookie to be used for TCP authentication
func save_token_to_cookie(token: String) -> void:
	if OS.has_feature("web"):
		var cookie_string = "poker_token=%s; path=/; secure; SameSite=Strict; max-age=3600" % token
		JavaScriptBridge.eval("document.cookie = '%s';" % cookie_string)
	
#### Helper methods

func get_url_parameter(param_name: String) -> String:
	if OS.has_feature("web"):
		var js_code: String = "new URLSearchParams(window.location.search).get('%s')" % param_name
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
	return id_token != null && access_token != null && refresh_token != null
	
func clear_local_storage():
	JavaScriptBridge.eval("localStorage.removeItem('access_token')")
	JavaScriptBridge.eval("localStorage.removeItem('id_token')")
	JavaScriptBridge.eval("localStorage.removeItem('refresh_token')")

#### Http request callbacks

func _on_get_tokens_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	clean_url() # Remove anything from the url so we don't re-trigger the token exchange
	
	if result != HTTPRequest.RESULT_SUCCESS || response_code != 200:
		Log.message("Error signing into account. Result: %s | ResponseCode: %s" % [result, response_code])
		clear_local_storage()
		return
		
	# Handle success
	var json = JSON.parse_string(body.get_string_from_utf8())
	var access_token: String = json["access_token"]
	var id_token: String = json["id_token"]
	var refresh_token: String = json["refresh_token"]
	JavaScriptBridge.eval("localStorage.setItem('access_token', '%s')" % access_token)
	JavaScriptBridge.eval("localStorage.setItem('id_token', '%s')" % id_token)
	JavaScriptBridge.eval("localStorage.setItem('refresh_token', '%s')" % refresh_token)
	save_token_to_cookie(access_token)
	NavigationManager.navigate_to_main()
