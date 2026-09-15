class_name MotionLabClient
extends Node

signal response_received(kind: String, data: Dictionary)
signal request_failed(kind: String, message: String)

const MAX_RESPONSE_BYTES: int = 524288

var _request: HTTPRequest
var _endpoint: String = ""
var _token: String = ""
var _kind: String = ""


func _ready() -> void:
	_request = HTTPRequest.new()
	_request.timeout = 20.0
	_request.body_size_limit = MAX_RESPONSE_BYTES
	_request.max_redirects = 0
	add_child(_request)
	_request.request_completed.connect(_on_completed)


static func endpoint_error(endpoint: String) -> String:
	var pattern: RegEx = RegEx.new()
	pattern.compile("^(http://(127\\.0\\.0\\.1|localhost|\\[::1\\])|https://([A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?|\\[::1\\]))(:[0-9]{1,5})?$")
	if pattern.search(endpoint.trim_suffix("/")) == null:
		return "Use a loopback HTTP origin or an authenticated HTTPS origin, without a path or credentials"
	var port_text: String = endpoint.trim_suffix("/").get_slice("://", 1).get_slice("]", 1)
	if not endpoint.contains("["):
		port_text = endpoint.trim_suffix("/").get_slice("://", 1)
	if port_text.contains(":"):
		var port: int = int(port_text.get_slice(":", 1))
		if port < 1 or port > 65535:
			return "Endpoint port must be between 1 and 65535"
	return ""


func configure(endpoint: String, token: String) -> String:
	if is_busy():
		return "A bridge request is already in progress"
	var issue: String = endpoint_error(endpoint)
	if not issue.is_empty():
		return issue
	var token_pattern: RegEx = RegEx.new()
	token_pattern.compile("^[!-~]{24,256}$")
	if token_pattern.search(token) == null:
		return "Enter the bridge bearer token (24..256 printable ASCII characters), not an OpenAI API key"
	if token.begins_with("sk-"):
		return "OpenAI API keys belong in the bridge environment, never in this field"
	_endpoint = endpoint.trim_suffix("/")
	_token = token
	return ""


func is_busy() -> bool:
	return not _kind.is_empty()


func current_request() -> String:
	return _kind


func abort_request() -> void:
	if _request != null:
		_request.cancel_request()
	_kind = ""
	_endpoint = ""
	_token = ""


func check_status() -> bool:
	return _send("status", HTTPClient.METHOD_GET, "/v1/status")


func start_search(payload: Dictionary) -> bool:
	return _send("start", HTTPClient.METHOD_POST, "/v1/search", payload)


func poll_job(id: String) -> bool:
	return _send_job("poll", HTTPClient.METHOD_GET, id)


func cancel_job(id: String) -> bool:
	if _kind == "poll":
		_request.cancel_request()
		_kind = ""
	return _send_job("cancel", HTTPClient.METHOD_POST, id, "/cancel")


func _send_job(kind: String, method: HTTPClient.Method, id: String, suffix: String = "") -> bool:
	var pattern: RegEx = RegEx.new()
	pattern.compile("^[a-f0-9]{32}$")
	if pattern.search(id) == null:
		request_failed.emit(kind, "Bridge returned an invalid search ID")
		return false
	return _send(kind, method, "/v1/search/" + id + suffix)


func _send(kind: String, method: HTTPClient.Method, path: String, payload: Dictionary = {}) -> bool:
	if is_busy():
		return false
	if _request == null or _endpoint.is_empty() or _token.is_empty():
		request_failed.emit(kind, "Check the bridge connection first")
		return false
	_kind = kind
	var headers: PackedStringArray = ["Authorization: Bearer " + _token, "Content-Type: application/json"]
	# Tiny joint-basis components must round-trip exactly or contact dynamics change.
	var body: String = JSON.stringify(payload, "", true, true) if method == HTTPClient.METHOD_POST else ""
	var error: Error = _request.request(_endpoint + path, headers, method, body)
	if error != OK:
		_kind = ""
		request_failed.emit(kind, "Could not start the bridge request (error %d)" % error)
		return false
	return true


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var kind: String = _kind
	_kind = ""
	if kind.is_empty():
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit(kind, "Bridge connection failed, timed out or exceeded the response limit. Nothing was applied.")
		return
	if code < 200 or code >= 300:
		var detail: String = "Check token, service state and request limits."
		var failure: Variant = JSON.parse_string(body.get_string_from_utf8())
		if failure is Dictionary and failure.get("error") is String:
			detail = String(failure.error).replace(_token, "[redacted]").left(300)
		request_failed.emit(kind, "Bridge HTTP %d: %s No automatic retry." % [code, detail])
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		request_failed.emit(kind, "Bridge returned invalid JSON; nothing was applied")
		return
	response_received.emit(kind, parsed)
