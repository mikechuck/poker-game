extends Node

## AccessTokenService - Singleton for managing authentication tokens

var key = "access_token"
var _token: String = ""

func _ready() -> void:
	_load_token()

## Get the current access token
func get_token() -> String:
	if _token.is_empty():
		_load_token()
	return _token

## Check if we have a valid access token
func has_token() -> bool:
	return not _token.is_empty()

## Set a new access token
func set_token(token: String) -> void:
	_token = token
	JavaScriptBridge.eval("sessionStorage.setItem('%s', '%s')" % [key, _token])

func _load_token() -> void:
	_token = JavaScriptBridge.eval("sessionStorage.getItem('%s')" % [key])