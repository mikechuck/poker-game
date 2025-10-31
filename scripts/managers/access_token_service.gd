extends Node

## AccessTokenService - Singleton for managing authentication tokens

const HTTPUtils = preload("res://scripts/utilities/http_utils.gd")

var key = "access_token"
var _token: String = ""
var _user_id: String = ""
var auth_server_url = "https://ultralight.dev"
var client_id = "ultralight-default-client"

func _load_token() -> void:
	# Only try to load from browser storage if running in web
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("sessionStorage.getItem('%s')" % [key])
		if result != null:
			_token = result
		else:
			_token = ""
	else:
		_token = ""

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
	# Only save to browser storage if running in web
	if OS.has_feature("web"):
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

func get_user_id() -> String:
	"""
	Get the user_id from the JWT token's 'sub' field.
	Extracts user_id on first call and caches it.
	"""
	if _user_id.is_empty():
		_extract_user_id_from_token()
	return _user_id

func _extract_user_id_from_token() -> void:
	"""Extract user_id from the JWT token payload"""
	var token = get_token()
	if token.is_empty():
		return

	var parts = token.split(".")
	if parts.size() != 3:
		return
	
	var payload_b64 = parts[1]
	
	# Convert base64url to base64 (need to handle padding)
	var padding = 4 - (payload_b64.length() % 4)
	if padding != 4:
		payload_b64 += "=".repeat(padding)
	
	# Replace base64url characters with base64
	payload_b64 = payload_b64.replace("-", "+").replace("_", "/")
	var payload_bytes = Marshalls.base64_to_raw(payload_b64)
	var payload_str = payload_bytes.get_string_from_utf8()
	
	var json = JSON.new()
	var parse_result = json.parse(payload_str)
	if parse_result != OK:
		return
	
	var payload = json.data

	if payload.has("sub"):
		_user_id = payload["sub"]
		print("Extracted user_id: ", _user_id)
