class_name PersonalityProfiles
extends RefCounted

const PROFILES = {
	"TightAggressive": {
		"name": "TightAggressive",
		"label": "Tight Aggressive",
		"aggression": 0.75,
		"looseness": 0.25,
		"bluff_rate": 0.08,
		"call_tolerance": 0.03,
		"simulation_count": 1500
	},
	"LooseAggressive": {
		"name": "LooseAggressive",
		"label": "Loose Aggressive",
		"aggression": 0.9,
		"looseness": 0.55,
		"bluff_rate": 0.16,
		"call_tolerance": 0.08,
		"simulation_count": 1500
	},
	"CallingStation": {
		"name": "CallingStation",
		"label": "Calling Station",
		"aggression": 0.25,
		"looseness": 0.65,
		"bluff_rate": 0.03,
		"call_tolerance": 0.18,
		"simulation_count": 1500
	},
	"Rock": {
		"name": "Rock",
		"label": "Rock",
		"aggression": 0.45,
		"looseness": 0.12,
		"bluff_rate": 0.02,
		"call_tolerance": -0.03,
		"simulation_count": 1500
	},
	"Balanced": {
		"name": "Balanced",
		"label": "Balanced",
		"aggression": 0.6,
		"looseness": 0.38,
		"bluff_rate": 0.1,
		"call_tolerance": 0.06,
		"simulation_count": 1500
	}
}

static func random_profile() -> Dictionary:
	var keys := PROFILES.keys()
	var key = keys[randi() % keys.size()]
	return PROFILES[key].duplicate(true)

static func default_profile() -> Dictionary:
	return PROFILES.Balanced.duplicate(true)
