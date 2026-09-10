class_name PracticeStore
extends RefCounted
## Completed-hand files are immutable. The compact ledger retains cumulative
## results and deduplication keys even when a player deletes a replay file.

const VERSION := 1
const CAPACITY := 1000
const LESSONS := ["T1", "T2", "T3", "T4", "T5", "T6", "T7"]
var base_path := "user://poker_practice"
var state: Dictionary = {}
var notice := ""
var _write_locked := false
var _records: Dictionary = {}
var _disk_hand_count := 0

func _init(path: String = "user://poker_practice") -> void:
	base_path = path
	self.load()

func _empty_state() -> Dictionary:
	return {"version": VERSION, "tutorial_version": 1, "tutorial_completed": [], "achievements": {},
		"legacy_stats": {}, "legacy_migrated": false, "ledger": {}, "matches": {}}

func load() -> Dictionary:
	state = _empty_state()
	_records = {}
	_disk_hand_count = 0
	notice = ""
	_write_locked = false
	var path := base_path.path_join("profile.json")
	if FileAccess.file_exists(path):
		var parsed: Variant = _read_json(path)
		if not _valid_state(parsed):
			_write_locked = true
			notice = "练习资料损坏或版本较新，已保留原文件；当前只读。"
		else:
			state = parsed
	var dir := DirAccess.open(base_path)
	if dir == null:
		return state.duplicate(true)
	for filename in dir.get_files():
		if not filename.begins_with("hand_") or not filename.ends_with(".json"):
			continue
		_disk_hand_count += 1
		var record: Variant = _read_json(base_path.path_join(filename))
		if not _valid_record(record) or filename != "hand_%s.json" % str(record.get("id", "")):
			_add_notice("部分牌谱损坏或版本不兼容，已跳过并保留原文件。")
			continue
		_records[record.id] = record
		if not state.ledger.has(record.id) or not state.ledger[record.id].has("created_at"):
			state.ledger[record.id] = _ledger_entry(record)
			_unlock_hand(state, state.ledger[record.id])
	return state.duplicate(true)

func commit_hand(record: Dictionary) -> bool:
	if not _can_write():
		return false
	if not _valid_record(record) or str(record.config.mode) == "tutorial":
		notice = "牌谱格式无效或来自预设教程，未计入正常战绩。"
		return false
	var id: String = record.id
	# This also covers a manually deleted replay: it must not reappear on retry.
	if state.ledger.has(id):
		return _commit_state(state.duplicate(true))
	if _records.has(id):
		var recovered := state.duplicate(true)
		recovered.ledger[id] = _ledger_entry(_records[id])
		_unlock_hand(recovered, recovered.ledger[id])
		return _commit_state(recovered)
	if _disk_hand_count >= CAPACITY:
		notice = "牌谱已满 1000 手，请手动删除旧牌谱后重试；累计统计与成就保留。"
		return false
	if not _atomic_write(base_path.path_join("hand_%s.json" % id), record):
		return false
	_records[id] = record.duplicate(true)
	_disk_hand_count += 1
	var next := state.duplicate(true)
	next.ledger[id] = _ledger_entry(record)
	_unlock_hand(next, next.ledger[id])
	# Keep a durable hand available for retry even if the metadata write fails.
	if not _commit_state(next):
		return false
	return true

func records() -> Array:
	var result: Array = _records.values().duplicate(true)
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		if a.created_at == b.created_at:
			return int(a.hand_number) > int(b.hand_number)
		return str(a.created_at) > str(b.created_at))
	return result

func delete_record(id: String) -> bool:
	if not _can_write() or not _safe_id(id):
		return false
	if not state.ledger.has(id) and not _records.has(id):
		notice = "找不到这手有效牌谱。"
		return false
	# Metadata must be durable BEFORE removing the only full record.
	var next := state.duplicate(true)
	if not next.ledger.has(id):
		next.ledger[id] = _ledger_entry(_records[id])
	if not _commit_state(next):
		return false
	var path := base_path.path_join("hand_%s.json" % id)
	if FileAccess.file_exists(path):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
			notice = "牌谱删除失败，原文件与累计统计保留，可以重试。"
			return false
		_disk_hand_count = maxi(0, _disk_hand_count - 1)
	_records.erase(id)
	notice = "已删除牌谱；累计统计与成就保留。"
	return true

func complete_tutorial(id: String) -> bool:
	if not _can_write() or not LESSONS.has(id):
		return false
	var next := state.duplicate(true)
	next.tutorial_version = 1
	if not next.tutorial_completed.has(id):
		next.tutorial_completed.append(id)
	next.achievements.first_lesson = {"name": "完成第一课", "source": "教程"}
	if next.tutorial_completed.size() == LESSONS.size():
		next.achievements.all_lessons = {"name": "完成入门课程", "source": "教程"}
	return _commit_state(next)

func mark_replay_complete(id: String) -> bool:
	if not _can_write() or not _records.has(id):
		return false
	var next := state.duplicate(true)
	next.achievements.replay_first = {"name": "第一次完整回放", "source": "回放"}
	return _commit_state(next)

func finish_match(match_id: String, outcome: String, config: Dictionary = {}) -> bool:
	if not _can_write() or not _safe_id(match_id) or not ["won", "lost", "left"].has(outcome):
		return false
	if state.matches.has(match_id):
		return _commit_state(state.duplicate(true))
	var cfg := config.duplicate(true)
	var assisted := false
	for entry in state.ledger.values():
		if entry.match_id == match_id:
			cfg = entry.config.duplicate(true)
			assisted = assisted or entry.assistance_viewed
	if not MatchConfig.validate(cfg) or cfg.mode == "tutorial":
		notice = "整场配置不完整，未记入场次。"
		return false
	var next := state.duplicate(true)
	next.matches[match_id] = {"outcome": outcome, "config": cfg, "assistance_viewed": assisted, "created_at": Time.get_datetime_string_from_system(true)}
	return _commit_state(next)

func statistics(filters: Dictionary = {}) -> Dictionary:
	var out := {"hands": 0, "exclusive_win_hands": 0, "split_hands": 0, "loss_hands": 0,
		"positive_net_hands": 0, "net_bb": 0.0, "max_net_bb": 0.0, "net_profit": {},
		"showdown_wins": 0, "uncontested_wins": 0, "rank_counts": {}, "rank_win_counts": {},
		"rank_exclusive_counts": {}, "rank_split_counts": {}, "completed_matches": 0,
		"won_matches": 0, "lost_matches": 0, "left_matches": 0,
		"peak_stack": 0, "peak_entry_multiple": 0.0}
	for entry in state.ledger.values():
		if not _matches_filters(entry.config, entry.assistance_viewed, filters, str(entry.get("created_at", ""))):
			continue
		out.hands += 1
		var net: int = entry.net_change
		var bb: int = entry.config.big_blind
		var blind_group := "%d/%d" % [entry.config.small_blind, bb]
		out.net_profit[blind_group] = int(out.net_profit.get(blind_group, 0)) + net
		out.net_bb += float(net) / bb
		out.max_net_bb = maxf(out.max_net_bb, float(net) / bb)
		out.positive_net_hands += int(net > 0)
		out.exclusive_win_hands += int(entry.exclusive_win)
		out.split_hands += int(entry.split)
		out.loss_hands += int(not entry.exclusive_win and not entry.split)
		out.showdown_wins += int(entry.showdown_win)
		out.uncontested_wins += int(entry.uncontested_win)
		out.peak_stack = maxi(out.peak_stack, entry.peak_stack)
		out.peak_entry_multiple = maxf(out.peak_entry_multiple, float(entry.peak_stack) / int(entry.config.initial_stack))
		if int(entry.rank_value) >= 0:
			var rank_key := str(entry.rank_name)
			_increment(out.rank_counts, rank_key)
			if entry.showdown_win:
				_increment(out.rank_win_counts, rank_key)
			if entry.exclusive_win:
				_increment(out.rank_exclusive_counts, rank_key)
			if entry.split:
				_increment(out.rank_split_counts, rank_key)
	for entry in state.matches.values():
		if not _matches_filters(entry.config, entry.assistance_viewed, filters, str(entry.get("created_at", ""))):
			continue
		out["%s_matches" % entry.outcome] += 1
		if entry.outcome != "left":
			out.completed_matches += 1
	return out

func migrate_legacy(profile: Dictionary) -> Dictionary:
	if state.legacy_migrated:
		return state.legacy_stats.duplicate(true)
	if not _can_write() or bool(profile.get("read_only", false)):
		return state.legacy_stats.duplicate(true)
	var next := state.duplicate(true)
	next.legacy_stats = LocalProfile.normalize_profile(profile).stats.duplicate(true)
	next.legacy_migrated = true
	_commit_state(next)
	return state.legacy_stats.duplicate(true)

func _ledger_entry(record: Dictionary) -> Dictionary:
	return {"id": record.id, "match_id": record.match_id, "created_at": record.created_at, "config": record.config.duplicate(true),
		"assistance_viewed": record.assistance_viewed, "net_change": record.net_change,
		"split": record.split, "exclusive_win": record.exclusive_win,
		"showdown_win": record.showdown_win, "uncontested_win": record.uncontested_win,
		"rank_value": record.rank_value, "rank_name": record.rank_name, "peak_stack": record.peak_stack}

func _unlock_hand(next: Dictionary, entry: Dictionary) -> void:
	var source := "辅助练习" if entry.assistance_viewed else "独立对局"
	var suffix := "_assisted" if entry.assistance_viewed else "_independent"
	var rank_awards := {HandEvaluator.FULL_HOUSE: ["full_house", "首次形成葫芦"],
		HandEvaluator.FOUR_KIND: ["four_kind", "首次形成四条"],
		HandEvaluator.STRAIGHT_FLUSH: ["straight_flush", "首次形成同花顺"]}
	if rank_awards.has(entry.rank_value):
		var award: Array = rank_awards[entry.rank_value]
		next.achievements[award[0] + suffix] = {"name": award[1], "source": source}
	if int(entry.peak_stack) >= 2 * int(entry.config.initial_stack):
		next.achievements["stack_double" + suffix] = {"name": "筹码达到入场两倍", "source": source}

func _matches_filters(config: Dictionary, assisted: bool, filters: Dictionary, created_at: String = "") -> bool:
	if filters.has("days"):
		var cutoff := Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) - int(filters.days) * 86400)
		if created_at.is_empty() or created_at < cutoff: return false
	if filters.has("since") and (created_at.is_empty() or created_at < str(filters.since)): return false
	if filters.has("until") and (created_at.is_empty() or created_at > str(filters.until)): return false
	if config.mode == "tutorial":
		return false
	for key in ["mode", "difficulty", "ai_count", "initial_stack"]:
		if filters.has(key) and filters[key] != config[key]:
			return false
	for key in ["assistance", "assistance_viewed"]:
		if filters.has(key) and filters[key] != assisted:
			return false
	if filters.has("depth") and not is_equal_approx(float(filters.depth), float(config.initial_stack) / int(config.big_blind)):
		return false
	return true

func _increment(target: Dictionary, key: String) -> void:
	target[key] = int(target.get(key, 0)) + 1

func _can_write() -> bool:
	if _write_locked:
		notice = "练习资料损坏或版本较新，当前只读，原文件未覆盖。"
		return false
	return true

func _commit_state(next: Dictionary) -> bool:
	if not _can_write() or not _atomic_write(base_path.path_join("profile.json"), next):
		return false
	state = next
	notice = ""
	return true

func _atomic_write(path: String, value: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_path)) != OK:
		notice = "保存目录不可写，请修复目录后重试；本次数据尚未保存。"
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		notice = "写入失败，可以重试；原存档保留。"
		return false
	file.store_string(JSON.stringify(value))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK:
		notice = "保存失败，可以重试；原存档保留。"
		return false
	return true

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return _integer_json(parser.data)

func _integer_json(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	if value is Dictionary:
		for key in value:
			value[key] = _integer_json(value[key])
	elif value is Array:
		for i in range(value.size()):
			value[i] = _integer_json(value[i])
	return value

func _safe_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 100:
		return false
	for letter in value:
		if not (letter >= "a" and letter <= "z") and not (letter >= "A" and letter <= "Z") and not (letter >= "0" and letter <= "9") and letter != "-" and letter != "_":
			return false
	return true

func _valid_state(value: Variant) -> bool:
	if not value is Dictionary or not value.get("version") is int or value.version != VERSION:
		return false
	if not value.get("tutorial_version", 1) is int or value.get("tutorial_version", 1) != 1: return false
	for key in ["achievements", "legacy_stats", "ledger", "matches"]:
		if not value.get(key) is Dictionary:
			return false
	if not value.get("tutorial_completed") is Array or not value.get("legacy_migrated") is bool:
		return false
	for amount in value.legacy_stats.values():
		if not amount is int: return false
	var unique_lessons := {}
	for id in value.tutorial_completed:
		if not LESSONS.has(id) or unique_lessons.has(id):
			return false
		unique_lessons[id] = true
	for id in value.ledger:
		if not _safe_id(id) or not _valid_ledger(value.ledger[id]) or value.ledger[id].id != id:
			return false
	for id in value.matches:
		var entry: Variant = value.matches[id]
		if not _safe_id(id) or not entry is Dictionary or not ["won", "lost", "left"].has(entry.get("outcome")):
			return false
		if not entry.get("config") is Dictionary or not MatchConfig.validate(entry.config) or not entry.get("assistance_viewed") is bool:
			return false
	return true

func _valid_ledger(value: Variant) -> bool:
	if not value is Dictionary or not _safe_id(value.get("id")) or not _safe_id(value.get("match_id")):
		return false
	if not value.get("config") is Dictionary or not MatchConfig.validate(value.config):
		return false
	for key in ["assistance_viewed", "split", "exclusive_win", "showdown_win", "uncontested_win"]:
		if not value.get(key) is bool:
			return false
	for key in ["net_change", "rank_value", "peak_stack"]:
		if not value.get(key) is int:
			return false
	return value.get("rank_name") is String

func _valid_record(value: Variant) -> bool:
	if not _valid_ledger(value) or not value.get("schema_version") is int or value.schema_version != VERSION:
		return false
	if not value.get("frames") is Array or value.frames.is_empty() or not value.get("hand_number") is int or value.hand_number < 1:
		return false
	if not value.get("created_at") is String or not value.get("net_changes") is Dictionary or not value.get("starting_stacks") is Array:
		return false
	var count: int = value.config.ai_count + 1
	if value.starting_stacks.size() != count:
		return false
	for frame in value.frames:
		if not frame is Dictionary or not frame.get("players") is Array or frame.players.size() != count:
			return false
		if not frame.get("community_cards") is Array or not _valid_cards(frame.community_cards) or frame.community_cards.size() > 5:
			return false
		if not frame.get("stage") is String or not frame.get("label") is String or not frame.get("type") is String:
			return false
		for key in ["pot", "current_bet", "min_raise", "button_index", "small_blind_player_index", "big_blind_player_index", "current_player_index"]:
			if not frame.get(key) is int: return false
		if not frame.get("winners") is Array or not frame.get("side_pots") is Array: return false
		for player in frame.players:
			if not player is Dictionary or not player.get("hole_cards") is Array or not _valid_cards(player.hole_cards) or player.hole_cards.size() > 2:
				return false
			if not player.get("name") is String or not player.get("status") is String or not player.get("hand_result") is Dictionary:
				return false
			for key in ["stack", "current_bet", "total_bet"]:
				if not player.get(key) is int or player[key] < 0:
					return false
	for key in ["refunds", "pots", "winners"]:
		if not value.get(key) is Array: return false
	for refund in value.refunds:
		if not refund is Dictionary or not refund.get("player_index") is int or refund.player_index < 0 or refund.player_index >= count or not refund.get("amount") is int: return false
	for pot in value.pots:
		if not pot is Dictionary or not pot.get("amount") is int or not pot.get("payouts") is Array: return false
		for payout in pot.payouts:
			if not payout is Dictionary or not payout.get("player_index") is int or payout.player_index < 0 or payout.player_index >= count or not payout.get("amount") is int: return false
	return value.frames.back().stage == TableState.STAGE_HAND_OVER

func _valid_cards(cards: Array) -> bool:
	for card in cards:
		if not card is Dictionary or not card.get("rank") is int or card.rank < 2 or card.rank > 14 or not ["S", "H", "D", "C"].has(card.get("suit")):
			return false
	return true

func _add_notice(message: String) -> void:
	if not notice.contains(message):
		notice += ("\n" if not notice.is_empty() else "") + message

func reset_legacy() -> bool:
	var next := state.duplicate(true)
	next.legacy_stats = LocalProfile.default_profile().stats.duplicate(true)
	next.legacy_migrated = true
	return _commit_state(next)
