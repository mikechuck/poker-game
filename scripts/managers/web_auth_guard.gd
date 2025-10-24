extends Node

var http_request: HTTPRequest

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

func set_cookie(name: String, value: String, minutes: int = 15):
    var js_code = "document.cookie = '%s=%s; max-age=%d; path=/; SameSite=Lax'"
    JavaScriptBridge.eval(js_code % [name, value, minutes * 60])

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
    var query_string = encode_url_params(params)
    var full_auth_url = auth_server_url + "/api/oauth/authorize?" + query_string
	return redirect(full_auth_url)

func handle_oauth_callback():
	var url_params = get_url_parameters()
	var code = url_params.get("code", "")
	var state = url_params.get("state", "")
	var stored_state = get_cookie("pkce_state")
	var verifier = get_cookie("pkce_verifier")
	var token_url = auth_server_url + "/api/oauth/token"
	var form_data = {
		"grant_type": "authorization_code",
		"code": code,
		"redirect_uri": redirect_uri,
		"client_id": client_id,
		"code_verifier": verifier
	}
	var body = encode_url_params(form_data)
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(func(result: int, response_code: int, response_headers: PackedStringArray, response_body: PackedByteArray):
		var response_text = response_body.get_string_from_utf8()
		var json = JSON.new()
		json.parse(response_text)
		var response_data = json.data
		if response_data.has("access_token"):
			AccessTokenService.set_token(response_data["access_token"])
			redirect("/")
	)
	http_request.request(token_url, headers, HTTPClient.METHOD_POST, body)