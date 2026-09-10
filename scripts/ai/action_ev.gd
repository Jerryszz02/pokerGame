class_name ActionEV
extends RefCounted
## One-response-round candidate action EV. This is an explicit approximation:
## after the hero acts, each remaining opponent folds or calls exactly once and
## the hand then checks down. It is NOT a full future-street solver and the EV
## is a heuristic expectation, never a claim of a proven best action.
##
## EV = expected eligible payout (from the layered pot) minus the hero's NEW
## incremental chips. Sunk contributions stay in the pot; folded money stays
## contestable; already all-in players have capped contributions; unmatched
## hero excess is refunded by the top pot layer; split pots are shared.
## Response folds use opponents' CURRENT-board made-hand strength, the price
## and the observed range/tendency -- never a future sampled board result.

const RESPONSE_HEURISTIC := "heuristic"
const RESPONSE_ALWAYS_CALL := "always_call"
const RESPONSE_ALWAYS_FOLD := "always_fold"
const MAX_WORLDS := 400

const ASSUMPTIONS := "one fold/call response round then checkdown; shared sampled worlds; EV = eligible payout - new incremental cost; sunk chips stay in pot; no future-street solver"

static func evaluate(game, player_index: int, profile: Dictionary = {}, opts: Dictionary = {}) -> Dictionary:
	var legal: Dictionary = game.get_legal_actions(player_index)
	var actions: Array = legal.actions
	if actions.is_empty():
		return {"candidates": [], "best": {}, "world_count": 0, "requested_world_count": world_count_for(profile, opts), "sampling_insufficient": true, "equity": 0.0, "assumptions": ASSUMPTIONS, "response_model": str(opts.get("response_model", RESPONSE_HEURISTIC))}
	var player: Dictionary = game.players[player_index]
	var hero_cards: Array = player.hole_cards
	var board: Array = game.community_cards
	var to_call := int(game.get_to_call(player_index))
	var pot := int(game.total_pot())
	var big_blind := maxf(1.0, float(game.big_blind))
	var response_model := str(opts.get("response_model", RESPONSE_HEURISTIC))
	var rng: RandomNumberGenerator = opts.get("rng") if opts.get("rng") is RandomNumberGenerator else _new_rng()
	var live_opponents := _live_opponents(game, player_index)

	var worlds: Array = opts.get("worlds", []) if opts.get("worlds", []) is Array else []
	if worlds.is_empty():
		worlds = _sample_worlds(game, player_index, profile, opts, rng)
	var prepared := _prepare_worlds(hero_cards, board, worlds, live_opponents.size())
	var response_rolls := _response_rolls(prepared.size(), live_opponents.size(), rng)

	var candidates := _build_candidates(game, player_index, legal, pot, to_call)
	var scored := []
	for candidate in candidates:
		scored.append(_score_candidate(game, player_index, candidate, worlds, prepared, live_opponents, response_rolls, response_model, rng, pot, big_blind, profile))
	var best: Dictionary = {}
	for candidate in scored:
		if best.is_empty() or float(candidate.ev) > float(best.ev):
			best = candidate
	var equity := MonteCarlo.evaluate_worlds(hero_cards, worlds)
	return {
		"candidates": scored,
		"best": best,
		"world_count": prepared.size(),
		"requested_world_count": world_count_for(profile, opts),
		"sampling_insufficient": prepared.size() < world_count_for(profile, opts),
		"equity": float(equity.equity),
		"win_rate": float(equity.win_rate),
		"tie_rate": float(equity.tie_rate),
		"assumptions": ASSUMPTIONS,
		"response_model": response_model,
		"pot": pot,
		"to_call": to_call
	}

# --- candidate construction --------------------------------------------------

static func _build_candidates(game, player_index: int, legal: Dictionary, pot: int, to_call: int) -> Array:
	var player: Dictionary = game.players[player_index]
	var actions: Array = legal.actions
	var candidates := []
	if to_call > 0 and actions.has(TableState.ACTION_FOLD):
		candidates.append({"action_type": TableState.ACTION_FOLD, "amount": 0, "label": "弃牌"})
	if to_call > 0 and actions.has(TableState.ACTION_CALL):
		candidates.append({"action_type": TableState.ACTION_CALL, "amount": 0, "label": "跟注"})
	elif to_call == 0 and actions.has(TableState.ACTION_CHECK):
		candidates.append({"action_type": TableState.ACTION_CHECK, "amount": 0, "label": "让牌"})
	if actions.has(TableState.ACTION_RAISE):
		var fractions := [1.0 / 3.0, 2.0 / 3.0, 1.0]
		var seen := {}
		for fraction in fractions:
			var target := int(round(float(player.current_bet + to_call) + float(pot + to_call) * fraction))
			target = clampi(target, int(legal.min_raise_to), int(legal.max_raise_to))
			if target <= int(game.current_bet) or seen.has(target):
				continue
			seen[target] = true
			candidates.append({"action_type": TableState.ACTION_RAISE, "amount": target, "label": "加注 %d" % target})
	if actions.has(TableState.ACTION_ALL_IN):
		var all_in_target := int(player.current_bet) + int(player.stack)
		# A short all-in that only calls is the same resulting investment as call;
		# an all-in matching an existing raise target is likewise not a new size.
		var duplicate_target := false
		for candidate in candidates:
			if str(candidate.get("action_type", "")) == TableState.ACTION_RAISE and int(candidate.get("amount", -1)) == all_in_target:
				duplicate_target = true
				break
		if not duplicate_target and not (to_call > 0 and int(player.stack) <= to_call and actions.has(TableState.ACTION_CALL)):
			candidates.append({"action_type": TableState.ACTION_ALL_IN, "amount": 0, "label": "全下"})
	return candidates

static func hero_cost(game, player_index: int, candidate: Dictionary) -> int:
	var player: Dictionary = game.players[player_index]
	var action := str(candidate.get("action_type", ""))
	match action:
		TableState.ACTION_FOLD:
			return 0
		TableState.ACTION_CHECK:
			return 0
		TableState.ACTION_CALL:
			return min(int(game.get_to_call(player_index)), int(player.stack))
		TableState.ACTION_RAISE:
			return max(0, int(candidate.get("amount", 0)) - int(player.current_bet))
		TableState.ACTION_ALL_IN:
			return int(player.stack)
	return 0

static func _score_candidate(game, player_index: int, candidate: Dictionary, _worlds: Array, prepared: Array, live_opponents: Array, response_rolls: Array, response_model: String, _rng: RandomNumberGenerator, pot: int, big_blind: float, profile: Dictionary) -> Dictionary:
	var action := str(candidate.get("action_type", ""))
	var player: Dictionary = game.players[player_index]
	var cost := hero_cost(game, player_index, candidate)
	var scored := candidate.duplicate(true)
	scored["cost"] = cost
	scored["is_aggressive"] = _hero_increased_bet(game, candidate, _action_target(game, player_index, candidate))
	if action == TableState.ACTION_FOLD or prepared.is_empty():
		scored["ev"] = 0.0
		scored["ev_bb"] = 0.0
		return scored

	var target := _action_target(game, player_index, candidate)
	var total := 0.0
	var fold_count := 0
	for world_index in range(prepared.size()):
		var world: Dictionary = prepared[world_index]
		var contributions := []
		var eligible := []
		for i in range(game.players.size()):
			contributions.append(int(game.players[i].total_bet))
			var status := str(game.players[i].status)
			eligible.append(status != TableState.STATUS_FOLDED and status != TableState.STATUS_OUT)
		contributions[player_index] += cost
		var pot_after := pot + cost
		for opponent_slot in range(live_opponents.size()):
			var opponent_index: int = live_opponents[opponent_slot]
			var opponent: Dictionary = game.players[opponent_index]
			var all_in := str(opponent.status) == TableState.STATUS_ALL_IN or int(opponent.stack) <= 0
			var extra: int = max(0, mini(target, int(opponent.current_bet) + int(opponent.stack)) - int(opponent.current_bet))
			var opponent_result: Dictionary = world.current_opponents[opponent_slot]
			var fold := false
			if not all_in and extra > 0:
				var price := 0.0
				if pot_after + extra > 0:
					price = float(extra) / float(pot_after + extra)
				fold = _opponent_folds(opponent_result, price, response_model, response_rolls[world_index][opponent_slot], profile)
			if fold:
				fold_count += 1
				eligible[opponent_index] = false
			else:
				contributions[opponent_index] += extra
				pot_after += extra
		var payout := compute_payout(contributions, eligible, _results_for_world(world, player_index, live_opponents, game), player_index)
		total += payout - float(cost)
	var ev := total / float(prepared.size())
	if is_nan(ev) or is_inf(ev):
		ev = 0.0
	scored["ev"] = ev
	scored["ev_bb"] = ev / big_blind
	scored["fold_rate"] = 0.0 if prepared.is_empty() else float(fold_count) / float(prepared.size() * maxi(1, live_opponents.size()))
	return scored

## Build the per-player result array needed by compute_payout from a world.
static func _results_for_world(world: Dictionary, hero_index: int, live_opponents: Array, game) -> Array:
	var results := []
	for i in range(game.players.size()):
		results.append({})
	results[hero_index] = world.hero
	for slot in range(live_opponents.size()):
		results[live_opponents[slot]] = world.opponents[slot]
	return results

## The bet level every opponent must match for this candidate.
static func _action_target(game, player_index: int, candidate: Dictionary) -> int:
	var player: Dictionary = game.players[player_index]
	var action := str(candidate.get("action_type", ""))
	if action == TableState.ACTION_RAISE:
		return int(candidate.get("amount", 0))
	if action == TableState.ACTION_ALL_IN:
		return maxi(int(game.current_bet), int(player.current_bet) + int(player.stack))
	return maxi(int(game.current_bet), int(player.current_bet))

static func _hero_increased_bet(game, candidate: Dictionary, target: int) -> bool:
	var action := str(candidate.get("action_type", ""))
	if action != TableState.ACTION_RAISE and action != TableState.ACTION_ALL_IN:
		return false
	return target > int(game.current_bet)

static func _opponent_folds(opponent_result: Dictionary, price: float, response_model: String, roll: float, _profile: Dictionary) -> bool:
	if response_model == RESPONSE_ALWAYS_FOLD:
		return true
	if response_model == RESPONSE_ALWAYS_CALL:
		return false
	var strength := hand_strength(opponent_result)
	var call_threshold := 0.30 + 0.55 * clampf(price, 0.0, 1.0)
	var p_call := _logistic((strength - call_threshold) * 5.0)
	p_call = clampf(p_call, 0.02, 0.98)
	return roll > p_call

## Normalized current-board made-hand strength (0..1) from the engine result.
static func hand_strength(result: Dictionary) -> float:
	if result.is_empty():
		return 0.0
	var rank_value := float(result.get("rank_value", -1))
	if rank_value < 0.0:
		return 0.0
	var strength := clampf(rank_value / 8.0, 0.0, 1.0) * 0.85
	var tiebreakers: Array = result.get("tiebreakers", [])
	if not tiebreakers.is_empty():
		strength += clampf(float(tiebreakers[0]) / 14.0, 0.0, 1.0) * 0.15
	return clampf(strength, 0.0, 1.0)

# --- pot math ----------------------------------------------------------------

## Expected hero payout from a layered pot. Contributions are total chips in
## the pot; eligible marks players who can win. Folded contributors keep their
## money in the pot but never receive a share.
static func compute_payout(contributions: Array, eligible: Array, results: Array, hero_index: int) -> float:
	if hero_index < 0 or hero_index >= contributions.size():
		return 0.0
	if hero_index >= eligible.size() or not bool(eligible[hero_index]):
		return 0.0
	var levels := []
	for value in contributions:
		var numeric := float(value)
		if numeric > 0.0 and not levels.has(numeric):
			levels.append(numeric)
	levels.sort()
	var previous := 0.0
	var payout := 0.0
	for level in levels:
		var amount := 0.0
		var pot_eligible := []
		for i in range(contributions.size()):
			if float(contributions[i]) >= float(level):
				amount += float(level) - previous
				if i < eligible.size() and bool(eligible[i]) and not pot_eligible.has(i):
					pot_eligible.append(i)
		previous = float(level)
		if amount <= 0.0 or pot_eligible.is_empty() or not pot_eligible.has(hero_index):
			continue
		var best := []
		for i in pot_eligible:
			if i >= results.size() or results[i].is_empty():
				continue
			if best.is_empty() or HandEvaluator.compare_results(results[i], results[best[0]]) > 0:
				best = [i]
			elif HandEvaluator.compare_results(results[i], results[best[0]]) == 0:
				best.append(i)
		if best.has(hero_index):
			payout += amount / float(best.size())
	return payout

# --- sampling helpers --------------------------------------------------------

static func _sample_worlds(game, player_index: int, profile: Dictionary, opts: Dictionary, rng: RandomNumberGenerator) -> Array:
	var hero_cards: Array = game.players[player_index].hole_cards
	var board: Array = game.community_cards
	var world_count := world_count_for(profile, opts)
	var history_detail := int(clampf(_finite_number(profile.get("history_detail"), 8.0), 0.0, 40.0))
	var history: Array = game.public_action_history
	var recent: Array = history.slice(maxi(0, history.size() - history_detail), history.size())
	var shared_combos := StartingHandTable.build_combo_table()
	var shared_features := {}
	var ranges := []
	for opponent_index in _live_opponents(game, player_index):
		var opponent_range := OpponentRange.new(hero_cards, board, shared_combos, shared_features)
		opponent_range.observe_history(recent, opponent_index, board)
		ranges.append(opponent_range)
	return MonteCarlo.sample_worlds(hero_cards, board, ranges, world_count, rng)

static func world_count_for(profile: Dictionary, opts: Dictionary = {}) -> int:
	if opts.has("world_count"):
		return int(clampf(_finite_number(opts.get("world_count"), 1.0), 1.0, float(MAX_WORLDS)))
	var configured := int(clampf(_finite_number(profile.get("simulation_count"), 0.0), 0.0, float(MAX_WORLDS)))
	if configured > 0:
		return clampi(configured, 1, MAX_WORLDS)
	var effort := int(_finite_number(profile.get("model_effort"), 1.0))
	return 120 if effort >= 2 else 60

static func _finite_number(value: Variant, fallback: float) -> float:
	if not (value is int or value is float):
		return fallback
	var numeric := float(value)
	return fallback if is_nan(numeric) or is_inf(numeric) else numeric

static func _prepare_worlds(hero_cards: Array, current_board: Array, worlds: Array, expected_opponents: int) -> Array:
	var prepared := []
	for raw_world in worlds:
		if not (raw_world is Dictionary):
			continue
		var world: Dictionary = raw_world
		var board: Array = world.get("board", [])
		var opponents: Array = world.get("opponents", [])
		if board.size() < 5 or opponents.size() != expected_opponents:
			continue
		var hero_result := HandEvaluator.evaluate(hero_cards + board)
		var opponent_results := []
		var current_opponent_results := []
		var board_is_complete := current_board.size() >= 5
		for cards in opponents:
			var showdown_result := HandEvaluator.evaluate(cards + board)
			opponent_results.append(showdown_result)
			# Response folding reads only the board as it stands right now,
			# never the sampled future runout.
			current_opponent_results.append(showdown_result if board_is_complete else HandEvaluator.evaluate(cards + current_board))
		prepared.append({
			"hero": hero_result,
			"opponents": opponent_results,
			"current_opponents": current_opponent_results
		})
	return prepared

static func _response_rolls(world_count: int, opponent_count: int, rng: RandomNumberGenerator) -> Array:
	var rolls := []
	for _world in range(world_count):
		var row := []
		for _opponent in range(opponent_count):
			row.append(rng.randf())
		rolls.append(row)
	return rolls

static func _live_opponents(game, player_index: int) -> Array:
	var indices := []
	var count: int = game.players.size()
	for offset in range(1, count):
		var i: int = (player_index + offset) % count
		var status := str(game.players[i].status)
		if status == TableState.STATUS_FOLDED or status == TableState.STATUS_OUT:
			continue
		indices.append(i)
	return indices

static func _logistic(x: float) -> float:
	return 1.0 / (1.0 + exp(-clampf(x, -30.0, 30.0)))

static func _new_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng
