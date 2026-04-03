extends Node

const CLIENT_ID = "2m5tvbn5p6po69bi8blouda9sc"
const REDIRECT_URI_PROD = "https://poker.mikechucktingle.net"
const REDIRECT_URI_DEV = "http://localhost:5173/"
var REDIRECT_URI = ""
const COGNITO_DOMAIN = "login.mikechucktingle.net"

func ready() -> void:
	if OS.has_feature("dev"):
		REDIRECT_URI = REDIRECT_URI_DEV
	else:
		REDIRECT_URI = REDIRECT_URI_PROD

func get_url_parameter(param_name: String) -> String:
	if OS.has_feature("web"):
		var js_code = "new URLSearchParams(window.location.search).get('%s')" % param_name
		var result = JavaScriptBridge.eval(js_code)
		if result != null:
			return str(result)
	return ""
	
func set_auth_tokens_from_auth_response(body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	var access_token = json["access_token"]
	var id_token = json["id_token"]
	var refresh_token = json["refresh_token"]
	set_auth_tokens(id_token, access_token, refresh_token)
	print("Login succes! Check local storage for tokens")

func set_auth_tokens(id_token: String, access_token: String, refresh_token: String):
	JavaScriptBridge.eval("localStorage.setItem('access_token', '%s')" % access_token)
	JavaScriptBridge.eval("localStorage.setItem('id_token', '%s')" % id_token)
	JavaScriptBridge.eval("localStorage.setItem('refresh_token', '%s')" % refresh_token)
	
func has_auth_tokens():
	var id_token = JavaScriptBridge.eval("localStorage.getItem('id_token')")
	var access_token = JavaScriptBridge.eval("localStorage.getItem('access_token')")
	var refresh_token = JavaScriptBridge.eval("localStorage.getItem('refresh_token')")
	return id_token != null && access_token != null && refresh_token != null
	
func clean_url():
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.history.replaceState({}, document.title, '/');")
	
func clear_local_storage():
	JavaScriptBridge.eval("localStorage.removeItem('access_token')")
	JavaScriptBridge.eval("localStorage.removeItem('id_token')")
	JavaScriptBridge.eval("localStorage.removeItem('refresh_token')")
