extends SceneTree
var failures := 0
class FakeClient extends DeepSeekReview:
	var calls := 0
	var sent: Dictionary = {}
	var authenticated := false
	func _dispatch_request(_request: HTTPRequest, headers: PackedStringArray, body: String) -> Error:
		calls += 1
		sent = JSON.parse_string(body)
		authenticated = headers.size() == 2 and headers[1].begins_with("Authorization: Bearer ")
		return OK

func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func envelope(items: Variant, finish: String = "stop") -> PackedByteArray:
	return JSON.stringify({"choices":[{"finish_reason":finish,"message":{"content":JSON.stringify({"items":items})}}]}).to_utf8_buffer()
func _run() -> void:
	var numerical := {"available":true,"actual":{"action_type":"call","amount":20,"ev_bb":0.2},"best":{"action_type":"fold","amount":0,"ev_bb":0.3},"gap_bb":0.1,"close":true,"uncertainty_available":true,"world_count":32,"depth":8,"opponent_hole_cards":["secret"]}
	var facts := DeepSeekReview.make_facts([numerical,{"available":false}])
	check(facts.size() == 1 and not JSON.stringify(facts).contains("secret"),"only allowlisted numerical facts leave the local analyzer")
	check(DeepSeekReview.make_facts([{"available":true}]).is_empty(),"incomplete numerical results are not sent")
	var payload := DeepSeekReview.make_payload(facts,"en")
	check(payload.model == DeepSeekReview.MODEL and payload.response_format.type == "json_object" and payload.stream == false,"bounded non-streaming JSON contract")
	check(payload.thinking.type == "disabled" and payload.max_tokens == 1200,"bounded text-only generation")
	var item := {"decision_id":1,"actual_action":"call","alternative_action":"fold","assessment":"close","explanation":"The estimates remain close.","next_step":"Review the sampling uncertainty before deciding."}
	check(DeepSeekReview.validate_response(envelope([item]),facts).available,"validated qualitative explanation is accepted")
	for field in ["decision_id","actual_action","alternative_action","assessment"]:
		var bad := item.duplicate(); bad[field] = 99 if field == "decision_id" else "invented"
		check(not DeepSeekReview.validate_response(envelope([bad]),facts).available,"reject unsupported factual reference: "+field)
	for text in ["Expect 90% wins.","Raise now.","保证获胜", "<b>advice</b>", "Calling was a mistake."]:
		var bad := item.duplicate();bad.explanation = text
		check(not DeepSeekReview.validate_response(envelope([bad]),facts).available,"reject unsupported numbers, actions, guarantees or markup")
	check(not DeepSeekReview.validate_response(envelope([item],"length"),facts).available,"reject truncated output even when JSON happens to parse")
	check(not DeepSeekReview.validate_response(envelope([]),facts).available,"empty output is unavailable")
	check(not DeepSeekReview.validate_response(envelope([item,item]),facts).available,"duplicate decision references are rejected")
	check(not DeepSeekReview.validate_response("not json".to_utf8_buffer(),facts).available,"malformed output is unavailable")
	var client := FakeClient.new()
	root.add_child(client)
	check(client.request_review([numerical],"en") == -1 and client.calls == 0,"no key means no outbound request")
	check(not client.set_session_key("bad\r\nheader"),"header-injection input rejected")
	check(client.set_session_key("fixture-not-a-real-key") and client.calls == 0,"saving a key alone never uses the network")
	var received: Array = []
	client.completed.connect(func(token: int,result: Dictionary): received.append({"token":token,"result":result}))
	var first := client.request_review([numerical],"en")
	var old_request := client._request
	check(client.authenticated and not JSON.stringify(client.sent).contains("fixture-not-a-real-key"),"key stays in authorization header, outside prompt")
	check(old_request.timeout == 30.0 and old_request.max_redirects == 0 and old_request.body_size_limit == 262144,"transport limits and redirect boundary")
	client.cancel()
	var second := client.request_review([numerical],"en")
	old_request.request_completed.emit(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),envelope([item]))
	check(received.is_empty() and second > first,"late cancelled completion cannot escape")
	client._request.request_completed.emit(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),envelope([item]))
	check(received.size() == 1 and received[0].token == second and received[0].result.available,"current completion delivered once")
	client.request_review([numerical],"en")
	client._request.request_completed.emit(HTTPRequest.RESULT_SUCCESS,401,PackedStringArray(),"private response data".to_utf8_buffer())
	check(received[-1].result == {"available":false,"reason":"credentials"},"provider error bodies are never displayed")
	client.request_review([numerical],"en")
	client.set_session_key("")
	check(not client.has_key() and client._request == null,"clearing a key cancels pending requests")
	client.queue_free()
	await process_frame
	var fresh := FakeClient.new()
	check(not fresh.has_key(),"a new session starts without credentials")
	fresh.free()
	await _check_replay_wiring(numerical,item)
	if failures == 0: print("DeepSeek review tests passed.")
	quit(failures)

func _check_replay_wiring(numerical: Dictionary, item: Dictionary) -> void:
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = OS.get_cache_dir().path_join("deepseek-fixture-%d.cfg" % Time.get_ticks_usec())
	scene.deepseek_review.free()
	var fake := FakeClient.new()
	scene.deepseek_review = fake
	root.add_child(scene)
	scene.set_process(false)
	var game := PokerRound.new()
	game.start_new_match(1,"simple",{"mode":"practice"})
	for step in 100:
		if game.stage == TableState.STAGE_HAND_OVER: break
		var legal := game.get_legal_actions(game.current_player_index)
		game.apply_action(TableState.ACTION_CHECK if legal.actions.has(TableState.ACTION_CHECK) else TableState.ACTION_CALL)
	scene.practice_views.open_replay(game.completed_hand_record(),false)
	scene.practice_views._review_results = [numerical]
	scene.practice_views._render_replay_analysis()
	fake.set_session_key("fixture-not-a-real-key")
	scene.practice_views._request_text_review()
	scene.practice_views._request_text_review()
	check(fake.calls == 1,"repeated clicks cannot create concurrent paid requests")
	scene.practice_views._seek(0)
	check(fake._request == null and scene.practice_views._text_review_token == -1,"seeking cancels the text request and resets the UI")
	scene.practice_views._request_text_review()
	fake._request.request_completed.emit(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),envelope([item]))
	check(scene.find_child("DeepSeekReviewBody",true,false).get_child_count() == 3,"validated response reaches the replay UI")
	check(not scene.find_child("DeepSeekReplay",true,false).disabled,"response restores the explicit retry action")
	scene.practice_views._request_text_review()
	scene.practice_views._close_replay()
	check(fake._request == null,"leaving the replay cancels the text request")
	scene.queue_free()
	await process_frame
