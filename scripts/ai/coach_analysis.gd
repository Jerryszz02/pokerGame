class_name CoachAnalysis
extends RefCounted
## Public coach entry points built on CoachContext, MonteCarlo and FiniteSearch.
##
## live()   -> bounded equity snapshot of a captured decision.
## review() -> FiniteSearch candidate comparison against the actual action.
##
## Both explicitly mark unsupported/malformed contexts and empty sampling as
## available=false with null probabilities instead of reporting fake zeros.
## Nothing here claims optimality; the finite search is a bounded heuristic.

const VERSION := CoachContext.VERSION
const MODEL := "finite_search"
const DEFAULT_LIVE_WORLDS := 256
const MAX_LIVE_WORLDS := 1024
const DEFAULT_REVIEW_WORLDS := 32
const DEFAULT_REVIEW_DEPTH := 12
const DEFAULT_REVIEW_TIME_MS := 1000

const LIVE_ASSUMPTIONS := "fractional showdown equity against neutral public-history ranges, not side-pot-adjusted payout EV; pot price is nominal and complex side pots need action review; tie_probability counts split events; estimates depend on ranges and samples"

static func live(context: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var start_ms := Time.get_ticks_msec()
	var cancellation: Variant = opts.get("cancellation")
	if FiniteSearch._is_cancelled(cancellation): return _live_unavailable("cancelled")
	var game = CoachContext.restore(context)
	if game == null: return _live_unavailable("unsupported_context")
	var hero := int(context.hero)
	if game.get_legal_actions(hero).actions.is_empty(): return _live_unavailable("no_legal_actions")
	var requested := clampi(_int(opts.get("max_worlds", DEFAULT_LIVE_WORLDS), DEFAULT_LIVE_WORLDS), 0, MAX_LIVE_WORLDS)
	if requested == 0: return _live_unavailable("no_worlds")
	var deadline := start_ms + clampi(_int(opts.get("time_budget_ms", 1000), 1000), 1, 10000)
	var rng := _rng_for(opts)
	var explicit: Array = opts.get("worlds", []) if opts.get("worlds", []) is Array else []
	var ranges := []
	if not explicit.is_empty():
		explicit = FiniteSearch._normalize_worlds(explicit, FiniteSearch._live_opponents(game, hero).size(), game.players[hero].hole_cards, game.community_cards)
		if explicit.is_empty(): return _live_unavailable("no_worlds")
		requested = mini(requested, explicit.size())
	else:
		ranges = FiniteSearch.opponent_ranges(game, hero)
		if ranges.is_empty(): return _live_unavailable("no_opponents")
	var count := 0
	var attempted := 0
	var wins := 0.0
	var split_share := 0.0
	var split_events := 0.0
	while attempted < requested and Time.get_ticks_msec() <= deadline:
		if FiniteSearch._is_cancelled(cancellation): return _live_unavailable("cancelled")
		var size := mini(8, requested - attempted)
		var batch: Array = explicit.slice(attempted, attempted + size) if not explicit.is_empty() else MonteCarlo.sample_worlds(game.players[hero].hole_cards, game.community_cards, ranges, size, rng)
		attempted += size
		if batch.is_empty(): continue
		var summary := MonteCarlo.evaluate_worlds(game.players[hero].hole_cards, batch)
		count += int(summary.count)
		wins += float(summary.win_rate) * int(summary.count)
		split_share += float(summary.tie_rate) * int(summary.count)
		split_events += float(summary.tie_probability) * int(summary.count)
	if FiniteSearch._is_cancelled(cancellation): return _live_unavailable("cancelled")
	if count == 0: return _live_unavailable("time_budget" if Time.get_ticks_msec() > deadline else "no_worlds")
	var pot := int(game.total_pot())
	var to_call := mini(int(game.get_to_call(hero)), int(game.players[hero].stack))
	return {
		"available": true, "reason": "", "version": VERSION,
		"win_rate": wins / count, "tie_probability": split_events / count,
		"tie_rate": split_share / count, "equity": (wins + split_share) / count,
		"world_count": count, "requested_world_count": requested,
		"uncertainty_available": count >= 2, "timed_out": attempted < requested,
		"elapsed_ms": Time.get_ticks_msec() - start_ms,
		"pot": pot, "to_call": to_call,
		"pot_odds": float(to_call) / maxi(1, pot + to_call),
		"assumptions": LIVE_ASSUMPTIONS
	}

static func review(context: Dictionary, actual_action: Dictionary = {}, opts: Dictionary = {}) -> Dictionary:
	var start_ms := Time.get_ticks_msec()
	if not (context is Dictionary) or context.is_empty():
		return _review_unavailable("unsupported_context", _echo_actual(actual_action), start_ms)
	var game = CoachContext.restore(context)
	if game == null:
		return _review_unavailable("unsupported_context", _echo_actual(actual_action), start_ms)
	var hero := _int(context.get("hero", 0), 0)
	if hero < 0 or hero >= game.players.size():
		return _review_unavailable("bad_hero", _echo_actual(actual_action), start_ms)
	if game.get_legal_actions(hero).actions.is_empty():
		return _review_unavailable("no_legal_actions", _echo_actual(actual_action), start_ms)
	var normalized := FiniteSearch.normalize_actual(game, hero, actual_action)
	if normalized.is_empty():
		# An illegal actual action is reported, never replaced by another move.
		return _review_unavailable("illegal_actual_action", _echo_actual(actual_action), start_ms)

	var search_opts := {
		"max_worlds": clampi(_int(opts.get("max_worlds", DEFAULT_REVIEW_WORLDS), DEFAULT_REVIEW_WORLDS), 1, FiniteSearch.MAX_WORLDS),
		"max_depth": clampi(_int(opts.get("max_depth", DEFAULT_REVIEW_DEPTH), DEFAULT_REVIEW_DEPTH), 1, FiniteSearch.MAX_DEPTH),
		"time_budget_ms": clampi(_int(opts.get("time_budget_ms", DEFAULT_REVIEW_TIME_MS), DEFAULT_REVIEW_TIME_MS), 1, 60000),
		"actual_action": normalized
	}
	if opts.has("seed"):
		search_opts["seed"] = opts.get("seed")
	if opts.get("rng", null) is RandomNumberGenerator:
		search_opts["rng"] = opts.get("rng")
	if opts.get("worlds", []) is Array:
		search_opts["worlds"] = opts.get("worlds")
	if opts.get("cancellation", null) != null:
		search_opts["cancellation"] = opts.get("cancellation")

	var result := FiniteSearch.evaluate(game, hero, search_opts)
	if not bool(result.get("available", false)):
		return _review_unavailable(str(result.get("reason", "unavailable")), _echo_actual(actual_action), start_ms)
	var candidates: Array = result.get("candidates", [])
	var best: Dictionary = result.get("best", {})
	var actual := _find_candidate(candidates, normalized)
	if not actual.is_empty():
		actual = actual.duplicate(true)
		actual["legal"] = true
		if str(normalized.get("action_type", "")) == TableState.ACTION_ALL_IN:
			actual["amount"] = int(normalized.get("amount", 0))

	var big_blind := maxf(1.0, float(game.big_blind))
	var gap_bb := 0.0
	var stderr_diff_bb := 0.0
	var close := true
	if not best.is_empty() and not actual.is_empty():
		gap_bb = (float(best.ev) - float(actual.ev)) / big_blind
		var best_values: Array = best.get("values", [])
		var actual_values: Array = actual.get("values", [])
		var n := mini(best_values.size(), actual_values.size())
		if n >= 2:
			var mean_diff := 0.0
			var diffs := []
			for i in range(n):
				var diff := float(actual_values[i]) - float(best_values[i])
				diffs.append(diff)
				mean_diff += diff
			mean_diff = mean_diff / float(n)
			var variance := 0.0
			for diff in diffs:
				variance += pow(float(diff) - mean_diff, 2.0)
			var stderr_diff := sqrt(variance / float(n - 1)) / sqrt(float(n))
			stderr_diff_bb = stderr_diff / big_blind
			# Paired-difference test: the actual action is close when its
			# paired loss is within ~95% of the sampled difference noise.
			close = gap_bb <= 1.96 * stderr_diff_bb
		else:
			close = true

	var out := result.duplicate(true)
	out["actual"] = actual
	out["gap_bb"] = gap_bb
	out["stderr_diff_bb"] = stderr_diff_bb
	out["close"] = close
	out["depth"] = int(result.get("depth_reached", 0))
	out["elapsed_ms"] = Time.get_ticks_msec() - start_ms
	out["model"] = MODEL
	out["reviewed"] = true
	return out

# --- helpers -----------------------------------------------------------------

static func _find_candidate(candidates: Array, normalized: Dictionary) -> Dictionary:
	var action := str(normalized.get("action_type", ""))
	for candidate in candidates:
		if str(candidate.get("action_type", "")) != action:
			continue
		if action in [TableState.ACTION_FOLD, TableState.ACTION_CHECK, TableState.ACTION_CALL, TableState.ACTION_ALL_IN]:
			return candidate
		if int(candidate.get("amount", -1)) == int(normalized.get("amount", -2)):
			return candidate
	return {}

static func _echo_actual(actual: Variant) -> Dictionary:
	if not (actual is Dictionary):
		return {}
	return {
		"action_type": str((actual as Dictionary).get("action_type", "")),
		"amount": _int((actual as Dictionary).get("amount", 0), 0),
		"legal": false
	}

static func _live_unavailable(reason: String) -> Dictionary:
	return {
		"available": false,
		"reason": reason,
		"version": VERSION,
		"win_rate": null,
		"tie_probability": null,
		"tie_rate": null,
		"equity": null,
		"world_count": 0,
		"pot": null,
		"to_call": null,
		"pot_odds": null,
		"assumptions": LIVE_ASSUMPTIONS
	}

static func _review_unavailable(reason: String, actual: Dictionary, start_ms: int) -> Dictionary:
	var out := _live_unavailable(reason)
	out["candidates"] = []
	out["best"] = {}
	out["actual"] = actual
	out["gap_bb"] = null
	out["stderr_diff_bb"] = null
	out["close"] = true
	out["depth"] = 0
	out["elapsed_ms"] = Time.get_ticks_msec() - start_ms
	out["model"] = MODEL
	out["reviewed"] = true
	return out

static func _rng_for(opts: Dictionary) -> RandomNumberGenerator:
	var provided: Variant = opts.get("rng", null)
	if provided is RandomNumberGenerator:
		return provided
	var rng := RandomNumberGenerator.new()
	if opts.has("seed") and (opts.get("seed") is int or opts.get("seed") is float):
		rng.seed = int(float(opts.get("seed")))
	else:
		rng.randomize()
	return rng

static func _int(value: Variant, fallback: int) -> int:
	if value is int:
		return value
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	if value is String and value.is_valid_int():
		return value.to_int()
	return fallback
