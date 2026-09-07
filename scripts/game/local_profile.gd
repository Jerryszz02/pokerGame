class_name LocalProfile
extends RefCounted

const PROFILE_PATH := "user://poker_profile.cfg"

static func default_profile() -> Dictionary:
	return {
		"settings": {"ai_count": 3, "difficulty": "medium", "sound_enabled": true, "fast_mode": false},
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
	return normalize_profile(raw)

static func save_profile(profile: Dictionary, path: String = PROFILE_PATH) -> bool:
	var normalized := normalize_profile(profile)
	var config := ConfigFile.new()
	for section in normalized:
		for key in normalized[section]:
			config.set_value(section, key, normalized[section][key])
	# Preserve the last valid profile if writing the new file fails.
	var temporary := path + ".tmp"
	if config.save(temporary) != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) == OK

static func normalize_profile(profile: Dictionary) -> Dictionary:
	var normalized := default_profile()
	var settings: Variant = profile.get("settings", {})
	if settings is Dictionary:
		normalized.settings.ai_count = clampi(_safe_int(settings.get("ai_count"), 3), 1, 5)
		normalized.settings.difficulty = _safe_difficulty(settings.get("difficulty"))
		for key in ["sound_enabled", "fast_mode"]:
			if settings.get(key) is bool:
				normalized.settings[key] = settings[key]
	var stats: Variant = profile.get("stats", {})
	if stats is Dictionary:
		for key in normalized.stats:
			var value := _safe_int(stats.get(key), 0)
			normalized.stats[key] = value if key == "total_net_profit" else maxi(0, value)
	return normalized

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
