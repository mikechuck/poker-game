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
		print("DEBUG: JWT token is empty, cannot extract user_id")
		return ""
	
	var payload = decode_jwt_payload(jwt_token)
	if payload.is_empty():
		return ""
	
	if payload.has("sub"):
		var user_id = str(payload["sub"])
		print("DEBUG: Extracted user_id from JWT: %s" % user_id)
		return user_id
	else:
		print("DEBUG: JWT payload does not contain 'sub' field")
		print("DEBUG: Available keys: %s" % payload.keys())
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
		print("DEBUG: JWT token is empty")
		return {}
	
	var parts = jwt_token.split(".")
	if parts.size() != 3:
		print("DEBUG: Invalid JWT token format (expected 3 parts, got %s)" % parts.size())
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
		print("DEBUG: Failed to decode base64 payload")
		return {}
	
	var payload_str = payload_bytes.get_string_from_utf8()
	if payload_str.is_empty():
		print("DEBUG: Failed to convert payload bytes to string")
		return {}
	
	var json = JSON.new()
	var parse_result = json.parse(payload_str)
	if parse_result != OK:
		print("DEBUG: Failed to parse JWT payload JSON: %s" % parse_result)
		print("DEBUG: Payload string (first 100 chars): %s" % payload_str.substr(0, min(100, payload_str.length())))
		return {}
	
	var payload = json.data
	if payload == null or not payload is Dictionary:
		print("DEBUG: JWT payload is not a Dictionary")
		return {}
	
	return payload

