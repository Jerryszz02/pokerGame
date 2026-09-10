class_name GameAudio
extends AudioStreamPlayer
## Local prerecorded audio. This node survives page rebuilds; it never touches poker state.
const MUSIC := preload("res://assets/audio/airport-lounge.mp3")
const EFFECTS := {
	"deal": preload("res://assets/audio/card-place-1.ogg"),
	"fold": preload("res://assets/audio/card-slide-1.ogg"),
	"shuffle": preload("res://assets/audio/card-shuffle.ogg"),
	"chip": preload("res://assets/audio/chip-lay-1.ogg"),
	"settle": preload("res://assets/audio/chips-stack-1.ogg")
}
var music_player: AudioStreamPlayer
var music_volume := 0.18
var effects_volume := 0.7
var effects_enabled := true
var _unlocked := false

func _ready() -> void:
	max_polyphony = 4
	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	var track := MUSIC.duplicate() as AudioStreamMP3
	track.loop = true
	music_player.stream = track
	add_child(music_player)
	# Web playback must be initiated by a real input event, never by a timer.
	_unlocked = not OS.has_feature("web")
	_sync_levels()

func apply_settings(settings: Dictionary) -> void:
	music_volume = clampf(float(settings.get("music_volume", 0.18)), 0.0, 1.0)
	effects_volume = clampf(float(settings.get("sound_volume", 0.7)), 0.0, 1.0)
	effects_enabled = bool(settings.get("sound_enabled", true))
	_sync_levels()

func _sync_levels() -> void:
	volume_db = linear_to_db(maxf(effects_volume, 0.0001)) - 4.0
	if not effects_enabled or effects_volume == 0.0:
		stop()
	if not is_instance_valid(music_player):
		return
	music_player.volume_db = linear_to_db(maxf(music_volume, 0.0001)) - 6.0
	if DisplayServer.get_name() == "headless" or not _unlocked:
		return
	if music_volume == 0.0:
		music_player.stream_paused = true
	else:
		music_player.stream_paused = false
		if not music_player.playing:
			music_player.play()

func _input(event: InputEvent) -> void:
	if not _unlocked and event.is_pressed() and (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch):
		_unlocked = true
		_sync_levels()

func play_effect(kind: String) -> void:
	if not effects_enabled or effects_volume == 0.0 or not _unlocked or DisplayServer.get_name() == "headless":
		return
	if not EFFECTS.has(kind):
		return
	stream = EFFECTS[kind]
	play()

func stop_all() -> void:
	stop()
	if is_instance_valid(music_player):
		music_player.stop()

func _exit_tree() -> void:
	stop_all()
	stream = null
	if is_instance_valid(music_player):
		music_player.stream = null
