extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = "user://poker_ai_runtime_probe.cfg"
	root.add_child(scene)
	scene.set_process(false)
	scene.game.start_new_match(5, "hard")
	scene.game.community_cards = scene.game.deck.draw(3)
	scene.game.stage = TableState.STAGE_FLOP
	scene.game.current_player_index = 1
	scene._render_table()
	var before: Array = scene.game.players.duplicate(true)
	scene._run_ai_turn()
	_check(scene._ai_worker.is_started(), "hard AI starts an isolated worker")
	scene.paused = true
	await _wait_worker(scene)
	scene._process(10.0)
	_check(scene.game.players == before, "completed worker cannot act while paused")
	_check(not scene._ai_result.is_empty(), "paused decision remains available to resume")
	scene.paused = false
	scene.log_open = true
	scene._process(10.0)
	_check(scene.game.players == before, "open log also defers a finished decision")
	scene.log_open = false
	scene._process(10.0)
	_check(scene.game.players != before, "resuming applies the ready decision through the rules")
	_check(not scene.ai_pending, "applied decision releases scheduler ownership")

	# Returning to the menu and starting again while an old worker is active
	# must not apply the previous hand's decision to the new game.
	scene.game.current_player_index = 1
	scene.game.players[1].status = TableState.STATUS_ACTIVE
	scene._run_ai_turn()
	var epoch: int = scene._ai_epoch
	scene._show_menu()
	scene._show_mode_config("free")
	scene.ai_count_spin.value = 3
	scene._on_start_pressed()
	_check(scene._ai_epoch > epoch, "new match invalidates the old request")
	var new_before: Array = scene.game.players.duplicate(true)
	await _wait_worker(scene)
	scene._process(0.0)
	_check(scene.game.players == new_before, "old completion cannot alter the restarted match")
	_check(scene._ai_result.is_empty(), "stale worker result is discarded")
	# A new worker may have been scheduled, but never applies in that frame.
	scene._show_menu()
	await _wait_worker(scene)
	scene._process(10.0)
	_check(not scene._execute_ai_turn_if_allowed(), "abandoned match cannot act in menu")
	scene.game.start_new_match(1, "simple")
	scene._render_table()
	scene._on_action("call", 0)
	var ai_before: Array = scene.game.players.duplicate(true)
	scene._on_action("fold", 0)
	_check(scene.game.players == ai_before, "queued human input cannot act for the next AI player")
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("AI runtime probe passed: worker, pause, log, resume, cancel, restart, cleanup.")
	quit(failures)

func _wait_worker(scene: Node) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while scene._ai_worker.is_started() and not scene._ai_worker.is_ready() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not scene._ai_worker.is_started() or scene._ai_worker.is_ready(), "worker completes within 15 seconds")
