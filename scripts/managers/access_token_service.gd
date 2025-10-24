extends Node

## AccessTokenService - Singleton for managing authentication tokens

var key = "access_token"
var _token: String = ""
var auth_server_url = "http://localhost:8080"
var client_id = "ultralight-default-client"

func _load_token() -> void:
	_token = JavaScriptBridge.eval("sessionStorage.getItem('%s')" % [key])

func _ready() -> void:
	_load_token()

func get_token() -> String:
	if _token.is_empty():
		_load_token()
	return _token

func has_token() -> bool:
	return not _token.is_empty()

func set_token(token: String) -> void:
	_token = token
	JavaScriptBridge.eval("sessionStorage.setItem('%s', '%s')" % [key, _token])

func renew_token() -> void:
	var token_url = auth_server_url + "/api/oauth/token"
	var form_data = {
		"grant_type": "renew",
		"token": _token,
		"client_id": client_id
	}
	var http_request = HTTPUtils.post_form_request(token_url, form_data, func (result: int, response_code: int, response_headers: PackedStringArray, response_body: PackedByteArray): 
		set_token(JSON.new().data["access_token"])
	)
	add_child(http_request)
