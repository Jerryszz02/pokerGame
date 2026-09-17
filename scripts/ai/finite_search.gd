class_name FiniteSearch
extends RefCounted
## Bounded finite-depth rollout evaluator for root candidate actions.
##
## Every candidate is scored on the SAME shared joint OpponentRange samples.
## After the root action the hand advances through real PokerRound.apply_action
## calls: future streets are dealt only as the engine advances them and every
## actor is played by a cheap fixed neutral stochastic policy that reads only
## that actor's own hole cards and the public table state. Opponent hole cards
## are never read by the policy; folded seats' real cards are never copied in.
##
## This is a heuristic finite-depth expectation, NOT a solver: there is no
## GTO/ISMCTS/optimality claim, only a bounded paired-world comparison.
##
## Decision value: hero final stack minus the hero's stack at the decision
## point. Sunk contributions already in the pot stay in the pot; unmatched
## refunds, all-in caps and split pots follow PokerRound's existing rules.
##
## World/depth counts are capped; the time deadline is cooperative between
## bounded work units. A candidate
## batch is only compared over complete worlds, so partial worlds are dropped
## rather than biasing one action. All randomness is a local RNG.

const MODEL := "finite_search"
const VERSION := CoachContext.VERSION
const MAX_WORLDS := 64
const MAX_DEPTH := 24
const DEFAULT_WORLDS := 24
const DEFAULT_DEPTH := 8
const DEFAULT_TIME_BUDGET_MS := 600

const ASSUMPTIONS := "bounded finite-depth shared-world rollout; each actor sees only its own cards and public state; neutral stochastic policy; EV = hero final stack - hero stack at the decision point (sunk chips stay in pot); side pots/refunds/splits follow PokerRound rules; heuristic, not optimal"
const CUTOFF_ASSUMPTION := "at the decision-depth cutoff the remaining actors check or call to showdown with no further raises; the sampled runout is revealed street by street through the engine"

static func evaluate(game, player_index: int, opts: Dictionary = {}) -> Dictionary:
	var start_ms := Time.get_ticks_msec()
	if game == null or player_index < 0 or player_index >= game.players.size():
		return _unavailable("bad_player", start_ms)
	if int(game.current_player_index) != player_index:
		return _unavailable("not_current_actor", start_ms)
	var legal: Dictionary = game.get_legal_actions(player_index)
	if legal.actions.is_empty():
		return _unavailable("no_legal_actions", start_ms)
	var hero_cards: Array = game.players[player_index].hole_cards
	if hero_cards.size() != 2:
		return _unavailable("no_hero_cards", start_ms)
	var live_opponents := _live_opponents(game, player_index)
	if live_opponents.is_empty():
		return _unavailable("no_opponents", start_ms)
	var cancellation = opts.get("cancellation", null)
	if _is_cancelled(cancellation):
		return _unavailable("cancelled", start_ms)

	var max_worlds := clampi(_int_opt(opts, "max_worlds", DEFAULT_WORLDS), 1, MAX_WORLDS)
	var max_depth := clampi(_int_opt(opts, "max_depth", DEFAULT_DEPTH), 1, MAX_DEPTH)
	var time_budget := clampi(_int_opt(opts, "time_budget_ms", DEFAULT_TIME_BUDGET_MS), 1, 60000)
	var deadline := start_ms + time_budget
	var rng := _rng_for(opts)

	var explicit_worlds: Variant = opts.get("worlds", [])
	var worlds: Array = []
	if explicit_worlds is Array and not (explicit_worlds as Array).is_empty():
		worlds = _normalize_worlds(explicit_worlds, live_opponents.size(), hero_cards, game.community_cards)
		if worlds.size() > max_worlds:
			worlds = worlds.slice(0, max_worlds)
	else:
		worlds = sample_worlds(game, player_index, max_worlds, rng)
	if worlds.is_empty():
		return _unavailable("no_worlds", start_ms)

	var actual_raw: Variant = opts.get("actual_action", {})
	var candidates := _build_candidates(game, player_index, legal, actual_raw)
	if candidates.is_empty():
		return _unavailable("no_candidates", start_ms)

	var values := []
	for _ci in range(candidates.size()):
		values.append([])
	var depth_reached := 0
	var cutoff_used := false
	var completed := 0
	var timed_out := false

	for wi in range(worlds.size()):
		if _is_cancelled(cancellation):
			return _unavailable("cancelled", start_ms)
		if Time.get_ticks_msec() > deadline:
			timed_out = true
			break
		var world: Dictionary = worlds[wi]
		var row := []
		var failed := false
		for ci in range(candidates.size()):
			var simulation := _simulate(game, player_index, candidates[ci], world, live_opponents, max_depth, rng, deadline, cancellation)
			if bool(simulation.get("cancelled", false)):
				return _unavailable("cancelled", start_ms)
			if not bool(simulation.get("ok", false)):
				timed_out = bool(simulation.get("timed_out", false))
				failed = true
				break
			row.append(float(simulation.get("value", 0.0)))
			depth_reached = maxi(depth_reached, int(simulation.get("decisions", 0)))
			cutoff_used = cutoff_used or bool(simulation.get("cutoff", false))
		if failed:
			break
		for ci in range(candidates.size()):
			values[ci].append(row[ci])
		completed += 1

	if _is_cancelled(cancellation):
		return _unavailable("cancelled", start_ms)
	if completed == 0:
		return _unavailable("time_budget" if timed_out else "no_worlds", start_ms)

	var scored := []
	for ci in range(candidates.size()):
		scored.append(_score(candidates[ci], values[ci], float(game.big_blind)))
	var best: Dictionary = {}
	for candidate in scored:
		if best.is_empty() or float(candidate.ev) > float(best.ev):
			best = candidate

	var completed_worlds: Array = worlds.slice(0, completed)
	var equity := MonteCarlo.evaluate_worlds(hero_cards, completed_worlds)
	var pot := int(game.total_pot())
	var to_call := mini(int(game.get_to_call(player_index)), int(game.players[player_index].stack))
	var pot_odds := 0.0
	if to_call > 0:
		pot_odds = float(to_call) / float(maxi(1, pot + to_call))

	return {
		"available": true,
		"reason": "",
		"version": VERSION,
		"model": MODEL,
		"equity": float(equity.equity),
		"win_rate": float(equity.win_rate),
		"tie_rate": float(equity.tie_rate),
		"tie_probability": float(equity.tie_probability),
		"world_count": completed,
		"uncertainty_available": completed >= 2,
		"requested_world_count": worlds.size(),
		"candidates": scored,
		"best": best,
		"depth_reached": depth_reached,
		"max_depth": max_depth,
		"cutoff_used": cutoff_used,
		"cutoff_assumption": CUTOFF_ASSUMPTION,
		"assumptions": ASSUMPTIONS,
		"timed_out": timed_out,
		"cancelled": false,
		"elapsed_ms": Time.get_ticks_msec() - start_ms,
		"pot": pot,
		"to_call": to_call,
		"pot_odds": pot_odds
	}

# --- public helpers ----------------------------------------------------------

## Shared joint OpponentRange samples reused by every candidate. The ranges use
## a neutral prior and public history only; seat difficulty/personality never
## enters the sampling.
static func sample_worlds(game, player_index: int, count: int, rng: RandomNumberGenerator) -> Array:
	if game == null or player_index < 0 or player_index >= game.players.size():
		return []
	var ranges := opponent_ranges(game, player_index)
	return MonteCarlo.sample_worlds(game.players[player_index].hole_cards, game.community_cards, ranges, clampi(count, 1, MAX_WORLDS), rng)

static func opponent_ranges(game, player_index: int) -> Array:
	var hero_cards: Array = game.players[player_index].hole_cards
	var board: Array = game.community_cards
	var shared_combos := StartingHandTable.build_combo_table()
	var shared_features := {}
	var ranges := []
	for opponent_index in _live_opponents(game, player_index):
		var opponent_range := OpponentRange.new(hero_cards, board, shared_combos, shared_features)
		opponent_range.observe_history(game.public_action_history, opponent_index, board)
		ranges.append(opponent_range)
	return ranges

## Normalize/validate a caller-supplied action. Returns {} when the action is
## not legal for the seat; a raise keeps its exact raise-to size and an all-in
## is normalized to its reachable target. The caller is never silently given a
## different move.
static func normalize_actual(game, player_index: int, actual: Variant) -> Dictionary:
	if not (actual is Dictionary) or game == null:
		return {}
	if player_index < 0 or player_index >= game.players.size():
		return {}
	var source: Dictionary = actual
	var action := str(source.get("action_type", ""))
	if action.is_empty():
		return {}
	var legal: Dictionary = game.get_legal_actions(player_index)
	if not legal.actions.has(action):
		return {}
	var amount := 0
	if action == TableState.ACTION_RAISE:
		amount = _int_opt(source, "amount", -1)
		if amount < int(legal.min_raise_to) or amount > int(legal.max_raise_to):
			return {}
	elif action == TableState.ACTION_ALL_IN:
		var player: Dictionary = game.players[player_index]
		amount = int(player.current_bet) + int(player.stack)
	return {"action_type": action, "amount": amount, "legal": true}

# --- candidates --------------------------------------------------------------

static func _build_candidates(game, player_index: int, legal: Dictionary, actual: Variant) -> Array:
	var player: Dictionary = game.players[player_index]
	var actions: Array = legal.actions
	var to_call := int(game.get_to_call(player_index))
	var pot := int(game.total_pot())
	var current_bet := int(game.current_bet)
	var candidates := []
	var seen := {}
	if to_call > 0 and actions.has(TableState.ACTION_FOLD):
		_append_unique(candidates, seen, {"action_type": TableState.ACTION_FOLD, "amount": 0, "label": "弃牌", "is_aggressive": false})
	if to_call > 0 and actions.has(TableState.ACTION_CALL):
		_append_unique(candidates, seen, {"action_type": TableState.ACTION_CALL, "amount": 0, "label": "跟注", "is_aggressive": false})
	elif to_call == 0 and actions.has(TableState.ACTION_CHECK):
		_append_unique(candidates, seen, {"action_type": TableState.ACTION_CHECK, "amount": 0, "label": "让牌", "is_aggressive": false})
	if actions.has(TableState.ACTION_RAISE):
		for fraction in [1.0 / 3.0, 2.0 / 3.0, 1.0]:
			var target := int(round(float(player.current_bet + to_call) + float(pot + to_call) * fraction))
			target = clampi(target, int(legal.min_raise_to), int(legal.max_raise_to))
			if target <= current_bet:
				continue
			_append_unique(candidates, seen, {
				"action_type": TableState.ACTION_RAISE, "amount": target,
				"label": "加注 %d" % target, "is_aggressive": target > current_bet
			})
	if actions.has(TableState.ACTION_ALL_IN):
		var all_in_target := int(player.current_bet) + int(player.stack)
		var is_aggressive := all_in_target > current_bet
		if not (not is_aggressive and actions.has(TableState.ACTION_CALL)):
			_append_unique(candidates, seen, {
				"action_type": TableState.ACTION_ALL_IN, "amount": all_in_target,
				"label": "全下", "is_aggressive": is_aggressive
			})
	var normalized := normalize_actual(game, player_index, actual)
	if not normalized.is_empty():
		var candidate := {
			"action_type": str(normalized.action_type),
			"amount": int(normalized.amount),
			"label": "实际行动",
			"is_aggressive": str(normalized.action_type) == TableState.ACTION_RAISE or (str(normalized.action_type) == TableState.ACTION_ALL_IN and int(normalized.amount) > current_bet)
		}
		_append_unique(candidates, seen, candidate)
	return candidates

static func _append_unique(candidates: Array, seen: Dictionary, candidate: Dictionary) -> void:
	var key := "%s:%d" % [str(candidate.get("action_type", "")), int(candidate.get("amount", 0))]
	if candidate.get("action_type", "") in [TableState.ACTION_FOLD, TableState.ACTION_CHECK, TableState.ACTION_CALL, TableState.ACTION_ALL_IN]:
		key = str(candidate.get("action_type", ""))
	if seen.has(key):
		return
	seen[key] = true
	candidates.append(candidate)

# --- rollout -----------------------------------------------------------------

static func _simulate(game, player_index: int, candidate: Dictionary, world: Dictionary, live_opponents: Array, max_depth: int, rng: RandomNumberGenerator, deadline: int, cancellation) -> Dictionary:
	var simulation = _clone_root(game, player_index, world, live_opponents)
	if simulation == null:
		return {"ok": false}
	var hero_before: int = int(simulation.players[player_index].stack)
	if not simulation.apply_action(str(candidate.get("action_type", "")), int(candidate.get("amount", 0))):
		return {"ok": false}
	var decisions := 0
	var cutoff := false
	while simulation.stage != TableState.STAGE_HAND_OVER and decisions < max_depth:
		if _is_cancelled(cancellation):
			return {"ok": false, "cancelled": true}
		if Time.get_ticks_msec() > deadline:
			return {"ok": false, "timed_out": true}
		var actor: int = int(simulation.current_player_index)
		if actor < 0:
			break
		var move := _rollout_action(simulation, actor, rng)
		if move.is_empty():
			break
		if not simulation.apply_action(str(move.action_type), int(move.amount)):
			break
		decisions += 1
	if simulation.stage != TableState.STAGE_HAND_OVER:
		cutoff = true
		_check_call_to_showdown(simulation, cancellation)
	if _is_cancelled(cancellation):
		return {"ok": false, "cancelled": true}
	if Time.get_ticks_msec() > deadline:
		return {"ok": false, "timed_out": true}
	if simulation.stage != TableState.STAGE_HAND_OVER:
		return {"ok": false}
	var final_stack: int = int(simulation.players[player_index].stack)
	return {
		"ok": true,
		"value": final_stack - hero_before,
		"decisions": decisions,
		"cutoff": cutoff,
		"cancelled": false
	}

## Fixed neutral stochastic policy. It reads only the acting seat's own cards
## and public state and never consults another player's holes, notes or
## personality.
static func _rollout_action(game, actor: int, rng: RandomNumberGenerator) -> Dictionary:
	var legal: Dictionary = game.get_legal_actions(actor)
	var actions: Array = legal.actions
	if actions.is_empty():
		return {}
	var player: Dictionary = game.players[actor]
	var to_call := int(game.get_to_call(actor))
	var pot := int(game.total_pot())
	var strength := _actor_strength(game, actor)
	var aggressive := actions.has(TableState.ACTION_RAISE) or actions.has(TableState.ACTION_ALL_IN)
	if to_call > 0:
		var price := float(to_call) / float(maxi(1, pot + to_call))
		var fold_probability := clampf(0.18 + price * 1.1 - strength * 1.0, 0.0, 0.92)
		if rng.randf() < fold_probability and actions.has(TableState.ACTION_FOLD):
			return {"action_type": TableState.ACTION_FOLD, "amount": 0}
		var raise_probability := clampf(0.08 + strength * 0.5 - price * 0.5, 0.0, 0.7)
		if aggressive and rng.randf() < raise_probability:
			return _rollout_aggressive(game, actor, legal, strength)
		if actions.has(TableState.ACTION_CALL):
			return {"action_type": TableState.ACTION_CALL, "amount": 0}
		return {"action_type": str(actions[0]), "amount": 0}
	var bet_probability := clampf(0.18 + strength * 0.55, 0.05, 0.8)
	if aggressive and rng.randf() < bet_probability:
		return _rollout_aggressive(game, actor, legal, strength)
	if actions.has(TableState.ACTION_CHECK):
		return {"action_type": TableState.ACTION_CHECK, "amount": 0}
	return {"action_type": str(actions[0]), "amount": 0}

static func _rollout_aggressive(game, actor: int, legal: Dictionary, strength: float) -> Dictionary:
	var actions: Array = legal.actions
	var player: Dictionary = game.players[actor]
	var to_call := int(game.get_to_call(actor))
	var pot := int(game.total_pot())
	if actions.has(TableState.ACTION_RAISE):
		var desired := int(round(float(player.current_bet + to_call) + float(pot + to_call) * (0.4 + 0.6 * strength)))
		var target := clampi(desired, int(legal.min_raise_to), int(legal.max_raise_to))
		if target > int(game.current_bet):
			return {"action_type": TableState.ACTION_RAISE, "amount": target}
	if actions.has(TableState.ACTION_ALL_IN):
		return {"action_type": TableState.ACTION_ALL_IN, "amount": 0}
	if actions.has(TableState.ACTION_CALL):
		return {"action_type": TableState.ACTION_CALL, "amount": 0}
	if actions.has(TableState.ACTION_CHECK):
		return {"action_type": TableState.ACTION_CHECK, "amount": 0}
	return {"action_type": TableState.ACTION_FOLD, "amount": 0}

static func _actor_strength(game, actor: int) -> float:
	var own: Array = game.players[actor].hole_cards
	if game.community_cards.is_empty():
		return StartingHandTable.class_strength(StartingHandTable.class_key(own))
	var result := HandEvaluator.evaluate(own + game.community_cards)
	return ActionEV.hand_strength(result)

## Documented depth-cutoff approximation: with no future raises, everyone left
## checks or calls to showdown and the engine deals the sampled runout through
## PokerRound, so side pots, refunds and split payouts stay rule-accurate.
static func _check_call_to_showdown(game, cancellation) -> void:
	var guard := 0
	var limit: int = game.players.size() * 4 + 8
	while game.stage != TableState.STAGE_HAND_OVER and guard < limit:
		if _is_cancelled(cancellation):
			break
		var actor: int = int(game.current_player_index)
		if actor < 0:
			break
		var to_call := int(game.get_to_call(actor))
		var action := TableState.ACTION_CHECK
		if to_call > 0:
			action = TableState.ACTION_ALL_IN if int(game.players[actor].stack) <= to_call else TableState.ACTION_CALL
		if not game.apply_action(action, 0):
			break
		guard += 1
	# An incomplete or cancelled rollout is rejected by the caller. Never force
	# showdown while unresolved legal decisions remain.

# --- world/root construction -------------------------------------------------

static func _clone_root(game, player_index: int, world: Dictionary, live_opponents: Array):
	var simulation = PokerRound.new()
	simulation.players = []
	for i in range(game.players.size()):
		var source: Dictionary = game.players[i]
		simulation.players.append({
			"id": int(source.get("id", i)),
			"name": str(source.get("name", "")),
			"is_human": i == player_index,
			"stack": int(source.get("stack", 0)),
			"current_bet": int(source.get("current_bet", 0)),
			"total_bet": int(source.get("total_bet", 0)),
			"status": str(source.get("status", TableState.STATUS_ACTIVE)),
			"has_acted": bool(source.get("has_acted", false)),
			"last_action_bet": int(source.get("last_action_bet", 0)),
			"difficulty": "medium",
			"personality": {},
			"last_action": str(source.get("last_action", "")),
			"last_action_note": "",
			"hand_result": {},
			# Folded/out seats keep no hole cards at all; only the hero and the
			# sampled live opponents receive cards.
			"hole_cards": []
		})
	simulation.players[player_index].hole_cards = CardUtil.clone_cards(game.players[player_index].hole_cards)
	var opponents: Array = world.get("opponents", [])
	for slot in range(live_opponents.size()):
		var seat: int = int(live_opponents[slot])
		if slot < opponents.size():
			simulation.players[seat].hole_cards = CardUtil.clone_cards(opponents[slot])
	simulation.community_cards = CardUtil.clone_cards(game.community_cards)
	var full_board: Array = world.get("board", [])
	var remaining: Array = full_board.slice(simulation.community_cards.size())
	var deck_cards := []
	for i in range(remaining.size() - 1, -1, -1):
		deck_cards.append(remaining[i])
	simulation.deck = Deck.new()
	simulation.deck.cards = deck_cards
	simulation.stage = game.stage
	simulation.button_index = int(game.button_index)
	simulation.small_blind_player_index = int(game.small_blind_player_index)
	simulation.big_blind_player_index = int(game.big_blind_player_index)
	simulation.current_bet = int(game.current_bet)
	simulation.min_raise = int(game.min_raise)
	simulation.small_blind = int(game.small_blind)
	simulation.big_blind = int(game.big_blind)
	simulation.hand_number = int(game.hand_number)
	simulation.current_player_index = player_index
	simulation.public_action_history = AiTurnWorker.clone_history(game.public_action_history)
	# Simulation flags: no context capture, frame snapshots, event log or
	# history growth, so rollout cost stays bounded.
	simulation.capture_decision_context = false
	simulation.record_frames = false
	simulation.record_events = false
	simulation.record_public_history = false
	return simulation

static func _normalize_worlds(value: Variant, expected_opponents: int, hero_cards: Array = [], public_board: Array = []) -> Array:
	var out := []
	if not (value is Array):
		return out
	for raw in (value as Array):
		if not (raw is Dictionary):
			continue
		var opponents: Variant = (raw as Dictionary).get("opponents", [])
		var board: Variant = (raw as Dictionary).get("board", [])
		if not (opponents is Array) or not (board is Array):
			continue
		if (opponents as Array).size() != expected_opponents or (board as Array).size() != 5:
			continue
		var parsed: Variant = CoachContext._parse_cards(board)
		if parsed == null or parsed.slice(0, public_board.size()) != public_board: continue
		var used := {}
		var valid := true
		for card in hero_cards + parsed:
			var key := CardUtil.card_key(card)
			if used.has(key): valid = false
			used[key] = true
		var clean_opponents := []
		for combo in (opponents as Array):
			if not (combo is Array) or (combo as Array).size() != 2:
				valid = false
				break
			var clean: Variant = CoachContext._parse_cards(combo)
			if clean == null:
				valid = false
				break
			for card in clean:
				var key := CardUtil.card_key(card)
				if used.has(key): valid = false
				used[key] = true
			clean_opponents.append(clean)
		if not valid:
			continue
		out.append({"opponents": clean_opponents, "board": parsed})
	return out

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

# --- scoring -----------------------------------------------------------------

static func _score(candidate: Dictionary, values: Array, big_blind: float) -> Dictionary:
	var n := values.size()
	var mean := 0.0
	for value in values:
		mean += float(value)
	mean = mean / float(maxi(1, n))
	var variance := 0.0
	for value in values:
		variance += pow(float(value) - mean, 2.0)
	var stderr := 0.0
	if n >= 2:
		stderr = sqrt(variance / float(n - 1)) / sqrt(float(n))
	var scored := candidate.duplicate(true)
	scored["ev"] = mean
	scored["ev_bb"] = mean / big_blind
	scored["stderr"] = stderr
	scored["stderr_bb"] = stderr / big_blind
	scored["uncertainty_available"] = n >= 2
	scored["samples"] = n
	scored["values"] = values.duplicate()
	return scored

# --- helpers -----------------------------------------------------------------

static func _rng_for(opts: Dictionary) -> RandomNumberGenerator:
	var provided: Variant = opts.get("rng", null)
	if provided is RandomNumberGenerator:
		return provided
	var rng := RandomNumberGenerator.new()
	if opts.has("seed") and _is_int_like(opts.get("seed")):
		rng.seed = int(float(opts.get("seed")))
	else:
		rng.randomize()
	return rng

static func _is_cancelled(cancellation) -> bool:
	if cancellation == null:
		return false
	if cancellation is CoachCancellation:
		return (cancellation as CoachCancellation).is_cancelled()
	if cancellation.has_method("is_cancelled"):
		return bool(cancellation.is_cancelled())
	return false

static func _int_opt(source: Dictionary, key: String, fallback: int) -> int:
	if source.has(key) and _is_int_like(source.get(key)):
		return int(float(source.get(key)))
	return fallback

static func _is_int_like(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(value) and value == floor(value)
	if value is String:
		return value.is_valid_int()
	return false

static func _unavailable(reason: String, start_ms: int) -> Dictionary:
	return {
		"available": false,
		"reason": reason,
		"version": VERSION,
		"model": MODEL,
		"equity": null,
		"win_rate": null,
		"tie_rate": null,
		"tie_probability": null,
		"world_count": 0,
		"requested_world_count": 0,
		"candidates": [],
		"best": {},
		"depth_reached": 0,
		"max_depth": 0,
		"cutoff_used": false,
		"cutoff_assumption": CUTOFF_ASSUMPTION,
		"assumptions": ASSUMPTIONS,
		"timed_out": false,
		"cancelled": reason == "cancelled",
		"elapsed_ms": Time.get_ticks_msec() - start_ms,
		"pot": 0,
		"to_call": 0,
		"pot_odds": null
	}
