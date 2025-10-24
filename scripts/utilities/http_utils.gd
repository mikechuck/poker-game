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
	
	# Make the request
	http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	return http_request
