class_name DeepSeekReview
extends Node
## The client sends numerical facts to the owner's service; credentials stay there.
signal completed(token: int, result: Dictionary)
const ACTIONS := ["fold", "check", "call", "raise", "all_in"]
var service_url := str(ProjectSettings.get_setting("coach/service_url", ""))
var _generation := 0
var _request: HTTPRequest
var _cache: Dictionary = {}

func cancel() -> void:
	_generation += 1
	if is_instance_valid(_request):
		_request.cancel_request()
		_request.queue_free()
	_request = null

func _exit_tree() -> void:
	cancel()

func request_review(results: Array, locale: String) -> int:
	cancel()
	var facts := make_facts(results)
	if service_url.is_empty() or facts.is_empty() or not is_inside_tree(): return -1
	var token := _generation
	var body := JSON.stringify(make_payload(facts, locale))
	var cache_key := (service_url + body).sha256_text()
	if _cache.has(cache_key) and _cache[cache_key].expires > Time.get_ticks_msec():
		_deliver_cached.call_deferred(token, _cache[cache_key].result.duplicate(true))
		return token
	_request = HTTPRequest.new()
	_request.timeout = 30.0
	_request.body_size_limit = 262144
	_request.max_redirects = 0
	add_child(_request)
	_request.request_completed.connect(_on_completed.bind(token, facts, _request, cache_key))
	if _dispatch_request(_request, PackedStringArray(["Content-Type: application/json"]), body) != OK:
		cancel()
		return -1
	return token

func _deliver_cached(token: int, result: Dictionary) -> void:
	if token == _generation: completed.emit(token, result)

func _dispatch_request(request: HTTPRequest, headers: PackedStringArray, body: String) -> Error:
	return request.request(service_url, headers, HTTPClient.METHOD_POST, body)

func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, token: int, facts: Array, request: HTTPRequest, cache_key: String) -> void:
	if token != _generation or request != _request: return
	_request = null
	request.queue_free()
	var response := {"available": false, "reason": "unavailable"}
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		response = validate_response(body, facts)
	_cache[cache_key] = {"result": response.duplicate(true), "expires": Time.get_ticks_msec() + (3600000 if response.available else 60000)}
	while _cache.size() > 64: _cache.erase(_cache.keys()[0])
	completed.emit(token, response)

static func make_facts(results: Array) -> Array:
	var facts: Array = []
	for index in results.size():
		var item: Variant = results[index]
		if not item is Dictionary or not item.get("available", false): continue
		var actual: Variant = item.get("actual")
		var best: Variant = item.get("best")
		if not actual is Dictionary or not best is Dictionary: continue
		if actual.get("action_type") not in ACTIONS or best.get("action_type") not in ACTIONS: continue
		var numbers := [actual.get("ev_bb"), best.get("ev_bb"), item.get("gap_bb")]
		var valid := true
		for value in numbers:
			if not (value is int or value is float) or not is_finite(float(value)): valid = false
		if not valid: continue
		facts.append({"decision_id": index + 1,
			"actual_action": actual.action_type, "actual_amount": int(actual.get("amount", 0)),
			"alternative_action": best.action_type, "alternative_amount": int(best.get("amount", 0)),
			"actual_ev_bb": actual.ev_bb, "alternative_ev_bb": best.ev_bb, "gap_bb": item.gap_bb,
			"assessment": "close" if item.get("close", true) or not item.get("uncertainty_available", false) else "compare",
			"sample_count": int(item.get("world_count", 0))})
		if facts.size() == 12: break
	return facts

static func make_payload(facts: Array, locale: String) -> Dictionary:
	return {"analysis_version": CoachAnalysis.VERSION,
		"locale": "en" if locale.begins_with("en") else "zh_CN", "decisions": facts}

static func validate_response(body: PackedByteArray, facts: Array) -> Dictionary:
	var invalid := {"available": false, "reason": "invalid_response"}
	if body.size() > 262144: return invalid
	var parsed: Variant = _parse_json(body.get_string_from_utf8())
	if not parsed is Dictionary or not parsed.get("items") is Array: return invalid
	if parsed.items.is_empty() or parsed.items.size() > 3: return invalid
	var output: Array = []
	var used := {}
	for item in parsed.items:
		if not item is Dictionary or not (item.get("decision_id") is int or item.get("decision_id") is float): return invalid
		var fact: Dictionary = {}
		for candidate in facts:
			if candidate.decision_id == item.decision_id: fact = candidate; break
		if fact.is_empty() or used.has(item.decision_id): return invalid
		for key in ["actual_action", "alternative_action", "assessment"]:
			if item.get(key) != fact[key]: return invalid
		for key in ["explanation", "next_step"]:
			if not _valid_text(item.get(key), fact): return invalid
		used[item.decision_id] = true
		output.append({"decision_id": int(item.decision_id), "explanation": item.explanation.strip_edges(), "next_step": item.next_step.strip_edges()})
	return {"available": true, "items": output}

static func _parse_json(value: String) -> Variant:
	# parse_string prints malformed provider content to the engine error log.
	var parser := JSON.new()
	return parser.data if parser.parse(value) == OK else null

static func _valid_text(value: Variant, fact: Dictionary) -> bool:
	if not value is String or value.strip_edges().is_empty() or value.length() > 180: return false
	var forbidden := RegEx.new()
	forbidden.compile("[0-9０-９%％♠♣♥♦<>]|(?i:guarantee|always win|GTO|https?://)|保证|必胜|百分之")
	if forbidden.search(value) != null: return false
	var aliases := {"fold": ["fold", "弃牌"], "check": ["check", "过牌", "让牌"], "call": ["call", "跟注"], "raise": ["raise", "加注"], "all_in": ["all-in", "all in", "全下"]}
	var lower: String = value.to_lower()
	if fact.assessment == "close":
		for claim in ["mistake", "wrong", "incorrect", "should have", "错误", "失误", "必须"]:
			if lower.contains(claim): return false
	for action in aliases:
		if action in [fact.actual_action, fact.alternative_action]: continue
		for alias in aliases[action]:
			if lower.contains(alias): return false
	return true
