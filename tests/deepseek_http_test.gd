extends SceneTree
## Launched by test_coach_service.py against a temporary loopback fixture service.
var failures := 0
func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _run() -> void:
	var endpoint := OS.get_environment("POKER_COACH_TEST_URL")
	if not endpoint.begins_with("http://127.0.0.1:"):
		push_error("A temporary fixture endpoint is required.")
		quit(1)
		return
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = OS.get_cache_dir().path_join("coach-http-%d.cfg" % Time.get_ticks_usec())
	scene.deepseek_review.service_url = endpoint
	root.add_child(scene)
	scene.set_process(false)
	var game := PokerRound.new()
	game.start_new_match(1,"simple",{"mode":"practice"})
	for step in 100:
		if game.stage == TableState.STAGE_HAND_OVER: break
		var legal := game.get_legal_actions(game.current_player_index)
		game.apply_action(TableState.ACTION_CHECK if legal.actions.has(TableState.ACTION_CHECK) else TableState.ACTION_CALL)
	scene.practice_views.open_replay(game.completed_hand_record(),false)
	var deadline := Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline:
		scene.practice_views.tick(0.0)
		await process_frame
		if scene.practice_views._review_scope.is_empty() and scene.practice_views._text_review_token < 0: break
	var prose := scene.find_child("ReplayTextReviewBody",true,false)
	check(prose != null and prose.get_child_count() == 4,"real HTTP response reaches the automatic replay UI")
	if prose != null and prose.get_child_count() == 4:
		check(prose.get_child(3).text.contains("The estimates remain close."),"validated fixture prose rendered as plain text")
	scene.queue_free()
	await process_frame
	if failures == 0: print("Coach HTTP integration passed.")
	quit(failures)
