extends SceneTree
const Profile := preload("res://scripts/game/local_profile.gd")
const Audio := preload("res://scripts/ui/game_audio.gd")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var normalized := Profile.normalize_profile({"settings": {"music_volume": INF, "sound_volume": -1}})
	_assert(normalized.settings.music_volume == 0.18 and normalized.settings.sound_volume == 0.0, "invalid volume should be safely normalized")
	var quiet_legacy := Profile.normalize_profile({"settings": {"sound_enabled": false}})
	_assert(quiet_legacy.settings.music_volume == 0.0, "legacy mute preference should not gain new music")
	var path := OS.get_cache_dir().path_join("poker_audio_test_%d.cfg" % Time.get_ticks_usec())
	var saved := Profile.default_profile()
	saved.settings.music_volume = 0.35
	saved.settings.sound_volume = 0.6
	_assert(Profile.save_profile(saved, path), "audio settings should save")
	var loaded := Profile.load_profile(path)
	_assert(is_equal_approx(loaded.settings.music_volume, 0.35) and is_equal_approx(loaded.settings.sound_volume, 0.6), "audio levels should survive restart")
	DirAccess.remove_absolute(path)
	var audio := Audio.new()
	root.add_child(audio)
	_assert(audio.music_player.stream is AudioStreamMP3, "background music should be the packaged recording")
	_assert(audio.music_player.stream.loop, "background music should repeat")
	_assert(audio.music_player.stream.get_length() > 300.0, "music recording should be complete")
	for key in Audio.EFFECTS:
		_assert(Audio.EFFECTS[key].get_length() > 0.0, "effect %s should decode" % key)
	audio.apply_settings({"music_volume": 0.0, "sound_volume": 0.4, "sound_enabled": true})
	_assert(audio.music_volume == 0.0 and audio.effects_volume == 0.4, "music and effects levels should be independent")
	audio.apply_settings({"music_volume": 0.2, "sound_volume": 0.0, "sound_enabled": false})
	_assert(audio.music_volume == 0.2 and not audio.effects_enabled, "muting effects should not mute music")
	audio._unlocked = false
	var motion := InputEventMouseMotion.new()
	audio._input(motion)
	_assert(not audio._unlocked, "mouse motion is not an audio-unlocking gesture")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	audio._input(click)
	_assert(audio._unlocked, "a real click should unlock browser audio")
	audio.stop_all()
	audio.queue_free()
	await process_frame
	if failures == 0:
		print("Audio tests passed.")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
