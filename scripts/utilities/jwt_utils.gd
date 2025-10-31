extends Node
class_name JWTUtils

## JWT Utility Functions - Server-side JWT decoding
## These functions work without browser dependencies (unlike AccessTokenService)

static func extract_user_id_from_token(jwt_token: String) -> String:
	"""
	Extract user_id from JWT token's 'sub' field.
	
	Args:
		jwt_token: The JWT token string
		
	Returns:
		user_id string from 'sub' claim, or empty string if extraction fails
	"""
	if jwt_token.is_empty():
		return ""
	
	var payload = decode_jwt_payload(jwt_token)
	if payload.is_empty():
		return ""
	
	if payload.has("sub"):
		return str(payload["sub"])
	
	return ""

static func decode_jwt_payload(jwt_token: String) -> Dictionary:
	"""
	Decode JWT payload from token string.
	
	Args:
		jwt_token: The JWT token string (format: header.payload.signature)
		
	Returns:
		Dictionary containing the decoded payload, or empty Dictionary on error
	"""
	if jwt_token.is_empty():
		return {}
	
	var parts = jwt_token.split(".")
	if parts.size() != 3:
		return {}
	
	var payload_b64 = parts[1]
	
	# Convert base64url to base64 (need to handle padding)
	var padding = 4 - (payload_b64.length() % 4)
	if padding != 4:
		payload_b64 += "=".repeat(padding)
	
	# Replace base64url characters with base64
	payload_b64 = payload_b64.replace("-", "+").replace("_", "/")
	
	var payload_bytes = Marshalls.base64_to_raw(payload_b64)
	if payload_bytes.is_empty():
		return {}
	
	var payload_str = payload_bytes.get_string_from_utf8()
	if payload_str.is_empty():
		return {}
	
	var json = JSON.new()
	var parse_result = json.parse(payload_str)
	if parse_result != OK:
		return {}
	
	var payload = json.data
	if payload == null or not payload is Dictionary:
		return {}
	
	return payload

static func is_token_expired(jwt_token: String) -> bool:
	"""
	Check if JWT token is expired by comparing 'exp' claim to current time.
	
	Args:
		jwt_token: The JWT token string
		
	Returns:
		true if token is expired or invalid, false if still valid
	"""
	if jwt_token.is_empty():
		return true
	
	var payload = decode_jwt_payload(jwt_token)
	if payload.is_empty():
		return true
	
	if not payload.has("exp"):
		return true
	
	var exp_timestamp = payload["exp"]
	if exp_timestamp == null:
		return true
	
	# exp is a Unix timestamp (seconds since epoch)
	var current_time = Time.get_unix_time_from_system()
	var exp_time = int(exp_timestamp)
	
	# Add 30 second buffer to renew before actual expiration
	# This prevents edge cases where token expires during API call
	var buffer_seconds = 30
	return current_time >= (exp_time - buffer_seconds)

static func get_token_expiration_time(jwt_token: String) -> int:
	"""
	Get the expiration timestamp from JWT token's 'exp' claim.
	
	Args:
		jwt_token: The JWT token string
		
	Returns:
		Unix timestamp (seconds) when token expires, or -1 on error
	"""
	if jwt_token.is_empty():
		return -1
	
	var payload = decode_jwt_payload(jwt_token)
	if payload.is_empty():
		return -1
	
	if not payload.has("exp"):
		return -1
	
	var exp_timestamp = payload["exp"]
	if exp_timestamp == null:
		return -1
	
	return int(exp_timestamp)

