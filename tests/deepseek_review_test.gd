extends SceneTree
const FakeClient := preload("res://tests/replay_review_fixture.gd")
var failures := 0
func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func envelope(items: Variant) -> PackedByteArray:
	return JSON.stringify({"items":items}).to_utf8_buffer()
func _run() -> void:
	var numerical := {"available":true,"actual":{"action_type":"call","amount":20,"ev_bb":0.2},"best":{"action_type":"fold","amount":0,"ev_bb":0.3},"gap_bb":0.1,"close":true,"uncertainty_available":true,"world_count":32,"depth":8,"opponent_hole_cards":["secret"]}
	var facts := DeepSeekReview.make_facts([numerical,{"available":false}])
	check(facts.size() == 1 and not JSON.stringify(facts).contains("secret"),"only allowlisted numerical facts leave the local analyzer")
	check(DeepSeekReview.make_facts([{"available":true}]).is_empty(),"incomplete numerical results are not sent")
	var payload := DeepSeekReview.make_payload(facts,"en_US")
	check(payload == {"analysis_version":CoachAnalysis.VERSION,"locale":"en","decisions":facts},"service receives facts and locale, never a provider prompt or key")
	var item := {"decision_id":1,"actual_action":"call","alternative_action":"fold","assessment":"close","explanation":"The estimates remain close.","next_step":"Review the sampling uncertainty before deciding."}
	check(DeepSeekReview.validate_response(envelope([item]),facts).available,"validated qualitative explanation is accepted")
	for field in ["decision_id","actual_action","alternative_action","assessment"]:
		var bad := item.duplicate(); bad[field] = 99 if field == "decision_id" else "invented"
		check(not DeepSeekReview.validate_response(envelope([bad]),facts).available,"reject unsupported factual reference: "+field)
	for text in ["Expect 90% wins.","Raise now.","保证获胜", "<b>advice</b>", "Calling was a mistake."]:
		var bad := item.duplicate();bad.explanation = text
		check(not DeepSeekReview.validate_response(envelope([bad]),facts).available,"reject unsupported numbers, actions, guarantees or markup")
	check(not DeepSeekReview.validate_response(envelope([]),facts).available,"empty output is unavailable")
	check(not DeepSeekReview.validate_response(envelope([item,item]),facts).available,"duplicate decision references are rejected")
	check(not DeepSeekReview.validate_response("not json".to_utf8_buffer(),facts).available,"malformed output is unavailable")
	var client := FakeClient.new()
	client.automatic = false
	root.add_child(client)
	client.service_url = ""
	check(client.request_review([numerical],"en") == -1 and client.calls == 0,"no service URL means no outbound request")
	client.service_url = "http://127.0.0.1:8062/review"
	var received: Array = []
	client.completed.connect(func(token: int,result: Dictionary): received.append({"token":token,"result":result}))
	var first := client.request_review([numerical],"en")
	var old_request := client._request
	check(client.sent_headers == PackedStringArray(["Content-Type: application/json"]),"client never sends provider authorization")
	check(old_request.timeout == 30.0 and old_request.max_redirects == 0 and old_request.body_size_limit == 262144,"transport limits and redirect boundary")
	client.cancel()
	var second := client.request_review([numerical],"en")
	old_request.request_completed.emit(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),envelope([item]))
	check(received.is_empty() and second > first,"late cancelled completion cannot escape")
	client._request.request_completed.emit(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),envelope([item]))
	check(received.size() == 1 and received[0].token == second and received[0].result.available,"current completion delivered once")
	var calls: int = client.calls
	var cached := client.request_review([numerical],"en")
	await process_frame
	check(client.calls == calls and received[-1].token == cached and received[-1].result.available,"reopening uses a validated cached response without a network call")
	var before := received.size()
	client.request_review([numerical],"en")
	client.cancel()
	await process_frame
	check(received.size() == before,"cancelled deferred cache result cannot escape")
	client.request_review([numerical],"zh_CN")
	client._request.request_completed.emit(HTTPRequest.RESULT_SUCCESS,503,PackedStringArray(),"private response data".to_utf8_buffer())
	check(received[-1].result == {"available":false,"reason":"unavailable"},"service error bodies are never displayed")
	calls = client.calls
	client.request_review([numerical],"zh_CN")
	await process_frame
	check(client.calls == calls,"failed service has a retry cooldown")
	client.queue_free()
	await process_frame
	await _check_replay_wiring()
	if failures == 0: print("DeepSeek review tests passed.")
	quit(failures)

func _check_replay_wiring() -> void:
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = OS.get_cache_dir().path_join("deepseek-fixture-%d.cfg" % Time.get_ticks_usec())
	scene.deepseek_review.free()
	var fake := FakeClient.new()
	fake.automatic = false
	scene.deepseek_review = fake
	root.add_child(scene)
	scene.set_process(false)
	var game := PokerRound.new()
	game.start_new_match(1,"simple",{"mode":"practice"})
	for step in 100:
		if game.stage == TableState.STAGE_HAND_OVER: break
		var legal := game.get_legal_actions(game.current_player_index)
		game.apply_action(TableState.ACTION_CHECK if legal.actions.has(TableState.ACTION_CHECK) else TableState.ACTION_CALL)
	var record := game.completed_hand_record()
	scene.practice_views.open_replay(record,false)
	check(not scene.practice_views._review_scope.is_empty(),"opening replay starts analysis automatically")
	var deadline := Time.get_ticks_msec()+15000
	while not scene.practice_views._review_scope.is_empty() and Time.get_ticks_msec()<deadline:
		scene.practice_views.tick(0.0)
		await process_frame
	check(fake.calls == 1,"local completion automatically requests prose exactly once")
	check(_prose(scene).contains(GameLocalization.present("本地规则分析")) and _prose(scene).contains("BB"),"local prose is already visible while the service is pending")
	check(scene.find_child("DeepSeekReplay",true,false) == null and scene.find_child("ReplayAnalysis",true,false) == null,"replay needs no analysis or generation buttons")
	var request := fake._request
	scene.practice_views._request_text_review()
	scene.practice_views._seek(1)
	scene.find_child("ReplayOmniscientToggle",true,false).button_pressed = true
	check(fake.calls == 1 and fake._request == request,"seeking and perspective changes preserve the single pending review")
	fake.respond(request,fake.sent)
	check(scene.find_child("ReplayTextReviewBody",true,false).get_child_count() == 4,"validated prose appears automatically in replay")
	scene.practice_views.open_replay(record,false)
	await process_frame
	check(fake.calls == 1 and scene.find_child("ReplayTextReviewBody",true,false).get_child_count() == 4,"reopening the same hand reuses numeric and prose results")
	var service_url: String = fake.service_url
	fake.service_url = ""
	var no_url_calls: int = fake.calls
	scene.practice_views.open_replay(record,false)
	check(fake.calls == no_url_calls and scene.practice_views._text_review_token == -1 and _prose(scene).contains("BB"),"unconfigured service immediately uses local prose without a request")
	check(_prose(scene).contains(GameLocalization.present("本地规则分析")),"offline prose is not labeled as cloud AI output")
	fake.service_url = service_url
	fake._cache.clear()
	fake.dispatch_error = ERR_CANT_CONNECT
	scene.practice_views.open_replay(record,false)
	check(scene.practice_views._text_review_token == -1 and _prose(scene).contains("BB"),"immediate dispatch failure retains local prose")
	fake.dispatch_error = OK
	for failure in [[HTTPRequest.RESULT_CANT_CONNECT,0,""], [HTTPRequest.RESULT_TIMEOUT,0,""], [HTTPRequest.RESULT_SUCCESS,429,"private response data"], [HTTPRequest.RESULT_SUCCESS,503,"private response data"], [HTTPRequest.RESULT_SUCCESS,200,"not JSON"], [HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED,200,""]]:
		fake._cache.clear()
		scene.practice_views.open_replay(record,false)
		fake._request.request_completed.emit(failure[0],failure[1],PackedStringArray(),str(failure[2]).to_utf8_buffer())
		check(scene.practice_views._text_review_token == -1 and _prose(scene).contains("BB") and _prose(scene).contains(GameLocalization.present("本地规则分析")),"transport/status/invalid-response failure keeps useful local prose")
		check(not _prose(scene).contains("private response data") and not _prose(scene).contains(GameLocalization.present("正在尝试云端解读，完成后将自动更新。")),"failure stops the pending notice and never displays server error bodies")
	var failed_calls: int = fake.calls
	scene.practice_views.open_replay(record,false)
	await process_frame
	check(fake.calls == failed_calls and _prose(scene).contains(GameLocalization.present("本地规则分析")),"failure cooldown also retains the local explanation")
	for key in fake._cache: fake._cache[key].expires = 0
	scene.practice_views.open_replay(record,false)
	fake.respond(fake._request,fake.sent)
	check(fake.calls == failed_calls+1 and scene.find_child("ReplayTextReviewBody",true,false).get_child_count() == 4,"after cooldown a recovered service replaces fallback with validated prose")
	fake._cache.clear()
	scene.practice_views.open_replay(record,false)
	check(fake._request != null,"uncached replay starts a new request")
	scene.practice_views._close_replay()
	check(fake._request == null and scene.practice_views._text_review_token == -1,"leaving replay cancels waiting")
	var older := record.duplicate(true)
	for frame in older.frames: frame.erase("decision_context")
	var calls: int = fake.calls
	scene.practice_views.open_replay(older,false)
	check(fake.calls == calls and scene.practice_views._review_results.is_empty(),"legacy replay without reliable facts never calls the service")
	check(not _prose(scene).contains("BB"),"legacy replay never fabricates a local written review")
	scene.queue_free()
	await process_frame

func _prose(scene: Node) -> String:
	var body := scene.find_child("ReplayTextReviewBody",true,false)
	if body == null: return ""
	var text := ""
	for child in body.get_children():
		if child is Label: text += child.text + "\n"
	return text
