extends Node

const HTTPUtils = preload("res://scripts/utilities/http_utils.gd")

var http_request: HTTPRequest

var auth_server_url = "https://ultralight.dev"
var client_id = "ultralight-default-client"

func get_redirect_uri() -> String:
	"""Get the redirect URI dynamically based on current origin"""
	if OS.has_feature("web"):
		var origin = JavaScriptBridge.eval("window.location.origin")
		return origin + "/callback"
	else:
		# Fallback for non-web builds
		return "http://localhost:5173/callback"

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

func set_cookie(name: String, value: String, minutes: int = 15):
    var js_code = "document.cookie = '%s=%s; max-age=%d; path=/; SameSite=Lax'"
    var result = JavaScriptBridge.eval(js_code % [name, value, minutes * 60])
    print("DEBUG: set_cookie('%s') result: %s" % [name, result])
    
    # Verify cookie was set
    var verify = get_cookie(name)
    if verify.is_empty():
        print("WARNING: Cookie '%s' was not set properly!" % name)
    else:
        print("DEBUG: Cookie '%s' verified, length: %s" % [name, verify.length()])

func get_cookie(name: String) -> String:
    var js_code = "document.cookie"
    var all_cookies = JavaScriptBridge.eval(js_code)
    var cookies = all_cookies.split(";")
    for cookie in cookies:
        var trimmed = cookie.strip_edges()
        if trimmed.begins_with(name + "="):
            var value = trimmed.substr(name.length() + 1)
            return value
    return ""

func encode_url_params(params: Dictionary) -> String:
    var encoded_parts = []
    for key in params.keys():
        var encoded_key = key.uri_encode()
        var encoded_value = str(params[key]).uri_encode()
        encoded_parts.append(encoded_key + "=" + encoded_value)
    return "&".join(encoded_parts)

func get_url_parameters() -> Dictionary:
    var js_code = "window.location.search"
    var search_string = JavaScriptBridge.eval(js_code)
    var params = {}
    var param_string = search_string.substr(1)
    var pairs = param_string.split("&")
    for pair in pairs:
        var key_value = pair.split("=")
        var key = key_value[0].uri_decode()
        var value = key_value[1].uri_decode()
        params[key] = value
    return params

func get_current_path() -> String:
    return JavaScriptBridge.eval("window.location.pathname")

func get_current_url() -> String:
    return JavaScriptBridge.eval("window.location.origin + window.location.pathname")

func redirect(url: String):
    JavaScriptBridge.eval("window.location.href = '%s'" % url)

func _ready():
	pass

func _complete_oauth_callback():
	"""Complete OAuth callback after token is saved"""
	# Small delay to ensure sessionStorage write completes
	await get_tree().create_timer(0.1).timeout
	redirect("/")

func redirect_to_auth():
	var return_url = get_current_url()
	var pkce = generate_pkce()
	var state = generate_random_string(32)
	set_cookie("pkce_verifier", pkce["verifier"])
	set_cookie("pkce_state", state)
	
	var redirect_uri = get_redirect_uri()
	print("DEBUG: Using redirect_uri: ", redirect_uri)
	
	var params = {
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "state": state,
        "code_challenge": pkce["challenge"],
        "code_challenge_method": "S256"
    }
    var query_string = encode_url_params(params)
    var full_auth_url = auth_server_url + "/api/oauth/authorize?" + query_string
	print("DEBUG: Redirecting to auth URL: ", full_auth_url)
	return redirect(full_auth_url)

func handle_oauth_callback():
    print("DEBUG: Handling OAuth callback...")
    var url_params = get_url_parameters()
    print("DEBUG: URL params: ", url_params)
    var code = url_params.get("code", "")
    var state = url_params.get("state", "")
    var stored_state = get_cookie("pkce_state")
    var verifier = get_cookie("pkce_verifier")
    
    if code.is_empty():
        print("ERROR: OAuth callback missing 'code' parameter")
        return
    
    if verifier.is_empty():
        print("ERROR: PKCE verifier cookie not found")
        return
    
    print("DEBUG: OAuth code received (length: %s), verifier found" % code.length())
    var redirect_uri = get_redirect_uri()
    print("DEBUG: Using redirect_uri for token exchange: ", redirect_uri)
    var token_url = auth_server_url + "/api/oauth/token"
    var form_data = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
        "client_id": client_id,
        "code_verifier": verifier
        }
    
    # Ensure we're in the scene tree before creating HTTP request
    if not is_inside_tree():
        print("WARNING: WebAuthGuard not in tree yet, deferring token request")
        call_deferred("_make_token_request", token_url, form_data)
        return
    
    _make_token_request(token_url, form_data)

func _make_token_request(token_url: String, form_data: Dictionary):
    """Make the token request - called after node is in tree"""
    # Double-check we're in the tree
    if not is_inside_tree():
        print("ERROR: _make_token_request called but node not in tree!")
        call_deferred("_make_token_request", token_url, form_data)
        return
    
    print("DEBUG: Creating HTTPRequest for token exchange...")
    http_request = HTTPUtils.post_form_request(token_url, form_data, func(result: int, response_code: int, response_headers: PackedStringArray, response_body: PackedByteArray):
        if result != HTTPRequest.RESULT_SUCCESS:
            print("ERROR: HTTP request failed with result: ", result)
            return
        
        if response_code != 200:
            print("ERROR: Token request failed with HTTP status: ", response_code)
            print("Response body: ", response_body.get_string_from_utf8())
            return
        
        var response_text = response_body.get_string_from_utf8()
        print("DEBUG: Token response received: ", response_text.substr(0, 100))
        
        var json = JSON.new()
        var parse_error = json.parse(response_text)
        if parse_error != OK:
            print("ERROR: Failed to parse token response JSON: ", parse_error)
            print("Response text: ", response_text)
            return
        
        var response_data = json.data
        print("DEBUG: Parsed response data keys: ", response_data.keys())
        
        if response_data.has("access_token"):
            var token = response_data["access_token"]
            print("DEBUG: Setting access token (length: %s)" % token.length())
            AccessTokenService.set_token(token)
            
            # Verify token was set
            var verify_token = AccessTokenService.get_token()
            if verify_token.is_empty():
                print("ERROR: Token was set but get_token() returns empty!")
            else:
                print("DEBUG: Token verified, length: ", verify_token.length())
            
            # Small delay to ensure sessionStorage write completes before redirect
            # Use call_deferred since we're in a callback
            call_deferred("_complete_oauth_callback")
        else:
            print("ERROR: Response does not contain 'access_token'")
            print("Response data: ", response_data)
    )
    
    # Add to scene tree - use call_deferred if not ready
    if not is_inside_tree():
        print("WARNING: HTTPRequest created before node in tree, adding deferred")
        call_deferred("_add_http_request_to_tree", http_request)
    else:
        _add_http_request_to_tree(http_request)

func _add_http_request_to_tree(http_request: HTTPRequest):
	"""Add HTTPRequest to tree and execute pending request"""
	if not is_inside_tree():
		print("ERROR: Cannot add HTTPRequest - WebAuthGuard not in tree!")
		call_deferred("_add_http_request_to_tree", http_request)
		return
	
	print("DEBUG: Adding HTTPRequest to tree...")
	add_child(http_request)
	
	# Use call_deferred to ensure HTTPRequest is fully in tree before calling request
	call_deferred("_execute_pending_request", http_request)

func _execute_pending_request(http_request: HTTPRequest):
	"""Execute the pending HTTP request after node is fully in tree"""
	if not http_request.is_inside_tree():
		print("WARNING: HTTPRequest still not in tree, waiting...")
		call_deferred("_execute_pending_request", http_request)
		return
	
	# Execute pending request if one exists
	var pending = http_request.get_meta("_pending_request", null)
	if pending != null:
		print("DEBUG: Executing pending HTTP request to: ", pending.url)
		var method = pending.get("method", HTTPClient.METHOD_GET)
		var body = pending.get("body", "")
		if body != "":
			var result = http_request.request(pending.url, pending.headers, method, body)
			if result != OK:
				print("ERROR: HTTPRequest.request() failed with code: ", result)
		else:
			var result = http_request.request(pending.url, pending.headers, method)
			if result != OK:
				print("ERROR: HTTPRequest.request() failed with code: ", result)
		http_request.remove_meta("_pending_request")
	else:
		print("WARNING: No pending request found in HTTPRequest metadata")