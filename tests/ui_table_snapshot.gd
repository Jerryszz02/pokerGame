extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	await process_frame
	for ai_count in [1, 3, 5]:
		await _snapshot_table(ai_count)
	await _snapshot_flop()
	await _snapshot_showdown()
	if failures == 0:
		print("All table snapshots saved.")
	else:
		push_error("%d table snapshots failed." % failures)
	quit(failures)

func _snapshot_showdown() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = "user://poker_ui_table_snapshot.cfg"
	root.add_child(scene)
	var main_control: Control = scene
	main_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene.game.start_new_match(3, "hard")
	scene.game.stage = TableState.STAGE_HAND_OVER
	scene.game.community_cards = [
		CardUtil.make_card(14, "S"), CardUtil.make_card(10, "H"), CardUtil.make_card(7, "D"),
		CardUtil.make_card(7, "C"), CardUtil.make_card(2, "S")
	]
	scene.game.players[0].hole_cards = [CardUtil.make_card(7, "H"), CardUtil.make_card(7, "S")]
	scene.game.players[1].status = TableState.STATUS_FOLDED
	scene.game.winners = [{"player_index": 0, "amount": 500, "rank_name": "三条"}]
	scene.game.last_message = "你用三条赢得 500。"
	scene._render_table()
	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png("/tmp/poker_table_showdown.png")
	_assert(error == OK, "showdown snapshot should save")
	if scene.sound_player:
		scene.sound_player.stop()
	scene.queue_free()
	await process_frame
	await process_frame

func _snapshot_flop() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = "user://poker_ui_table_snapshot.cfg"
	root.add_child(scene)
	var main_control: Control = scene
	main_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene.game.start_new_match(5, "hard")
	scene.game.community_cards = [
		CardUtil.make_card(14, "S"), CardUtil.make_card(10, "H"), CardUtil.make_card(7, "D")
	]
	var bets := [120, 120, 300, 0, 40, 120]
	for i in range(scene.game.players.size()):
		scene.game.players[i].current_bet = bets[i]
		scene.game.players[i].last_action = "Fold" if bets[i] == 0 else "Call"
		if bets[i] == 0:
			scene.game.players[i].status = TableState.STATUS_FOLDED
	scene.game.current_player_index = 0
	scene._render_table()
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png("/tmp/poker_table_flop.png")
	_assert(error == OK, "flop snapshot should save")
	if scene.sound_player:
		scene.sound_player.stop()
	scene.queue_free()
	await process_frame
	await process_frame

func _snapshot_table(ai_count: int) -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = "user://poker_ui_table_snapshot.cfg"
	root.add_child(scene)
	var main_control: Control = scene
	main_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene.game.start_new_match(ai_count, "hard")
	var iterations := 0
	while scene.game.is_ai_turn() and iterations < 12:
		var idx: int = scene.game.current_player_index
		var decision: Dictionary = AiDecision.decide(scene.game, idx)
		scene.game.apply_action(decision.action_type, int(decision.get("amount", 0)), str(decision.get("decision_label", "")))
		iterations += 1
	scene._render_table()
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := "/tmp/poker_table_ai%d.png" % ai_count
	var error := image.save_png(path)
	_assert(error == OK, "snapshot for %d AI should save to %s" % [ai_count, path])
	if scene.sound_player:
		scene.sound_player.stop()
	scene.queue_free()
	await process_frame
	await process_frame

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
