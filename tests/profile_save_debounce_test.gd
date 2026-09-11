extends SceneTree

class CountingMain extends "res://scripts/ui/main.gd":
	var save_calls := 0
	func _save_profile() -> void:
		save_calls += 1
		super._save_profile()

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_cache_dir().path_join("poker-volume-debounce-%d.cfg" % Time.get_ticks_usec())
	var initial := LocalProfile.default_profile()
	initial.settings.music_volume = 0.0
	initial.settings.sound_enabled = false
	_assert(LocalProfile.save_profile(initial, path), "create isolated profile")
	var main := CountingMain.new()
	main.profile_path = path
	root.add_child(main)
	main.set_process(false) # Advance debounce time explicitly, without timing races.
	var music_row: Control = main._audio_volume_control("music_volume")
	var effects_row: Control = main._audio_volume_control("sound_volume")
	main.add_child(music_row)
	main.add_child(effects_row)
	var music := music_row.get_child(0) as HSlider
	var effects := effects_row.get_child(0) as HSlider
	for value in range(1, 101):
		music.value = value
		effects.value = 100 - value
	_assert(main.save_calls == 0, "a slider sweep must not synchronously write the profile")
	_assert(main.sound_player.music_volume == 1.0 and main.sound_player.effects_volume == 0.0, "both audio levels update immediately")
	_assert(LocalProfile.load_profile(path).settings.music_volume == 0.0, "disk remains unchanged during editing")
	main._process(0.2)
	music.value = 80
	main._process(0.2)
	_assert(main.save_calls == 0, "continued editing restarts the quiet interval")
	main._process(0.11)
	_assert(main.save_calls == 1, "one write persists both sliders after editing stops")
	var saved := LocalProfile.load_profile(path)
	_assert(is_equal_approx(saved.settings.music_volume, 0.8) and saved.settings.sound_volume == 0.0, "persist the final values")
	main._process(1.0)
	_assert(main.save_calls == 1, "idle frames do not repeat the save")
	music.value = 60
	main._save_profile() # Another setting can request an immediate save.
	main._process(1.0)
	_assert(main.save_calls == 2, "an immediate save cancels the pending duplicate")
	effects.value = 45
	main._show_menu(false) # Destroy the sliders while a save is pending.
	main._process(0.31)
	_assert(main.save_calls == 3, "page rebuild retains the pending save")
	_assert(is_equal_approx(LocalProfile.load_profile(path).settings.sound_volume, 0.45), "page rebuild keeps the last slider value")
	var exit_row: Control = main._audio_volume_control("music_volume")
	main.add_child(exit_row)
	(exit_row.get_child(0) as HSlider).value = 23
	main.queue_free()
	await process_frame
	await process_frame
	_assert(is_equal_approx(LocalProfile.load_profile(path).settings.music_volume, 0.23), "exit flushes a pending final value")
	DirAccess.remove_absolute(path)
	if failures == 0:
		print("Profile save debounce tests passed.")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
