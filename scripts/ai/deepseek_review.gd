class_name DeepSeekReview
extends Node
## Session-only credentials; only explicit replay requests may use the network.
## Local rules and numerical analysis remain authoritative.
signal completed(token: int, result: Dictionary)
const ENDPOINT := "https://api.deepseek.com/chat/completions"
const MODEL := "deepseek-flash"
const ACTIONS := ["fold", "check", "call", "raise", "all_in"]
var _api_key := ""
var _generation := 0
var _request: HTTPRequest

func has_key() -> bool:
	return not _api_key.is_empty()

func set_session_key(value: String) -> bool:
	var clean := value.strip_edges()
	if not clean.is_empty():
		if clean.length() < 16 or clean.length() > 512: return false
		for index in clean.length():
			if clean.unicode_at(index) < 33 or clean.unicode_at(index) > 126: return false
	cancel()
	_api_key = clean
	return true

func cancel() -> void:
	_generation += 1
	if is_instance_valid(_request):
		_request.cancel_request()
		_request.queue_free()
	_request = null

func _exit_tree() -> void:
	cancel()
	_api_key = ""

func request_review(results: Array, locale: String) -> int:
	cancel()
	var facts := make_facts(results)
	if not has_key() or facts.is_empty() or not is_inside_tree(): return -1
	var token := _generation
	_request = HTTPRequest.new()
	_request.timeout = 30.0
	_request.body_size_limit = 262144
	_request.max_redirects = 0
	add_child(_request)
	_request.request_completed.connect(_on_completed.bind(token, facts, _request))
	var body := JSON.stringify(make_payload(facts, locale))
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + _api_key])
	if _dispatch_request(_request, headers, body) != OK:
		cancel()
		return -1
	return token

func _dispatch_request(request: HTTPRequest, headers: PackedStringArray, body: String) -> Error:
	return request.request(ENDPOINT, headers, HTTPClient.METHOD_POST, body)

func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, token: int, facts: Array, request: HTTPRequest) -> void:
	if token != _generation or request != _request: return
	_request = null
	request.queue_free()
	var response := {"available": false, "reason": "network"}
	if result == HTTPRequest.RESULT_SUCCESS:
		if code == 200: response = validate_response(body, facts)
		elif code in [401, 403]: response.reason = "credentials"
		elif code == 402: response.reason = "balance"
		elif code == 429: response.reason = "rate_limit"
		else: response.reason = "provider"
	# Never expose raw response bodies, request headers, or credentials in errors.
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
	var language := "English" if locale.begins_with("en") else "Simplified Chinese"
	var instructions := "Write a brief poker practice explanation in %s using ONLY supplied local-analysis facts. " % language
	instructions += "Return JSON only: {\"items\":[{\"decision_id\":1,\"actual_action\":\"call\",\"alternative_action\":\"fold\",\"assessment\":\"compare\",\"explanation\":\"Short qualitative explanation\",\"next_step\":\"Short practice suggestion\"}]}. "
	instructions += "Choose one to three distinct supplied decisions. Copy decision_id, actual_action, alternative_action and assessment exactly from that decision. "
	instructions += "Each text must be at most 180 characters. Do not write numbers, percentages, card names, imagined holdings, outcomes, or actions other than the two supplied actions in either text. "
	instructions += "The UI supplies all numeric values. These are approximate neutral-range sampled EVs, not optimal play. For close, acknowledge unresolved sampling uncertainty and do not call the action a mistake. For compare, invite comparison of sizing and future risk. Never guarantee success."
	return {"model": MODEL, "stream": false, "thinking": {"type": "disabled"}, "max_tokens": 1200,
		"response_format": {"type": "json_object"},
		"messages": [{"role": "system", "content": instructions}, {"role": "user", "content": JSON.stringify({"decisions": facts})}]}

static func validate_response(body: PackedByteArray, facts: Array) -> Dictionary:
	var invalid := {"available": false, "reason": "invalid_response"}
	if body.size() > 262144: return invalid
	var envelope: Variant = _parse_json(body.get_string_from_utf8())
	if not envelope is Dictionary: return invalid
	var choices: Variant = envelope.get("choices")
	if not choices is Array or choices.size() != 1 or not choices[0] is Dictionary: return invalid
	var choice: Dictionary = choices[0]
	if choice.get("finish_reason") != "stop" or not choice.get("message") is Dictionary: return invalid
	var content: Variant = choice.message.get("content")
	if not content is String or content.strip_edges().is_empty() or content.length() > 6000: return invalid
	var parsed: Variant = _parse_json(content)
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
