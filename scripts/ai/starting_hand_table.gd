class_name StartingHandTable
extends RefCounted
## Preflop entry point.
##
## `score`/`label` are the original compatibility API and are NOT calibrated
## equity. The 169-class range functions below are an explicit, documented
## heuristic: `class_strength` is a rank/connectivity ordering in 0..1, and
## action frequencies are context-conditioned tier adjustments. They are not
## win probabilities and must never be presented as such.

const LABEL_TO_RANK := {
	"2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9,
	"T": 10, "J": 11, "Q": 12, "K": 13, "A": 14
}

static func score(hole_cards: Array) -> int:
	if hole_cards.size() != 2:
		return 0
	var a: int = hole_cards[0].rank
	var b: int = hole_cards[1].rank
	var high: int = max(a, b)
	var low: int = min(a, b)
	var suited: bool = hole_cards[0].suit == hole_cards[1].suit
	var gap: int = high - low
	var value := 0

	if high == low:
		value = 45 + high * 4
	else:
		value = high * 4 + low * 2
		if high == 14:
			value += 12
		if suited:
			value += 8
		if gap == 1:
			value += 7
		elif gap == 2:
			value += 4
		elif gap >= 5:
			value -= 7
		if low <= 5 and high < 11:
			value -= 6
	return clampi(value, 1, 100)

static func label(hole_cards: Array) -> String:
	if hole_cards.size() != 2:
		return ""
	var a: int = hole_cards[0].rank
	var b: int = hole_cards[1].rank
	var high: int = max(a, b)
	var low: int = min(a, b)
	if high == low:
		return "%s%s" % [CardUtil.RANK_LABELS[high], CardUtil.RANK_LABELS[low]]
	var suffix := "s" if hole_cards[0].suit == hole_cards[1].suit else "o"
	return "%s%s%s" % [CardUtil.RANK_LABELS[high], CardUtil.RANK_LABELS[low], suffix]

# --- 169-class range representation -----------------------------------------

static func class_key(hole_cards: Array) -> String:
	return label(hole_cards)

static func class_info(key: String) -> Dictionary:
	if key.length() < 2 or key.length() > 3:
		return {}
	var high_label := key.substr(0, 1)
	var low_label := key.substr(1, 1)
	if not LABEL_TO_RANK.has(high_label) or not LABEL_TO_RANK.has(low_label):
		return {}
	var high: int = LABEL_TO_RANK[high_label]
	var low: int = LABEL_TO_RANK[low_label]
	if high < low:
		return {}
	var pair: bool = high == low
	var suited := false
	if key.length() == 3:
		if pair:
			return {}
		var suffix := key.substr(2, 1)
		if suffix == "s":
			suited = true
		elif suffix != "o":
			return {}
	return {
		"key": key, "high": high, "low": low, "pair": pair,
		"suited": suited, "offsuit": not pair and not suited
	}

static func all_class_keys() -> Array:
	var keys := []
	for rank in CardUtil.RANKS:
		var pair_label: String = CardUtil.RANK_LABELS[rank]
		keys.append(pair_label + pair_label)
	for high_index in range(CardUtil.RANKS.size()):
		for low_index in range(high_index):
			var high_label: String = CardUtil.RANK_LABELS[CardUtil.RANKS[high_index]]
			var low_label: String = CardUtil.RANK_LABELS[CardUtil.RANKS[low_index]]
			keys.append(high_label + low_label + "s")
			keys.append(high_label + low_label + "o")
	return keys

static func class_combos(key: String) -> Array:
	var info := class_info(key)
	if info.is_empty():
		return []
	var combos := []
	if info.pair:
		for i in range(CardUtil.SUITS.size()):
			for j in range(i + 1, CardUtil.SUITS.size()):
				combos.append([
					CardUtil.make_card(info.high, CardUtil.SUITS[i]),
					CardUtil.make_card(info.high, CardUtil.SUITS[j])
				])
		return combos
	for first_suit in CardUtil.SUITS:
		for second_suit in CardUtil.SUITS:
			if info.suited and first_suit != second_suit:
				continue
			if info.offsuit and first_suit == second_suit:
				continue
			combos.append([
				CardUtil.make_card(info.high, first_suit),
				CardUtil.make_card(info.low, second_suit)
			])
	return combos

## Immutable combo table shared by every opponent range built during a single
## decision so the 169-class combos are materialized once, not per opponent.
static func build_combo_table() -> Dictionary:
	var table := {}
	for key in all_class_keys():
		table[key] = class_combos(key)
	return table

## Deterministic rank/connectivity ordering in 0..1. Heuristic only; it is not
## an equity estimate and is intentionally independent of chips, position or
## opponent tendencies.
static func class_strength(key: String) -> float:
	var info := class_info(key)
	if info.is_empty():
		return 0.0
	var high: int = info.high
	var low: int = info.low
	var strength := 0.0
	if info.pair:
		strength = 0.58 + float(high - 2) * 0.035
	else:
		strength = float(high - 2) / 12.0 * 0.45 + float(low - 2) / 12.0 * 0.25
		if info.suited:
			strength += 0.06
		var gap: int = high - low
		if gap == 1:
			strength += 0.05
		elif gap == 2:
			strength += 0.03
		elif gap >= 5:
			strength -= 0.04
		if high == 14:
			strength += 0.05
	return clampf(strength, 0.05, 1.0)

static func class_tier(key: String) -> int:
	var strength := class_strength(key)
	var thresholds := [0.90, 0.80, 0.70, 0.62, 0.54, 0.46, 0.38, 0.28]
	for index in range(thresholds.size()):
		if strength >= thresholds[index]:
			return index + 1
	return 9

## Action frequencies for the class alone (context-free baseline).
static func frequencies(hole_cards: Array) -> Dictionary:
	return action_frequencies(hole_cards, {})

# --- context-conditioned frequencies ----------------------------------------

## Context keys (all optional, absolute chip amounts are never used):
##   relative_position 0 = earliest preflop actor, 1 = last to act
##   live_players      players still contesting the pot
##   raises_before     voluntary raises/all-in raises already made this hand
##   facing_bb         chips owed / big blind
##   effective_stack_bb effective stack / big blind
##   looseness, aggression  0..1 personality style fields
##   is_button, is_blind, closing_action, is_heads_up
static func action_frequencies(hole_cards: Array, context: Dictionary = {}) -> Dictionary:
	var key := class_key(hole_cards)
	if key.is_empty():
		return _empty_frequencies()
	var ctx := _context_defaults(context)
	var strength := class_strength(key)
	var effective := clampf(strength + _speculative_adjustment(key, ctx), 0.02, 1.0)

	var open_threshold := 0.40
	open_threshold -= 0.16 * float(ctx.relative_position)
	open_threshold -= 0.14 * (float(ctx.looseness) - 0.35)
	open_threshold += 0.018 * float(maxi(0, int(ctx.live_players) - 2))
	if bool(ctx.is_button):
		open_threshold -= 0.06
	if bool(ctx.is_heads_up):
		open_threshold -= 0.03
	var stack_bb: float = float(ctx.effective_stack_bb)
	if stack_bb < 30.0:
		open_threshold += (30.0 - stack_bb) / 30.0 * 0.10
	open_threshold = clampf(open_threshold, 0.06, 0.88)
	var open_frequency := _logistic((effective - open_threshold) * 9.0)

	# Facing a voluntary raise: bigger price and more raises tighten the range.
	var raise_pressure: float = float(ctx.raises_before)
	var call_threshold := 0.46 + 0.06 * raise_pressure
	call_threshold += 0.10 * minf(2.0, float(ctx.facing_bb) / 6.0)
	call_threshold -= 0.10 * (float(ctx.looseness) - 0.35)
	call_threshold -= 0.05 * float(ctx.relative_position)
	if bool(ctx.closing_action):
		call_threshold -= 0.04
	call_threshold = clampf(call_threshold, 0.05, 0.95)
	var continue_frequency := _logistic((effective - call_threshold) * 8.0)

	var reraise_threshold := 0.70 + 0.05 * raise_pressure - 0.12 * (float(ctx.aggression) - 0.5)
	if raise_pressure >= 2.0:
		reraise_threshold += 0.06
	reraise_threshold = clampf(reraise_threshold, 0.35, 0.95)
	var reraise_frequency := _logistic((effective - reraise_threshold) * 12.0)
	reraise_frequency *= 0.35 + 0.55 * float(ctx.aggression)
	if raise_pressure >= 2.0:
		reraise_frequency *= 0.6
	reraise_frequency = clampf(reraise_frequency, 0.0, continue_frequency)
	var call_frequency := maxf(0.0, continue_frequency - reraise_frequency)

	var result := {
		"class": key,
		"tier": class_tier(key),
		"strength": strength,
		"effective_strength": effective,
		"open_frequency": clampf(open_frequency, 0.0, 1.0),
		"continue_frequency": clampf(continue_frequency, 0.0, 1.0),
		"call_frequency": clampf(call_frequency, 0.0, 1.0),
		"reraise_frequency": clampf(reraise_frequency, 0.0, 1.0),
		"fold_frequency": clampf(1.0 - continue_frequency, 0.0, 1.0),
		"open_fold_frequency": clampf(1.0 - open_frequency, 0.0, 1.0),
		"context": ctx
	}
	return result

static func context_from_game(game, player_index: int, profile: Dictionary = {}) -> Dictionary:
	var player_count: int = game.players.size()
	if player_index < 0 or player_index >= player_count:
		return _context_defaults({})
	var big_blind: float = maxf(1.0, float(game.big_blind))
	var to_call: float = float(game.get_to_call(player_index))
	var raises_before := 0
	var history: Array = game.public_action_history
	for observation in history:
		if str(observation.get("street", "")) != TableState.STAGE_PREFLOP:
			continue
		var action := str(observation.get("action", ""))
		if (action == TableState.ACTION_RAISE or action == TableState.ACTION_ALL_IN) and bool(observation.get("increased_current_bet", false)):
			raises_before += 1

	var order := _preflop_order(game)
	var live := 0
	var surviving_seats := 0
	for idx in order:
		var seat_status := str(game.players[idx].status)
		if seat_status != TableState.STATUS_OUT:
			surviving_seats += 1
		if seat_status != TableState.STATUS_OUT and seat_status != TableState.STATUS_FOLDED:
			live += 1
	# Positional advantage follows postflop order: button is last, blinds first.
	# Keep this separate from the preflop action sequence and closing rights.
	var positional_order := []
	for offset in range(1, player_count + 1):
		var idx: int = (int(game.button_index) + offset) % player_count
		if str(game.players[idx].status) not in [TableState.STATUS_OUT, TableState.STATUS_FOLDED]:
			positional_order.append(idx)
	var position: int = positional_order.find(player_index)
	var relative_position := float(maxi(0, position)) / float(maxi(1, positional_order.size() - 1))

	var own_stack: float = float(game.players[player_index].stack)
	var largest_other := 0.0
	for i in range(player_count):
		if i == player_index:
			continue
		var status: String = str(game.players[i].status)
		if status == TableState.STATUS_FOLDED or status == TableState.STATUS_OUT:
			continue
		var other := float(game.players[i].stack) + float(game.players[i].current_bet)
		largest_other = maxf(largest_other, other)
	if largest_other <= 0.0:
		largest_other = own_stack + float(game.players[player_index].current_bet)
	var own_effective := own_stack + float(game.players[player_index].current_bet)
	# A single effective depth is a multiplayer approximation: use the deepest
	# live opponent while each EV calculation still uses actual stacks.
	var effective_stack_bb := minf(own_effective, largest_other) / big_blind
	# Folding down from a multiway deal is still a multiway preflop context;
	# eliminated seats represent an actual heads-up table.
	var heads_up := live == 2 and surviving_seats == 2
	var pending_after := false
	for after_idx in range(player_count):
		if after_idx == player_index:
			continue
		var after_status := str(game.players[after_idx].status)
		if after_status == TableState.STATUS_FOLDED or after_status == TableState.STATUS_OUT or after_status == TableState.STATUS_ALL_IN:
			continue
		if not bool(game.players[after_idx].has_acted) or int(game.players[after_idx].current_bet) < int(game.current_bet):
			pending_after = true
			break

	return _context_defaults({
		"relative_position": relative_position,
		"live_players": maxi(2, live),
		"raises_before": raises_before,
		"facing_bb": to_call / big_blind,
		"effective_stack_bb": effective_stack_bb,
		"looseness": profile.get("looseness", 0.35),
		"aggression": profile.get("aggression", 0.5),
		"is_button": player_index == int(game.button_index),
		"is_blind": player_index == game.small_blind_player_index or player_index == game.big_blind_player_index,
		"closing_action": not pending_after,
		"is_heads_up": heads_up
	})

static func _empty_frequencies() -> Dictionary:
	return {
		"class": "", "tier": 9, "strength": 0.0, "effective_strength": 0.0,
		"open_frequency": 0.0, "continue_frequency": 0.0, "call_frequency": 0.0,
		"reraise_frequency": 0.0, "fold_frequency": 1.0, "open_fold_frequency": 1.0,
		"context": _context_defaults({})
	}

static func _context_defaults(context: Dictionary) -> Dictionary:
	return {
		"relative_position": clampf(_finite(context.get("relative_position"), 0.5), 0.0, 1.0),
		"live_players": clampi(int(_finite(context.get("live_players"), 2.0)), 2, 10),
		"raises_before": maxi(0, int(_finite(context.get("raises_before"), 0.0))),
		"facing_bb": maxf(0.0, _finite(context.get("facing_bb"), 0.0)),
		"effective_stack_bb": clampf(_finite(context.get("effective_stack_bb"), 100.0), 1.0, 500.0),
		"looseness": clampf(_finite(context.get("looseness"), 0.35), 0.0, 1.0),
		"aggression": clampf(_finite(context.get("aggression"), 0.5), 0.0, 1.0),
		"is_button": bool(context.get("is_button", false)),
		"is_blind": bool(context.get("is_blind", false)),
		"closing_action": bool(context.get("closing_action", false)),
		"is_heads_up": bool(context.get("is_heads_up", false))
	}

static func _speculative_adjustment(key: String, ctx: Dictionary) -> float:
	var info := class_info(key)
	if info.is_empty():
		return 0.0
	var bonus := 0.0
	var stack_bb: float = float(ctx.effective_stack_bb)
	var deep := clampf((stack_bb - 40.0) / 120.0, -0.10, 0.10)
	var suited_connector: bool = info.suited and not info.pair and (info.high - info.low) <= 2
	var small_pair: bool = info.pair and info.high <= 8
	if suited_connector or small_pair:
		bonus += deep
		bonus += 0.06 * (float(ctx.looseness) - 0.35)
		if bool(ctx.is_blind) and bool(ctx.closing_action):
			bonus += 0.02
	if small_pair:
		bonus += clampf((stack_bb - 25.0) / 100.0, -0.06, 0.06)
	return bonus

static func _preflop_order(game) -> Array:
	var order := []
	var player_count: int = game.players.size()
	if player_count == 0:
		return order
	var start: int = (int(game.big_blind_player_index) + 1) % player_count
	for offset in range(player_count):
		var idx: int = (start + offset) % player_count
		if game.players[idx].status != TableState.STATUS_OUT:
			order.append(idx)
	return order

static func _logistic(x: float) -> float:
	return 1.0 / (1.0 + exp(-clampf(x, -30.0, 30.0)))

static func _finite(value: Variant, fallback: float) -> float:
	if value == null:
		return fallback
	if not (value is int or value is float):
		return fallback
	var number := float(value)
	if is_nan(number) or is_inf(number):
		return fallback
	return number
