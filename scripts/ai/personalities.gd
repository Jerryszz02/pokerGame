class_name PersonalityProfiles
extends RefCounted
## Personality presets plus a safe normalization API.
##
## Style fields (aggression, looseness, bluff_rate, call_tolerance) describe
## how a seat plays. Difficulty owns model effort, history detail and action
## noise, so a seat is never made stronger merely by raising aggression and
## supplied/user-provided custom fields can never trigger unbounded work.

const DEFAULT_NAME := "Balanced"
const DIFFICULTIES := ["simple", "medium", "hard"]
const MAX_SIMULATIONS := 4000
const MAX_HISTORY := 40

const BASE_PROFILE := {
	"name": "Balanced",
	"label": "均衡",
	"difficulty": "medium",
	"aggression": 0.6,
	"looseness": 0.38,
	"bluff_rate": 0.10,
	"call_tolerance": 0.06,
	"simulation_count": 0,
	"action_noise": 0.06,
	"history_detail": 8,
	"model_effort": 1
}

const FIELD_SPECS := {
	"aggression": {"default": 0.6, "min": 0.0, "max": 1.0, "integer": false},
	"looseness": {"default": 0.38, "min": 0.0, "max": 1.0, "integer": false},
	"bluff_rate": {"default": 0.10, "min": 0.0, "max": 1.0, "integer": false},
	"call_tolerance": {"default": 0.06, "min": -0.5, "max": 0.5, "integer": false},
	"simulation_count": {"default": 0, "min": 0, "max": MAX_SIMULATIONS, "integer": true},
	"action_noise": {"default": 0.06, "min": 0.0, "max": 0.5, "integer": false},
	"history_detail": {"default": 8, "min": 0, "max": MAX_HISTORY, "integer": true},
	"model_effort": {"default": 1, "min": 0, "max": 2, "integer": true}
}

const PROFILES = {
	"TightAggressive": {
		"name": "TightAggressive",
		"label": "紧凶",
		"difficulty": "hard",
		"aggression": 0.75,
		"looseness": 0.25,
		"bluff_rate": 0.08,
		"call_tolerance": 0.03,
		"simulation_count": 1500,
		"action_noise": 0.05,
		"history_detail": 20,
		"model_effort": 2
	},
	"LooseAggressive": {
		"name": "LooseAggressive",
		"label": "松凶",
		"difficulty": "hard",
		"aggression": 0.9,
		"looseness": 0.55,
		"bluff_rate": 0.16,
		"call_tolerance": 0.08,
		"simulation_count": 1500,
		"action_noise": 0.05,
		"history_detail": 20,
		"model_effort": 2
	},
	"CallingStation": {
		"name": "CallingStation",
		"label": "跟注站",
		"difficulty": "hard",
		"aggression": 0.25,
		"looseness": 0.65,
		"bluff_rate": 0.03,
		"call_tolerance": 0.18,
		"simulation_count": 1500,
		"action_noise": 0.05,
		"history_detail": 20,
		"model_effort": 2
	},
	"Rock": {
		"name": "Rock",
		"label": "岩石",
		"difficulty": "hard",
		"aggression": 0.45,
		"looseness": 0.12,
		"bluff_rate": 0.02,
		"call_tolerance": -0.03,
		"simulation_count": 1500,
		"action_noise": 0.05,
		"history_detail": 20,
		"model_effort": 2
	},
	"Balanced": {
		"name": "Balanced",
		"label": "均衡",
		"difficulty": "hard",
		"aggression": 0.6,
		"looseness": 0.38,
		"bluff_rate": 0.1,
		"call_tolerance": 0.06,
		"simulation_count": 1500,
		"action_noise": 0.05,
		"history_detail": 20,
		"model_effort": 2
	}
}

static func random_profile() -> Dictionary:
	var keys := PROFILES.keys()
	var key = keys[randi() % keys.size()]
	return PROFILES[key].duplicate(true)

static func default_profile() -> Dictionary:
	return normalize_profile(PROFILES[DEFAULT_NAME])

## Look up a named preset and apply overrides. Unknown names fall back to the
## balanced preset; unknown keys and invalid/NaN/Inf values are dropped or
## clamped by `normalize_profile`.
static func get_profile(name: String, overrides: Dictionary = {}) -> Dictionary:
	var preset: Dictionary = BASE_PROFILE
	if PROFILES.has(name):
		preset = PROFILES[name]
	var merged := preset.duplicate(true)
	if overrides is Dictionary:
		for key in overrides:
			merged[key] = overrides[key]
	if not merged.has("name") or str(merged.get("name", "")).is_empty():
		merged["name"] = name
	return normalize_profile(merged)

## Returns a dictionary containing exactly the documented fields. Style fields
## are clamped to sane ranges; simulation/history/model effort are bounded so
## no caller can request unbounded simulation work.
static func normalize_profile(profile: Variant) -> Dictionary:
	var source: Dictionary = profile if profile is Dictionary else {}
	var fallback_difficulty := str(BASE_PROFILE.difficulty)
	var difficulty := _safe_difficulty(source.get("difficulty", fallback_difficulty))
	var name := _safe_text(source.get("name", BASE_PROFILE.name), BASE_PROFILE.name)
	var label := _safe_text(source.get("label", BASE_PROFILE.label), name)
	var normalized := {
		"name": name,
		"label": label,
		"difficulty": difficulty
	}
	for field in FIELD_SPECS.keys():
		var spec: Dictionary = FIELD_SPECS[field]
		normalized[field] = _safe_number(source.get(field), spec)
	return normalized

static func difficulty_defaults(difficulty: String) -> Dictionary:
	match _safe_difficulty(difficulty):
		"simple":
			return {"model_effort": 0, "history_detail": 0, "action_noise": 0.12, "simulation_count": 0}
		"hard":
			return {"model_effort": 2, "history_detail": 20, "action_noise": 0.05, "simulation_count": 320}
		_:
			return {"model_effort": 1, "history_detail": 10, "action_noise": 0.07, "simulation_count": 120}

## Style stays with the supplied profile; difficulty owns effort/noise.
static func apply_difficulty(profile: Dictionary, difficulty: String) -> Dictionary:
	var normalized := normalize_profile(profile)
	var resolved := _safe_difficulty(difficulty)
	normalized["difficulty"] = resolved
	var effort := difficulty_defaults(resolved)
	for key in effort:
		normalized[key] = effort[key]
	return normalize_profile(normalized)

static func _safe_number(value: Variant, spec: Dictionary) -> Variant:
	var fallback: float = float(spec.default)
	if value == null:
		return int(fallback) if bool(spec.integer) else fallback
	if not (value is int or value is float):
		return int(fallback) if bool(spec.integer) else fallback
	var number := float(value)
	if is_nan(number) or is_inf(number):
		return int(fallback) if bool(spec.integer) else fallback
	number = clampf(number, float(spec.min), float(spec.max))
	if bool(spec.integer):
		return int(round(number))
	return number

static func _safe_difficulty(value: Variant) -> String:
	if value is String and DIFFICULTIES.has(value):
		return value
	return "medium"

static func _safe_text(value: Variant, fallback: String) -> String:
	if value is String and not (value as String).is_empty():
		return value
	return fallback
