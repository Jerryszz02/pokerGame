class_name OpponentRange
extends RefCounted
## Weighted legal two-card combinations for one opponent.
##
## Concrete combo posteriors are sampled directly; class_weights remains a
## compatibility prior. Hero and board cards are excluded.
## Weights start from a neutral, personality-agnostic prior and are updated
## from PUBLIC current-hand observations only. Checks/calls are deliberately
## weak evidence and every raise keeps a nonzero bluff component so the range
## never collapses to a single hand. This is a bounded heuristic, not a
## solver and not a claim of true opponent modelling.

const MIN_WEIGHT := 0.0001
const MAX_WEIGHT := 4.0

var class_weights: Dictionary = {}
## Combo posterior keyed by canonical card keys. class_weights remains a
## compatibility prior; sampling and observation use this posterior.
var combo_weights: Dictionary = {}
var observations_applied := 0
var _blocked: Dictionary = {}
var _combo_cache: Dictionary = {}
var _combo_by_key: Dictionary = {}
var _feature_cache: Dictionary = {}
var _distribution_combos: Array = []
var _distribution_masses: Array = []
var _distribution_total := 0.0
var _distribution_signature := ""

func _init(hero_cards: Array = [], board: Array = [], shared_combos: Dictionary = {}, shared_features: Dictionary = {}) -> void:
	_feature_cache = shared_features
	_build_cache(shared_combos)
	set_public_blockers(hero_cards, board)
	reset_to_neutral_prior()

func _build_cache(shared_combos: Dictionary) -> void:
	if shared_combos.is_empty():
		_combo_cache = {}
		for key in StartingHandTable.all_class_keys():
			var combos := StartingHandTable.class_combos(key)
			_combo_cache[key] = combos
	else:
		_combo_cache = shared_combos
	for key in _combo_cache:
		if not class_weights.has(key):
			class_weights[key] = 1.0
		for combo in _combo_cache[key]:
			var combo_key := _combo_key(combo)
			combo_weights[combo_key] = 1.0
			_combo_by_key[combo_key] = combo

## A neutral prior: every legal concrete combination equally likely, with no peeking at the
## opponent's assigned personality.
func reset_to_neutral_prior() -> void:
	for key in class_weights.keys():
		class_weights[key] = 1.0
	for key in combo_weights:
		combo_weights[key] = 1.0
	observations_applied = 0
	_rebuild_distribution()

func set_public_blockers(hero_cards: Array, board: Array) -> void:
	_blocked.clear()
	for card in hero_cards:
		_blocked[CardUtil.card_key(card)] = true
	for card in board:
		_blocked[CardUtil.card_key(card)] = true
	_rebuild_distribution()

func bump_blockers(cards: Array) -> void:
	for card in cards:
		_blocked[CardUtil.card_key(card)] = true
	_rebuild_distribution()

## Test/support API: replaces the concrete posterior without changing class priors.
## Missing combos get zero mass; callers must invoke this rather than mutating a
## cached distribution behind its back.
func set_combo_masses(masses: Dictionary) -> void:
	for combo_key in combo_weights:
		var value := _finite(masses.get(combo_key, 0.0), 0.0)
		combo_weights[combo_key] = maxf(0.0, value)
	_rebuild_distribution()

func is_blocked(card: Dictionary) -> bool:
	return _blocked.has(CardUtil.card_key(card))

## Exact combo weight (0 when blocked by hero/board or a shared card).
func combo_weight(card_a: Dictionary, card_b: Dictionary) -> float:
	if CardUtil.card_key(card_a) == CardUtil.card_key(card_b):
		return 0.0
	if is_blocked(card_a) or is_blocked(card_b):
		return 0.0
	var key := StartingHandTable.class_key([card_a, card_b])
	return maxf(0.0, float(combo_weights.get(_combo_key([card_a, card_b]), 0.0)) * float(class_weights.get(key, 0.0)))

func total_weight() -> float:
	_rebuild_distribution_if_needed()
	return _distribution_total

func is_empty() -> bool:
	return total_weight() <= MIN_WEIGHT

## Copy normalized to max weight 1 so callers can inspect relative support.
func normalized_weights() -> Dictionary:
	var sums := {}
	var peak := 0.0
	for key in class_weights:
		var sum := 0.0
		var legal_count := 0
		for combo in _combo_cache.get(key, []):
			if _is_blocked_combo(combo, {}):
				continue
			sum += maxf(0.0, float(combo_weights.get(_combo_key(combo), 0.0)) * float(class_weights.get(key, 0.0)))
			legal_count += 1
		sums[key] = sum / float(maxi(1, legal_count))
		peak = maxf(peak, float(sums[key]))
	var out := {}
	for key in class_weights:
		out[key] = 0.0 if peak <= 0.0 else maxf(0.0, float(sums.get(key, 0.0))) / peak
	return out

## Apply every public observation for `opponent_index` in chronological order
## against the board as it was at each action (no future-board hindsight).
func observe_history(history: Array, opponent_index: int, current_board: Array = []) -> void:
	bump_blockers(current_board)
	for observation in history:
		update_from_observation(observation, opponent_index)

## Multiply concrete posterior weights by a public-action likelihood. Returns true when
## an observation was applied.
func update_from_observation(observation: Variant, opponent_index: int) -> bool:
	if not (observation is Dictionary):
		return false
	var obs: Dictionary = observation
	if int(obs.get("actor", -1)) != opponent_index:
		return false
	var action := str(obs.get("action", ""))
	if not action in [TableState.ACTION_FOLD, TableState.ACTION_CHECK, TableState.ACTION_CALL, TableState.ACTION_RAISE, TableState.ACTION_ALL_IN]:
		return false
	var board: Array = obs.get("board_before", []) if obs.get("board_before", []) is Array else []
	for board_card in board:
		_blocked[CardUtil.card_key(board_card)] = true
	var big_blind: float = maxf(1.0, _finite(obs.get("big_blind"), 20.0))
	var all_in_call := action == TableState.ACTION_ALL_IN and (not bool(obs.get("increased_current_bet", false)) or bool(obs.get("is_all_in_call", false)))
	if action == TableState.ACTION_ALL_IN:
		action = TableState.ACTION_CALL if all_in_call else TableState.ACTION_RAISE
	var price_bb := 0.0
	if action == TableState.ACTION_RAISE:
		price_bb = _finite(obs.get("raise_to"), 0.0) / big_blind
	else:
		price_bb = _finite(obs.get("to_call_before"), 0.0) / big_blind
	if not board.is_empty() and action in [TableState.ACTION_CALL, TableState.ACTION_RAISE]:
		var paid := maxf(0.0, _finite(obs.get("paid"), _finite(obs.get("to_call_before"), 0.0)))
		var pot_before := maxf(0.0, _finite(obs.get("pot_before"), 0.0))
		price_bb = paid / maxf(1.0, pot_before + paid) * 12.0
	price_bb = clampf(price_bb, 0.0, 200.0)

	if action == TableState.ACTION_FOLD:
		for key in combo_weights:
			combo_weights[key] = maxf(MIN_WEIGHT, float(combo_weights[key]) * 0.02)
		observations_applied += 1
		_normalize()
		return true

	var value_scale := 1.0
	var bluff := 0.0
	var draw_scale := 1.0
	if action == TableState.ACTION_CHECK:
		value_scale = 0.9
		bluff = 0.0
		draw_scale = 0.4
	elif action == TableState.ACTION_CALL:
		value_scale = 1.0
		draw_scale = 0.8
	else:
		# Aggressive actions shift weight towards value and draws, but keep a
		# real bluff tail for all classes.
		value_scale = 1.0
		draw_scale = 1.0
		bluff = 0.12 + 0.04 * minf(4.0, price_bb)

	var board_keys := PackedStringArray()
	for card in board:
		board_keys.append(CardUtil.card_key(card))
	var board_key := ",".join(board_keys)
	if not _feature_cache.has(board_key):
		_feature_cache[board_key] = {}
	var features: Dictionary = _feature_cache[board_key]
	for combo_key in combo_weights:
		var combo: Array = _combo_by_key.get(combo_key, [])
		if combo.size() != 2 or _is_blocked_combo(combo, {}):
			continue
		var key := StartingHandTable.class_key(combo)
		# Postflop evidence is combo-specific, with a small preflop prior tie-break
		# so an overpair remains distinguishable from total air on dry boards.
		if not features.has(combo_key):
			features[combo_key] = [maxf(_combo_strength(combo, board), 0.45 * StartingHandTable.class_strength(key)), _combo_draw_potential(combo, board)]
		var strength: float = features[combo_key][0]
		var potential: float = features[combo_key][1]
		var factor := 0.9
		if action == TableState.ACTION_CHECK:
			# Checking is weak evidence: almost no shape change.
			factor = 0.95 + 0.10 * strength
		elif action == TableState.ACTION_CALL:
			# Cheap calls keep many hands; expensive calls lean to value/draws.
			var price_pressure := clampf(price_bb / 12.0, 0.0, 1.0)
			factor = 0.9 + 0.15 * strength + 0.35 * price_pressure * (0.4 * strength + 0.6 * potential)
		else:
			var value_term := pow(maxf(0.0, strength - 0.30), 1.3)
			value_term *= 1.2 + 0.5 * minf(3.0, price_bb / 4.0)
			factor = 0.35 + value_scale * value_term + draw_scale * potential + bluff
		factor = clampf(factor, 0.01, 6.0)
		combo_weights[combo_key] = clampf(float(combo_weights[combo_key]) * factor, MIN_WEIGHT, MAX_WEIGHT * 1000.0)
	observations_applied += 1
	_normalize()
	return true

## Weighted sample of one legal combo, avoiding `extra_blocked` (cards already
## used by hero/board or other sampled opponents).
func sample_combo(rng: RandomNumberGenerator, extra_blocked: Dictionary = {}) -> Array:
	_rebuild_distribution_if_needed()
	if _distribution_total > 0.0:
		for _retry in range(40):
			var picked := _distribution_index(rng.randf() * _distribution_total)
			var candidate: Array = _distribution_combos[picked]
			if not _is_blocked_combo(candidate, extra_blocked):
				return candidate
	var legal := []
	var masses := []
	var total := 0.0
	for key in combo_weights:
		var combo: Array = _combo_by_key.get(key, [])
		if combo.size() != 2 or _is_blocked_combo(combo, extra_blocked):
			continue
		var combo_class := StartingHandTable.class_key(combo)
		var weight := maxf(0.0, float(combo_weights[key]) * float(class_weights.get(combo_class, 0.0)))
		if weight <= 0.0:
			continue
		legal.append(combo)
		masses.append(weight)
		total += weight
	if total <= 0.0:
		# Neutral legal fallback, preserving the actual remaining-card space.
		for key in combo_weights:
			var combo: Array = _combo_by_key.get(key, [])
			if combo.size() == 2 and not _is_blocked_combo(combo, extra_blocked):
				legal.append(combo)
				masses.append(1.0)
				total += 1.0
	if total <= 0.0:
		return []
	var roll := rng.randf() * total
	var running := 0.0
	for i in range(legal.size()):
		running += masses[i]
		if roll <= running:
			return legal[i]
	return legal[legal.size() - 1]

func _normalize() -> void:
	var peak := 0.0
	for key in combo_weights:
		peak = maxf(peak, float(combo_weights[key]))
	if peak <= MIN_WEIGHT or is_nan(peak) or is_inf(peak):
		reset_to_neutral_prior()
		return
	for key in combo_weights:
		var normalized := float(combo_weights[key]) / peak
		if is_nan(normalized) or is_inf(normalized):
			normalized = MIN_WEIGHT
		combo_weights[key] = clampf(normalized, MIN_WEIGHT, 1.0)
	_rebuild_distribution()

func _rebuild_distribution() -> void:
	_distribution_combos.clear()
	_distribution_masses.clear()
	_distribution_total = 0.0
	for key in combo_weights:
		var combo: Array = _combo_by_key.get(key, [])
		if combo.size() != 2:
			continue
		if _is_blocked_combo(combo, {}):
			continue
		var class_key := StartingHandTable.class_key(combo)
		var mass := maxf(0.0, _finite(combo_weights[key], 0.0) * _finite(class_weights.get(class_key, 0.0), 0.0))
		if mass <= 0.0:
			continue
		_distribution_combos.append(combo)
		_distribution_total += mass
		_distribution_masses.append(_distribution_total)
	_distribution_signature = JSON.stringify(class_weights)

func _rebuild_distribution_if_needed() -> void:
	# Class priors are retained as a public compatibility dictionary. Comparing
	# only its compact 169-class signature avoids hashing every combo per draw.
	if JSON.stringify(class_weights) != _distribution_signature:
		_rebuild_distribution()

func _distribution_index(roll: float) -> int:
	var low := 0
	var high := _distribution_masses.size() - 1
	while low < high:
		var middle := (low + high) / 2
		if roll < float(_distribution_masses[middle]):
			high = middle
		else:
			low = middle + 1
	return low

func _combo_key(combo: Array) -> String:
	if combo.size() != 2:
		return ""
	var a := CardUtil.card_key(combo[0])
	var b := CardUtil.card_key(combo[1])
	var first := a if a < b else b
	var second := b if a < b else a
	return first + "|" + second

func _is_blocked_combo(combo: Array, extra_blocked: Dictionary) -> bool:
	return is_blocked(combo[0]) or is_blocked(combo[1]) or extra_blocked.has(CardUtil.card_key(combo[0])) or extra_blocked.has(CardUtil.card_key(combo[1]))

func _combo_strength(combo: Array, board: Array) -> float:
	if board.is_empty():
		return StartingHandTable.class_strength(StartingHandTable.class_key(combo))
	var result := HandEvaluator.evaluate(combo + board)
	return ActionEV.hand_strength(result)

func _combo_draw_potential(combo: Array, board: Array) -> float:
	if board.size() >= 5:
		return 0.0
	var potential := 0.0
	var suits := {}
	for card in combo + board:
		suits[card.suit] = int(suits.get(card.suit, 0)) + 1
	for suit in suits:
		if int(suits[suit]) >= 4:
			potential = maxf(potential, 0.28)
	var ranks := {}
	for card in combo + board:
		ranks[card.rank] = true
	for card in combo:
		for delta in range(-2, 3):
			if delta != 0 and ranks.has(card.rank + delta):
				potential += 0.04
	return clampf(potential, 0.0, 0.5)

static func _finite(value: Variant, fallback: float) -> float:
	if value == null:
		return fallback
	if not (value is int or value is float):
		return fallback
	var number := float(value)
	if is_nan(number) or is_inf(number):
		return fallback
	return number
