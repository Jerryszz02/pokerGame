class_name LocalProfile
extends RefCounted

const PROFILE_PATH := "user://poker_profile.cfg"

static func default_profile() -> Dictionary:
	return {
		"settings": {
			"ai_count": 3,
			"difficulty": "medium",
			"sound_enabled": true,
			"music_enabled": false
		},
		"stats": {
			"total_hands": 0,
			"total_net_profit": 0,
			"total_win_hands": 0,
			"max_single_hand_win": 0
		}
	}

static func load_profile(path: String = PROFILE_PATH) -> Dictionary:
	var profile := default_profile()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return profile
	profile.settings.ai_count = clampi(int(config.get_value("settings", "ai_count", profile.settings.ai_count)), 1, 5)
	profile.settings.difficulty = _safe_difficulty(str(config.get_value("settings", "difficulty", profile.settings.difficulty)))
	profile.settings.sound_enabled = bool(config.get_value("settings", "sound_enabled", profile.settings.sound_enabled))
	profile.settings.music_enabled = bool(config.get_value("settings", "music_enabled", profile.settings.music_enabled))
	profile.stats.total_hands = maxi(0, int(config.get_value("stats", "total_hands", profile.stats.total_hands)))
	profile.stats.total_net_profit = int(config.get_value("stats", "total_net_profit", profile.stats.total_net_profit))
	profile.stats.total_win_hands = maxi(0, int(config.get_value("stats", "total_win_hands", profile.stats.total_win_hands)))
	profile.stats.max_single_hand_win = maxi(0, int(config.get_value("stats", "max_single_hand_win", profile.stats.max_single_hand_win)))
	return profile

static func save_profile(profile: Dictionary, path: String = PROFILE_PATH) -> bool:
	var normalized := normalize_profile(profile)
	var config := ConfigFile.new()
	config.set_value("settings", "ai_count", normalized.settings.ai_count)
	config.set_value("settings", "difficulty", normalized.settings.difficulty)
	config.set_value("settings", "sound_enabled", normalized.settings.sound_enabled)
	config.set_value("settings", "music_enabled", normalized.settings.music_enabled)
	config.set_value("stats", "total_hands", normalized.stats.total_hands)
	config.set_value("stats", "total_net_profit", normalized.stats.total_net_profit)
	config.set_value("stats", "total_win_hands", normalized.stats.total_win_hands)
	config.set_value("stats", "max_single_hand_win", normalized.stats.max_single_hand_win)
	return config.save(path) == OK

static func normalize_profile(profile: Dictionary) -> Dictionary:
	var normalized := default_profile()
	if profile.has("settings") and profile.settings is Dictionary:
		normalized.settings.ai_count = clampi(int(profile.settings.get("ai_count", normalized.settings.ai_count)), 1, 5)
		normalized.settings.difficulty = _safe_difficulty(str(profile.settings.get("difficulty", normalized.settings.difficulty)))
		normalized.settings.sound_enabled = bool(profile.settings.get("sound_enabled", normalized.settings.sound_enabled))
		normalized.settings.music_enabled = bool(profile.settings.get("music_enabled", normalized.settings.music_enabled))
	if profile.has("stats") and profile.stats is Dictionary:
		normalized.stats.total_hands = maxi(0, int(profile.stats.get("total_hands", normalized.stats.total_hands)))
		normalized.stats.total_net_profit = int(profile.stats.get("total_net_profit", normalized.stats.total_net_profit))
		normalized.stats.total_win_hands = maxi(0, int(profile.stats.get("total_win_hands", normalized.stats.total_win_hands)))
		normalized.stats.max_single_hand_win = maxi(0, int(profile.stats.get("max_single_hand_win", normalized.stats.max_single_hand_win)))
	return normalized

static func reset_stats(profile: Dictionary) -> Dictionary:
	var normalized := normalize_profile(profile)
	normalized.stats = default_profile().stats
	return normalized

static func _safe_difficulty(value: String) -> String:
	if ["simple", "medium", "hard"].has(value):
		return value
	return "medium"
