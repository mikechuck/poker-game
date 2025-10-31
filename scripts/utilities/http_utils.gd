extends RefCounted

## HTTP utility functions for making requests

## Encode a dictionary as x-www-form-urlencoded data
static func encode_form_data(params: Dictionary) -> String:
	var encoded_parts = []
	for key in params.keys():
		var encoded_key = key.uri_encode()
		var encoded_value = str(params[key]).uri_encode()
		encoded_parts.append(encoded_key + "=" + encoded_value)
	return "&".join(encoded_parts)

## Make a POST request with form data
static func post_form_request(url: String, form_data: Dictionary, callback: Callable) -> HTTPRequest:
	var http_request = HTTPRequest.new()
	var body = encode_form_data(form_data)
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	
	# Connect the callback
	http_request.request_completed.connect(callback)
	
	# Note: request() will be called after the node is added to the tree
	# Store request parameters for deferred execution
	http_request.set_meta("_pending_request", {
		"url": url,
		"headers": headers,
		"method": HTTPClient.METHOD_POST,
		"body": body
	})
	
	return http_request

## Make a GET request with Authorization header
static func get_request_with_auth(url: String, auth_token: String, callback: Callable) -> HTTPRequest:
	var http_request = HTTPRequest.new()
	var headers = ["Authorization: Bearer %s" % auth_token]
	
	# Connect the callback
	http_request.request_completed.connect(callback)
	
	# Note: request() will be called after the node is added to the tree
	# Store request parameters for deferred execution
	http_request.set_meta("_pending_request", {
		"url": url,
		"headers": headers,
		"method": HTTPClient.METHOD_GET,
		"body": ""
	})
	
	return http_request

## Make a PUT request with JSON body and Authorization header
static func put_json_request_with_auth(url: String, auth_token: String, json_body: String, callback: Callable) -> HTTPRequest:
	var http_request = HTTPRequest.new()
	var headers = [
		"Authorization: Bearer %s" % auth_token,
		"Content-Type: application/json"
	]
	
	# Connect the callback
	http_request.request_completed.connect(callback)
	
	# Note: request() will be called after the node is added to the tree
	# Store request parameters for deferred execution
	http_request.set_meta("_pending_request", {
		"url": url,
		"headers": headers,
		"method": HTTPClient.METHOD_PUT,
		"body": json_body
	})
	
	return http_request
