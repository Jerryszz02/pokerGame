class_name MatchConfig
extends RefCounted

const DEFAULTS := {"ai_count": 3, "difficulty": "medium", "initial_stack": 1000, "small_blind": 10, "big_blind": 20, "mode": "free", "show_hints": false, "pause_each_hand": true, "opponent_personality": "default"}
const STACKS := [1000, 2000, 5000, 10000]
const BLINDS := [[5, 10], [10, 20], [25, 50], [50, 100]]
## Whole-table opponent style. `default` preserves each difficulty's existing
## behavior and `random` draws per seat; the remaining IDs are the existing
## `PersonalityProfiles.PROFILES` presets. The field is additive: configurations
## saved before it existed normalize to `default` and stay valid.
const OPPONENT_PERSONALITY_DEFAULT := "default"
const OPPONENT_PERSONALITY_RANDOM := "random"
const OPPONENT_PERSONALITIES := ["default", "random", "TightAggressive", "LooseAggressive", "CallingStation", "Rock", "Balanced"]

static func normalize(raw: Dictionary) -> Dictionary:
	var out := DEFAULTS.duplicate(true)
	if _int_value(raw.get("ai_count", -1)) >= 1 and _int_value(raw.get("ai_count", -1)) <= 5: out.ai_count = _int_value(raw.ai_count)
	if ["simple", "medium", "hard"].has(str(raw.get("difficulty", ""))): out.difficulty = str(raw.difficulty)
	if STACKS.has(_int_value(raw.get("initial_stack", -1))): out.initial_stack = _int_value(raw.initial_stack)
	var pair := [_int_value(raw.get("small_blind", -1)), _int_value(raw.get("big_blind", -1))]
	if BLINDS.has(pair): out.small_blind = pair[0]; out.big_blind = pair[1]
	if ["free", "practice", "tutorial"].has(str(raw.get("mode", ""))): out.mode = str(raw.mode)
	for key in ["show_hints", "pause_each_hand"]:
		if raw.get(key) is bool: out[key] = raw[key]
	var raw_personality: Variant = raw.get("opponent_personality", null)
	if raw_personality is String and OPPONENT_PERSONALITIES.has(raw_personality): out.opponent_personality = raw_personality
	return out

static func validate(raw: Dictionary) -> bool:
	if not raw.has("ai_count") or not (raw.ai_count is int) or not (raw.ai_count >= 1 and raw.ai_count <= 5): return false
	if not ["simple", "medium", "hard"].has(str(raw.get("difficulty"))): return false
	if not raw.get("initial_stack") is int or not STACKS.has(raw.initial_stack): return false
	if not raw.get("small_blind") is int or not raw.get("big_blind") is int or not BLINDS.has([raw.small_blind, raw.big_blind]): return false
	if not ["free", "practice", "tutorial"].has(str(raw.get("mode"))): return false
	if raw.has("opponent_personality") and (not (raw.opponent_personality is String) or not OPPONENT_PERSONALITIES.has(raw.opponent_personality)): return false
	return raw.get("show_hints") is bool and raw.get("pause_each_hand") is bool

static func _int_value(value: Variant) -> int:
	if value is int: return value
	if value is float and is_finite(value) and value == floor(value): return int(value)
	if value is String and value.is_valid_int(): return value.to_int()
	return -1
