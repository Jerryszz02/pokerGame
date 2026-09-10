class_name LocalProfile
extends RefCounted

const PROFILE_PATH := "user://poker_profile.cfg"
const PROFILE_VERSION := 2

static func default_profile() -> Dictionary:
	return {
		"version": PROFILE_VERSION,
		"settings": {"ai_count": 3, "difficulty": "medium", "initial_stack": 1000, "small_blind": 10, "big_blind": 20, "mode": "free", "show_hints": false, "pause_each_hand": true, "sound_enabled": true, "music_volume": 0.18, "sound_volume": 0.7, "fast_mode": false, "language": "system"},
		"stats": {"total_hands": 0, "total_net_profit": 0, "total_win_hands": 0, "max_single_hand_win": 0}
	}

static func load_profile(path: String = PROFILE_PATH) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return default_profile()
	var raw := {}
	for section in ["settings", "stats"]:
		raw[section] = {}
		if config.has_section(section):
			for key in config.get_section_keys(section):
				raw[section][key] = config.get_value(section, key)
	raw.version = _safe_int(config.get_value("meta", "version", 1), PROFILE_VERSION + 1)
	return normalize_profile(raw)

static func save_profile(profile: Dictionary, path: String = PROFILE_PATH) -> bool:
	var existing := ConfigFile.new()
	if FileAccess.file_exists(path) and existing.load(path) == OK and _safe_int(existing.get_value("meta", "version", 1), PROFILE_VERSION + 1) > PROFILE_VERSION:
		return false
	if bool(profile.get("read_only", false)):
		return false
	var normalized := normalize_profile(profile)
	var config := ConfigFile.new()
	config.set_value("meta", "version", PROFILE_VERSION)
	for section in ["settings", "stats"]:
		for key in normalized[section]:
			config.set_value(section, key, normalized[section][key])
	# Preserve the last valid profile if writing the new file fails.
	var temporary := path + ".tmp"
	if config.save(temporary) != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK

static func normalize_profile(profile: Dictionary) -> Dictionary:
	var normalized := default_profile()
	if _safe_int(profile.get("version", 1), PROFILE_VERSION + 1) > PROFILE_VERSION:
		normalized.read_only = true
		normalized.notice = "偏好资料来自更新版本，已保留原文件；本次使用默认设置且不覆盖。"
		return normalized
	var settings: Variant = profile.get("settings", {})
	if settings is Dictionary:
		normalized.settings.ai_count = clampi(_safe_int(settings.get("ai_count"), 3), 1, 5)
		normalized.settings.difficulty = _safe_difficulty(settings.get("difficulty"))
		for key in ["sound_enabled", "fast_mode"]:
			if settings.get(key) is bool:
				normalized.settings[key] = settings[key]
		normalized.settings.language = GameLocalization.normalize_choice(settings.get("language", GameLocalization.SYSTEM))
		normalized.settings.music_volume = _safe_volume(settings.get("music_volume"), 0.18 if normalized.settings.sound_enabled else 0.0)
		normalized.settings.sound_volume = _safe_volume(settings.get("sound_volume"), 0.7)
		var safe := MatchConfig.normalize(settings)
		for key in ["initial_stack", "small_blind", "big_blind", "mode", "show_hints", "pause_each_hand"]:
			normalized.settings[key] = safe[key]
		for key in safe:
			if settings.has(key) and (typeof(settings[key]) != typeof(normalized.settings[key]) or settings[key] != normalized.settings[key]):
				normalized.notice = "部分旧配置无效，已回退到支持的安全配置。"
	var stats: Variant = profile.get("stats", {})
	if stats is Dictionary:
		for key in normalized.stats:
			var value := _safe_int(stats.get(key), 0)
			normalized.stats[key] = value if key == "total_net_profit" else maxi(0, value)
	return normalized

static func migrate_legacy(profile: Dictionary) -> Dictionary:
	var out := normalize_profile(profile)
	out.version = PROFILE_VERSION
	return out

static func reset_stats(profile: Dictionary) -> Dictionary:
	var normalized := normalize_profile(profile)
	normalized.stats = default_profile().stats
	return normalized

static func _safe_int(value: Variant, fallback: int) -> int:
	if value is int:
		return value
	if value is String and value.is_valid_int():
		return value.to_int()
	return fallback

static func _safe_difficulty(value: Variant) -> String:
	if value is String and ["simple", "medium", "hard"].has(value):
		return value
	return "medium"

static func _safe_volume(value: Variant, fallback: float) -> float:
	if (value is int or value is float) and is_finite(float(value)):
		return clampf(float(value), 0.0, 1.0)
	return fallback
