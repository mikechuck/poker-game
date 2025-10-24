extends Node

var access_token = ""
var http_request: HTTPRequest

# External auth system configuration
var auth_server_url = "http://localhost:8080"
var redirect_uri = "http://localhost:5173/callback"
var client_id = "ultralight-default-client"

# helper functions for oauth pkce
const PKCE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"

func generate_random_string(length: int) -> String:
    var result = ""
    for i in length:
        result += PKCE_CHARS[randi() % PKCE_CHARS.length()]
    return result

func generate_pkce() -> Dictionary:
    # Generate 128-character verifier
    var verifier = generate_random_string(128)
    # Generate SHA-256 hash and convert to base64url
    var hex_string = verifier.sha256_text()
    # convert sha hash to bytes
	var bytes = PackedByteArray()
    for i in range(0, hex_string.length(), 2):
        var hex_byte = hex_string.substr(i, 2)
        var byte_value = hex_byte.hex_to_int()
        bytes.append(byte_value)
	# convert bytes to base64 string
    var hash_base64 = Marshalls.raw_to_base64(bytes)
    # Remove padding and convert to base64url
    var challenge = hash_base64.replace("+", "-").replace("/", "_").replace("=", "")
    return {"verifier": verifier, "challenge": challenge}

# helper functions for cookies
func set_cookie(name: String, value: String, minutes: int = 15):
    var js_code = "document.cookie = '%s=%s; max-age=%d; path=/; SameSite=Lax'"
    JavaScriptBridge.eval(js_code % [name, value, minutes * 60])

func get_cookie(name: String) -> String:
    var js_code = "document.cookie"
    var all_cookies = JavaScriptBridge.eval(js_code)
    # Parse cookies in Godot instead of JavaScript
    var cookies = all_cookies.split(";")
    for cookie in cookies:
        var trimmed = cookie.strip_edges()
        if trimmed.begins_with(name + "="):
            var value = trimmed.substr(name.length() + 1)
            return value
    return ""

# helper functions for urls
func get_url_parameters() -> Dictionary:
	# Get URL search parameters from JavaScript
	var js_code = "window.location.search"
	var search_string = JavaScriptBridge.eval(js_code)
	var params = {}
	if search_string.begins_with("?"):
		# Remove the "?" at the beginning
		var param_string = search_string.substr(1)
		if param_string != "":
			var pairs = param_string.split("&")
			for pair in pairs:
				var key_value = pair.split("=")
				if key_value.size() == 2:
					var key = key_value[0].uri_decode()
					var value = key_value[1].uri_decode()
					params[key] = value
	return params

func get_current_path() -> String:
	var js_code = "window.location.pathname"
	return JavaScriptBridge.eval(js_code)

func get_current_url() -> String:
	var js_code = "window.location.origin + window.location.pathname"
	return JavaScriptBridge.eval(js_code)

# main
func _ready():
	print("WebAuthGuard ready")

func check_auth_status() -> bool:
	var access_token = get_cookie("access_token")
	print("Access token: ", access_token)
	if access_token != "":
		print("User is authenticated")
		return true
	else:
		print("User is NOT authenticated")
		return false

func handle_oauth_callback():
	var url_params = get_url_parameters()
	var code = url_params.get("code", "")
	var state = url_params.get("state", "")
	var stored_state = get_cookie("pkce_state")
	var verifier = get_cookie("pkce_verifier")
	# Validate state parameter
	if state != stored_state:
		print("ERROR: State mismatch - possible CSRF attack")
		return
	var token_url = auth_server_url + "/api/oauth/token"
	var form_data = {
		"grant_type": "authorization_code",
		"code": code,
		"redirect_uri": redirect_uri,
		"client_id": client_id,
		"code_verifier": verifier
	}
	
	# Convert to URL-encoded form data
	var form_parts = []
	for key in form_data.keys():
		var encoded_key = key.uri_encode()
		var encoded_value = str(form_data[key]).uri_encode()
		form_parts.append(encoded_key + "=" + encoded_value)
	var body = "&".join(form_parts)
	
	print("Request body: ", body)
	
	# Set headers
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	
	print("Exchanging code for token...")
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		if result != HTTPRequest.RESULT_SUCCESS:
			print("HTTP request failed: " + str(result))
			return
		if response_code != 200:
			print("HTTP error: " + str(response_code))
			return
		# Parse response body
		var response_text = body.get_string_from_utf8()
		var json = JSON.new()
		var parse_result = json.parse(response_text)
		
		if parse_result != OK:
			print("Failed to parse JSON response")
			return
		
		var response_data = json.data
		if response_data.has("access_token"):
			access_token = response_data["access_token"]
			# Store token in cookie for persistence
			set_cookie("access_token", access_token, 60) # 60 minutes
			print("Successfully obtained access token")
		else:
			var error_msg = response_data.get("error_description", response_data.get("error", "Unknown error"))
			print("Token exchange failed: " + str(error_msg))
	)
	var error = http_request.request(token_url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("Failed to start HTTP request: ", error)
		print("Failed to start HTTP request")

func redirect_to_auth():
	var return_url = get_current_url()
	var pkce = generate_pkce()
	var state = generate_random_string(32)
	set_cookie("pkce_verifier", pkce["verifier"])
	set_cookie("pkce_state", state)	
	var params = {
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "state": state,
        "code_challenge": pkce["challenge"],
        "code_challenge_method": "S256"
    }
    var query_parts = []
    for key in params.keys():
        var encoded_key = key.uri_encode()
        var encoded_value = str(params[key]).uri_encode()
        query_parts.append(encoded_key + "=" + encoded_value)
    
    var query_string = "&".join(query_parts)
    var full_auth_url = auth_server_url + "/api/oauth/authorize?" + query_string
	var js_code = "window.location.href = '%s'" % full_auth_url
	JavaScriptBridge.eval(js_code)
