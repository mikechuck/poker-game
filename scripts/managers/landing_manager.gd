extends Control

@onready var http_request = $LoginButton/HTTPRequest

const CLIENT_ID = "2m5tvbn5p6po69bi8blouda9sc"
const REDIRECT_URI_PROD = "https://poker.mikechucktingle.net"
const REDIRECT_URI_DEV = "http://localhost:5173/"
var REDIRECT_URI = ""
const COGNITO_DOMAIN = "login.mikechucktingle.net"

func _ready() -> void:
	var user_args = OS.get_cmdline_user_args()
	if "--dev" in user_args:
		REDIRECT_URI = REDIRECT_URI_DEV
	else:
		REDIRECT_URI = REDIRECT_URI_PROD
		
	print("using redirect uri %s" % REDIRECT_URI)
		
	# check url for "code" parameter.
	# 	- if present, send POST to cognito's auth endpoint (/oauth2/token)
	# 	- if valid values from response, add to local storage, clear code from url, and navigate to "main" scene
	# 	- if invalid, just remove from url and stay on landing page. Clear any tokens in localstorage
	var auth_code = get_url_parameter("code")
	if auth_code != "":
		print("We have an auth code, attempt to turn it into tokens!")
		#exchange_code_for_tokens(auth_code)
	else:
		print("Waiting for login...")
		
	# if no "code" parameter, check localstorage if there are tokens present
	# 	- if tokens, navigate to "main" scene
	# if no tokens, clear everything from localstorage and stay on landing page

func get_url_parameter(param_name: String) -> String:
	if OS.has_feature("web"):
		var js_code = "new URLSearchParams(window.location.search).get('%s')" % param_name
		var result = JavaScriptBridge.eval(js_code)
		if result != null:
			return str(result)
	return ""
	
func exchange_code_for_tokens(code: String):
	var url = "https://%s/oauth2/token" % COGNITO_DOMAIN
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	
	var body = HTTPClient.new().query_string_from_dict({
		"grant_type": "authorization_code",
		"client_id": CLIENT_ID,
		"code": code,
		"redirect_uri": REDIRECT_URI
	})
	
	var response = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if response != OK:
		print("An error occurred in the HTTP request, check logs for more details")
	
func clean_url():
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.history.replaceState({}, document.title, '/');")
	
func clear_local_storage():
	JavaScriptBridge.eval("localStorage.removeItem('access_token')")
	JavaScriptBridge.eval("localStorage.removeItem('id_token')")
	JavaScriptBridge.eval("localStorage.removeItem('refresh_token')")
		
func navigate_to_main():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")

func _on_login_button_pressed() -> void:
	if OS.has_feature("web"):
		var login_url = "https://%s/login?client_id=%s&response_type=code&scope=email+openid&redirect_uri=%s" % [COGNITO_DOMAIN, CLIENT_ID, REDIRECT_URI]
		JavaScriptBridge.eval("window.location.href = '" + login_url + "';")
	else:
		print("Can't redirect to login url, user is not on web environment")

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("Got network response from Cognito")
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
	print("Login succes! Check local storage for tokens")
	navigate_to_main()
