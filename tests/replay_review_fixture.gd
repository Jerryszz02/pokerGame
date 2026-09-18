extends DeepSeekReview
## Deterministic local fixture; UI probes never use the owner's service or key.
var calls := 0
var sent: Dictionary = {}
var sent_headers := PackedStringArray()
var automatic := true

func _dispatch_request(request: HTTPRequest, headers: PackedStringArray, body: String) -> Error:
	calls += 1
	sent = JSON.parse_string(body)
	sent_headers = headers
	if automatic: respond.call_deferred(request, sent)
	return OK

func respond(request: HTTPRequest, payload: Dictionary) -> void:
	if not is_instance_valid(request) or request != _request: return
	var fact: Dictionary = payload.decisions[0]
	var item := {"decision_id":fact.decision_id,"actual_action":fact.actual_action,
		"alternative_action":fact.alternative_action,"assessment":fact.assessment,
		"explanation":"The estimates reflect a sampled model.","next_step":"Consider uncertainty and future risk."}
	if payload.locale == "zh_CN":
		item.explanation = "这些估值来自抽样模型，仍有不确定性。"
		item.next_step = "回看当时的投入与后续风险，再比较两种选择。"
	request.request_completed.emit(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify({"items":[item]}).to_utf8_buffer())
