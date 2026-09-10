extends SceneTree
## Real-window, real-scheduler soak. Default is the 30-minute release gate.
## Short --seconds/--min-ai overrides are diagnostics, not release evidence.

var scene: Node
var failures := 0
var ai_actions := 0
var hands := 0
var frame_ms := PackedFloat64Array()
var busy_frame_ms := PackedFloat64Array()
var checkpoints: Array = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var source_sha256 := _runtime_fingerprint()
	var seconds := 1800
	var min_ai := 100
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			seconds = int(arg.get_slice("=", 1))
		if arg.begins_with("--min-ai="):
			min_ai = int(arg.get_slice("=", 1))
	if DisplayServer.get_name() == "headless":
		push_error("UI stability evidence requires a rendered window")
		quit(1)
		return
	scene = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = "user://poker_stability_probe.cfg"
	root.add_child(scene)
	scene.profile.settings.sound_enabled = false
	scene.profile.settings.fast_mode = true
	_start_match()
	# Warm fonts and shader pipelines before recording steady-state frames.
	for i in range(120):
		await process_frame
	var started := Time.get_ticks_msec()
	var previous := Time.get_ticks_usec()
	var next_checkpoint := started + 60000
	var event_key := ""
	while Time.get_ticks_msec() - started < seconds * 1000:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := float(now - previous) / 1000.0
		previous = now
		frame_ms.append(elapsed)
		if scene._ai_worker.is_started():
			busy_frame_ms.append(elapsed)
		var current_key: String = scene._event_fingerprint()
		if current_key != event_key and not scene.game.event_log.is_empty():
			var event: Dictionary = scene.game.event_log.back()
			if event.type == "action" and str(event.text).begins_with("AI "):
				ai_actions += 1
		event_key = current_key
		if scene.game.stage == TableState.STAGE_HAND_OVER:
			hands += 1
			if scene.game.match_over:
				_start_match()
			else:
				scene.game.start_next_hand()
				scene._render_table()
		elif scene.game.is_human_turn():
			var legal: Dictionary = scene.game.get_legal_actions(0)
			var action := "check" if legal.actions.has("check") else "call"
			# Regular all-ins exercise settlement/restarts as well as full streets.
			if hands % 5 == 4 and legal.actions.has("all_in"):
				action = "all_in"
			scene._on_action(action, 0)
		if Time.get_ticks_msec() >= next_checkpoint:
			await _checkpoint(started)
			next_checkpoint += 60000
			previous = Time.get_ticks_usec()
	await _checkpoint(started)
	frame_ms.sort()
	busy_frame_ms.sort()
	var p95 := _percentile(frame_ms, 0.95)
	var p99 := _percentile(frame_ms, 0.99)
	var busy_p99 := _percentile(busy_frame_ms, 0.99)
	_check(ai_actions >= min_ai, "insufficient completed AI decisions")
	_check(p95 <= 33.4 and p99 <= 100.0 and busy_p99 <= 100.0, "window frame latency exceeds release budget")
	if checkpoints.size() >= 3:
		var baseline: Dictionary = checkpoints[1]
		var last: Dictionary = checkpoints.back()
		_check(last.tweens == baseline.tweens, "running tween count grows across the soak")
		_check(last.nodes == baseline.nodes, "menu node count grows across the soak")
		_check(last.orphans <= baseline.orphans, "orphan count grows across the soak")
		_check(last.memory_bytes <= baseline.memory_bytes + 32 * 1024 * 1024, "static memory grows by more than 32 MiB after warmup")
	var report := {
		"source_sha256": source_sha256, "probe_sha256": FileAccess.get_sha256("res://tests/ui_stability_probe.gd"),
		"commit": OS.get_environment("POKER_TEST_COMMIT"), "dirty": OS.get_environment("POKER_TEST_DIRTY") != "false",
		"duration_seconds": seconds, "ai_actions": ai_actions, "hands": hands,
		"frames": frame_ms.size(), "busy_frames": busy_frame_ms.size(),
		"frame_p95_ms": p95, "frame_p99_ms": p99, "busy_frame_p99_ms": busy_p99,
		"frame_max_ms": frame_ms[frame_ms.size() - 1] if not frame_ms.is_empty() else 0,
		"checkpoints": checkpoints, "failures": failures,
		"engine": Engine.get_version_info().string, "os": OS.get_name(),
		"processor": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"full_release_duration": seconds >= 1800 and min_ai >= 100
	}
	var report_path := "user://poker_stability_report.json"
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("UI stability report: ", ProjectSettings.globalize_path(report_path))
	print(JSON.stringify(report))
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("UI stability probe passed.")
	quit(failures)

func _start_match() -> void:
	scene._show_menu()
	scene._show_mode_config("free")
	scene.ai_count_spin.value = 5
	scene.difficulty_options.select(2)
	scene._on_start_pressed()

func _checkpoint(started: int) -> void:
	scene._show_menu()
	while scene._ai_worker.is_started():
		await process_frame
	await process_frame
	await process_frame
	var point := {"elapsed_s": (Time.get_ticks_msec() - started) / 1000, "nodes": get_node_count(), "tweens": get_processed_tweens().size(), "objects": Performance.get_monitor(Performance.OBJECT_COUNT), "orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), "memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "ai_actions": ai_actions, "hands": hands}
	checkpoints.append(point)
	print("Soak checkpoint: ", JSON.stringify(point))
	_start_match()

func _percentile(values: PackedFloat64Array, fraction: float) -> float:
	return values[mini(values.size() - 1, int(ceil(values.size() * fraction)) - 1)] if not values.is_empty() else 9999.0

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _runtime_fingerprint() -> String:
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		return ""
	var paths := Array(config.get_value("preset.0", "export_files", PackedStringArray()))
	paths.append("res://project.godot")
	paths.append("res://export_presets.cfg")
	paths.sort()
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	for path in paths:
		digest.update((str(path) + "\n" + FileAccess.get_sha256(path) + "\n").to_utf8_buffer())
	return digest.finish().hex_encode()
