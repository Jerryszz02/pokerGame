extends "res://tools/promo_capture.gd"

var failures := 0

# Override the deferred capture entry point; no window or movie is needed.
func _run() -> void:
	tag = "isolation-test-" + str(Time.get_ticks_usec())
	var first_path := _new_capture_profile_path()
	check(LocalProfile.save_profile(LocalProfile.default_profile(), first_path), "first capture profile saves")
	var first_store := PracticeStore.new(first_path + ".practice")
	check(first_store.complete_guided_tutorial("G1"), "first capture completes G1")
	check(PracticeStore.new(first_path + ".practice").guided_resume_lesson() == "G2", "fixture persists the stale tutorial progress")

	# Same tag and process ID model a subsequent capture after OS PID reuse.
	var second_path := _new_capture_profile_path()
	check(second_path != first_path, "captures in the same process receive different profile paths")
	check(not FileAccess.file_exists(second_path), "new capture cannot reopen an old profile")
	var second_store := PracticeStore.new(second_path + ".practice")
	check(second_store.guided_resume_lesson() == "G1", "new capture starts at G1 despite the earlier saved progress")
	check(second_store.records().is_empty(), "new capture has no previous hands")
	if failures == 0:
		print("Promo capture isolation tests passed.")
	quit(failures)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
