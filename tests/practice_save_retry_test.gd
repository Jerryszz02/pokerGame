extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
var failures := 0
var scratch := OS.get_cache_dir().path_join("poker-practice-save-retry-" + str(Time.get_ticks_usec()))

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := MainScene.instantiate()
	scene.profile_path = scratch.path_join("profile.cfg")
	DirAccess.make_dir_recursive_absolute(scratch)
	get_root().add_child(scene)
	await process_frame
	var source := PokerRound.new()
	source.start_new_match(1, "simple", {"mode": "practice"})
	source.mark_assistance_viewed()
	while source.stage != TableState.STAGE_HAND_OVER:
		var legal := source.get_legal_actions(source.current_player_index)
		source.apply_action("check" if legal.actions.has("check") else "call")
	var record: Dictionary = source.completed_hand_record()
	var blocked_match := str(record.match_id)
	var other_match := "match-other-retry"
	scene.practice_store._disk_hand_count = PracticeStore.CAPACITY
	scene._pending_records[record.id] = record
	scene._pending_matches[blocked_match] = {"outcome":"won", "config":record.config.duplicate(true)}
	scene._pending_matches[other_match] = {"outcome":"won", "config":record.config.duplicate(true)}
	scene._retry_practice_saves()
	check(scene._pending_records.has(record.id), "capacity failure keeps pending hand")
	check(scene._pending_matches.has(blocked_match), "match waits for its pending hand")
	check(not scene._pending_matches.has(other_match), "other match is not blocked by pending hand")
	check(scene.practice_store.state.matches.has(other_match), "other match is durably finished")
	scene.practice_store._disk_hand_count = 0
	scene._retry_practice_saves()
	check(scene._pending_records.is_empty() and not scene._pending_matches.has(blocked_match), "capacity recovery flushes blocked hand and match")
	var reopened := PracticeStore.new(scene.practice_store.base_path)
	check(reopened.state.matches.has(blocked_match) and reopened.state.matches[blocked_match].assistance_viewed, "reopened match retains assisted source")
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("Practice save retry tests passed.")
	quit(failures)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
