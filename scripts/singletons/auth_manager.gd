extends Node

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
	# Setup HTTP client before anything else
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	
	if (OS.has_feature("local")):
		REDIRECT_URI = REDIRECT_URI_LOCAL
		API_URL += "/dev"
	if OS.has_feature("dev"):
		REDIRECT_URI = REDIRECT_URI_HOSTED
		API_URL += "/dev"
	else:
		REDIRECT_URI = REDIRECT_URI_HOSTED
		API_URL += "/prod"
		
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
#### This should be used for all client HTTP requests to our api
func api_request(path: String, method: int, request_body: String = "", retry_count: int = 0) -> Contracts.HttpResponseWrapper:
	var url: String = API_URL + path
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer " + get_id_token()
	]
	
	# Call api
	var err = http.request(url, headers, method, request_body)
	if err != OK:
		http.queue_free()
		Log.error("HTTP Request failed to initiate: %d" % err)
		return null

	# Await the signal asynchronously (returns an Array of signal arguments)
	var args: Array = await http.request_completed
	var result: int = args[0]
	var response_code: int = args[1]
	var response_headers: PackedStringArray = args[2]
	var response_body: PackedByteArray = args[3]
	http.queue_free()
	
	if (response_code == 401 and retry_count < 1):
		if await refresh_tokens():
			return await api_request(path, method, request_body, retry_count + 1)
		else:
			# Something is wrong with our auth, boot user
			clear_local_storage()
			NavigationManager.navigate_to_landing()
			# Return empty response so we don't need to do null checks everywhere
			return Contracts.HttpResponseWrapper.new()
	else:
		if (response_code >= 300):
			Log.error("HTTP response error code: %s" % response_code)
		var http_response: Contracts.HttpResponseWrapper = Contracts.HttpResponseWrapper.new()
		http_response.result = result
		http_response.response_code = response_code
		http_response.append_response_headers(response_headers)
		http_response.response_body = response_body
		return http_response
	
# For api calls from the server, uses api token instead of JWT
func server_api_request(path: String, method: int, body: String = "") -> Contracts.HttpResponseWrapper:
	var url: String = API_URL + path
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"x-server-token: " + SERVER_API_TOKEN
	]
	
	http.request(url, headers, method, body)
	var args: Array = await http.request_completed
	var result: int = args[0]
	var response_code: int = args[1]
	var response_headers: PackedStringArray = args[2]
	var response_body: PackedByteArray = args[3]
	http.queue_free()
	
	if (response_code != 200):
		Log.error("API request failed | Method: %s | Path: %s | Status code: %s | Response: %s" % [
			method,
			path,
			response_code,
			JSON.parse_string(response_body.get_string_from_utf8())
		])
		return null
	else:
		Log.message("API request succeeded | Method: %s | Path: %s | Status code: %s | Response: %s" % [
			method,
			path,
			response_code,
			JSON.parse_string(response_body.get_string_from_utf8())
		])
		
		var http_response: Contracts.HttpResponseWrapper = Contracts.HttpResponseWrapper.new()
		http_response.result = result
		http_response.response_code = response_code
		http_response.append_response_headers(response_headers)
		http_response.response_body = response_body
		return http_response

#### Cognito methods

func exchange_code_for_tokens(code: String):
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	var headers: PackedStringArray = ["Content-Type: application/x-www-form-urlencoded"]
	var body: String = HTTPClient.new().query_string_from_dict({
		"grant_type": "authorization_code",
		"client_id": CLIENT_ID,
		"code": code,
		"redirect_uri": REDIRECT_URI
	})
	
	var err: Error = http.request(TOKEN_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		Log.message("Error signing into account | Error: %s" % err)
		clean_url() # Remove anything from the url so we don't re-trigger the token exchange
		clear_local_storage()
		return
	
	var response = await http.request_completed
	var result: int = response[0]
	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]
	
	if response_code != 200:
		Log.message("Error signing into account. Result: %s | ResponseCode: %s" % [result, response_code])
		clear_local_storage()
		return
		
	# Handle success
	# Tokens are used for api auth, cookies are used for server auth
	var json: Dictionary = JSON.parse_string(response_body.get_string_from_utf8())
	var access_token: String = json.get("access_token", "")
	var id_token: String = json.get("id_token", "")
	var refresh_token: String = json.get("refresh_token")
	JavaScriptBridge.eval("localStorage.setItem('access_token', '%s')" % access_token)
	JavaScriptBridge.eval("localStorage.setItem('id_token', '%s')" % id_token)
	JavaScriptBridge.eval("localStorage.setItem('refresh_token', '%s')" % refresh_token)
	save_token_to_cookie(access_token)
	clean_url() # Remove anything from the url so we don't re-trigger the token exchange
	NavigationManager.navigate_to_main()
		
func refresh_tokens() -> bool:
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	var current_refresh_token: String = get_refresh_token()
	if (current_refresh_token == ""): return false
	
	var headers: PackedStringArray = ["Content-Type: application/x-www-form-urlencoded"]
	var body: String = HTTPClient.new().query_string_from_dict({
		"grant_type": "refresh_token",
		"client_id": CLIENT_ID,
		"refresh_token": get_refresh_token(),
	})
	
	var err: Error = http.request(TOKEN_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		("Error sending request, returning to landing page")
		NavigationManager.navigate_to_landing()
		return false
	
	var response = await http.request_completed
	var result: int = response[0]
	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]
	
	if result != HTTPRequest.RESULT_SUCCESS:
		Log.message("Network error code, returning to landing page")
		NavigationManager.navigate_to_landing()
		return false
		
	if response_code < 200 or response_code > 300:
		Log.message("Error refreshing tokens, returning to landing page")
		NavigationManager.navigate_to_landing()
		return false
	
	var json: Dictionary = JSON.parse_string(response_body.get_string_from_utf8())
	var access_token: String = json.get("access_token")
	var id_token: String = json.get("id_token")
	JavaScriptBridge.eval("localStorage.setItem('access_token', '%s')" % access_token)
	JavaScriptBridge.eval("localStorage.setItem('id_token', '%s')" % id_token)
	save_token_to_cookie(access_token)
	
	if (json.get("refresh_token", "") != ""):
		var refresh_token: String = json["refresh_token"]
		JavaScriptBridge.eval("localStorage.setItem('refresh_token', '%s')" % refresh_token)
		
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
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("localStorage.getItem('id_token')")
	
func get_access_token():
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("localStorage.getItem('access_token')")
	
func get_refresh_token():
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("localStorage.getItem('refresh_token')")

func has_auth_tokens():
	if OS.has_feature("web"):
		var id_token = JavaScriptBridge.eval("localStorage.getItem('id_token')")
		var access_token = JavaScriptBridge.eval("localStorage.getItem('access_token')")
		var refresh_token = JavaScriptBridge.eval("localStorage.getItem('refresh_token')")
		return id_token != null && access_token != null && refresh_token != null
	
func clear_local_storage():
	DataStore.account_data = null
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.removeItem('access_token')")
		JavaScriptBridge.eval("localStorage.removeItem('id_token')")
		JavaScriptBridge.eval("localStorage.removeItem('refresh_token')")
	
func clear_cookie():
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.cookie = '%s';" % "poker_token=; path=/; max-age=0")
	
func logout():
	DataStore.account_data = null
	clear_local_storage()
	clean_url()
	clear_cookie()
	NavigationManager.navigate_to_landing()
