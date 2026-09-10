class_name AiDecision
extends RefCounted
## Decision entry point.
##
## Preflop uses the 169-class StartingHandTable range heuristic (no preflop
## MonteCarlo). Postflop, simple keeps cheap rules while medium/hard compare
## bounded ActionEV candidates over shared MonteCarlo worlds. Everything the
## strategy reads is either the acting player's own cards/profile or public
## table state; opponent hole cards, hidden decks, notes and personality
## internals are never consulted. Decisions are returned as
## {action_type, amount, decision_label} plus optional `analysis` diagnostics;
## the EV comparison is a heuristic, not a proven best action.

static func decide(game: PokerRound, player_index: int, rng_override: RandomNumberGenerator = null) -> Dictionary:
	if player_index < 0 or player_index >= game.players.size():
		return _decision(TableState.ACTION_CHECK, 0, "无可用行动")
	var player: Dictionary = game.players[player_index]
	var legal := game.get_legal_actions(player_index)
	var actions: Array = legal.actions
	if actions.is_empty():
		return _decision(TableState.ACTION_CHECK, 0, "无可用行动")
	var profile := _profile_for(player)
	var rng: RandomNumberGenerator = rng_override if rng_override != null else _local_rng()
	var analysis := {
		"difficulty": str(profile.get("difficulty", "medium")),
		"model_effort": int(profile.get("model_effort", 1)),
		"style": {
			"aggression": float(profile.get("aggression", 0.5)),
			"looseness": float(profile.get("looseness", 0.35)),
			"bluff_rate": float(profile.get("bluff_rate", 0.1)),
			"call_tolerance": float(profile.get("call_tolerance", 0.0))
		}
	}
	var chosen: Dictionary
	if game.stage == TableState.STAGE_PREFLOP:
		chosen = _decide_preflop(game, player_index, legal, profile, rng, analysis)
	elif str(profile.get("difficulty", "medium")) == "simple":
		chosen = _decide_simple_postflop(game, player_index, legal, profile, rng, analysis)
	else:
		chosen = _decide_ev_postflop(game, player_index, legal, profile, rng, analysis)
	if chosen.is_empty() or not actions.has(str(chosen.get("action_type", ""))):
		chosen = _fallback(legal)
	chosen["decision_label"] = str(chosen.get("decision_label", "继续"))
	chosen["analysis"] = analysis
	return chosen

static func profile_for_difficulty(difficulty: String) -> Dictionary:
	var resolved := difficulty if PersonalityProfiles.DIFFICULTIES.has(difficulty) else "medium"
	var style := {}
	match resolved:
		"simple":
			style = {
				"name": "Simple", "label": "简单", "aggression": 0.35,
				"looseness": 0.28, "bluff_rate": 0.04, "call_tolerance": -0.02
			}
		"hard":
			style = {"name": "Hard", "label": "困难"}
		_:
			style = {
				"name": "Medium", "label": "中等", "aggression": 0.5,
				"looseness": 0.35, "bluff_rate": 0.07, "call_tolerance": 0.04
			}
	var profile := PersonalityProfiles.get_profile("Balanced", style)
	profile["difficulty"] = resolved
	return PersonalityProfiles.apply_difficulty(profile, resolved)

static func _profile_for(player: Dictionary) -> Dictionary:
	var difficulty := str(player.get("difficulty", "medium"))
	if not PersonalityProfiles.DIFFICULTIES.has(difficulty):
		difficulty = "medium"
	var personality: Variant = player.get("personality", {})
	if personality is Dictionary and not (personality as Dictionary).is_empty():
		# Style comes from the seat; difficulty owns model effort/noise.
		return PersonalityProfiles.apply_difficulty(personality, difficulty)
	return profile_for_difficulty(difficulty)

# --- preflop ----------------------------------------------------------------

static func _decide_preflop(game: PokerRound, player_index: int, legal: Dictionary, profile: Dictionary, rng: RandomNumberGenerator, analysis: Dictionary) -> Dictionary:
	var player: Dictionary = game.players[player_index]
	var actions: Array = legal.actions
	var context := StartingHandTable.context_from_game(game, player_index, profile)
	var frequencies := StartingHandTable.action_frequencies(player.hole_cards, context)
	analysis["preflop"] = {
		"class": frequencies["class"],
		"tier": frequencies["tier"],
		"strength": frequencies.strength,
		"open_frequency": frequencies.open_frequency,
		"continue_frequency": frequencies.continue_frequency,
		"reraise_frequency": frequencies.reraise_frequency,
		"context": context
	}
	var to_call := game.get_to_call(player_index)
	var raises_before := int(context.raises_before)
	var roll := rng.randf()

	if to_call > 0 and raises_before > 0:
		if roll < float(frequencies.reraise_frequency):
			if actions.has(TableState.ACTION_RAISE):
				return _raise_action(game, player_index, legal, _three_bet_target(game), "范围再加注")
			if actions.has(TableState.ACTION_ALL_IN):
				return _decision(TableState.ACTION_ALL_IN, 0, "范围全下")
		if roll < float(frequencies.continue_frequency) and actions.has(TableState.ACTION_CALL):
			return _decision(TableState.ACTION_CALL, 0, "范围跟注")
		if actions.has(TableState.ACTION_FOLD):
			return _decision(TableState.ACTION_FOLD, 0, "范围弃牌")
		return _fallback(legal)

	if to_call > 0:
		if roll < float(frequencies.open_frequency):
			return _open_action(game, player_index, legal, profile, rng)
		var limp_frequency := clampf(0.12 + 0.25 * float(profile.looseness) - 0.2 * float(profile.aggression), 0.0, 0.4)
		if roll < float(frequencies.open_frequency) + limp_frequency and actions.has(TableState.ACTION_CALL):
			return _decision(TableState.ACTION_CALL, 0, "平跟入池")
		if actions.has(TableState.ACTION_FOLD):
			return _decision(TableState.ACTION_FOLD, 0, "范围弃牌")
		return _fallback(legal)

	if roll < float(frequencies.open_frequency):
		return _open_action(game, player_index, legal, profile, rng)
	if actions.has(TableState.ACTION_CHECK):
		return _decision(TableState.ACTION_CHECK, 0, "免费看牌")
	return _fallback(legal)

static func _open_action(game: PokerRound, player_index: int, legal: Dictionary, profile: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var player: Dictionary = game.players[player_index]
	# Entry range controls which hands participate; aggression controls whether
	# that participation opens the betting or takes the passive legal action.
	var strength := StartingHandTable.class_strength(StartingHandTable.class_key(player.hole_cards))
	var raise_share := clampf(0.20 + 0.85 * float(profile.aggression) + 0.15 * strength, 0.20, 0.98)
	if rng.randf() >= raise_share:
		if legal.actions.has(TableState.ACTION_CHECK):
			return _decision(TableState.ACTION_CHECK, 0, "范围让牌")
		if legal.actions.has(TableState.ACTION_CALL):
			return _decision(TableState.ACTION_CALL, 0, "范围平跟")
	var desired := maxi(int(legal.min_raise_to), int(game.current_bet) + int(round(2.5 * float(game.big_blind))))
	var target := clampi(desired, int(legal.min_raise_to), int(legal.max_raise_to))
	if target >= int(player.current_bet) + int(player.stack) and legal.actions.has(TableState.ACTION_ALL_IN):
		return _decision(TableState.ACTION_ALL_IN, 0, "范围全下")
	return _decision(TableState.ACTION_RAISE, target, "范围开池")

static func _three_bet_target(game: PokerRound) -> int:
	return int(round(float(maxi(int(game.current_bet), int(game.big_blind))) * 3.0))

static func _raise_action(game: PokerRound, player_index: int, legal: Dictionary, target: int, label: String) -> Dictionary:
	var player: Dictionary = game.players[player_index]
	var clamped := clampi(target, int(legal.min_raise_to), int(legal.max_raise_to))
	if clamped >= int(player.current_bet) + int(player.stack) and legal.actions.has(TableState.ACTION_ALL_IN):
		return _decision(TableState.ACTION_ALL_IN, 0, label)
	if not legal.actions.has(TableState.ACTION_RAISE):
		return _fallback(legal)
	return _decision(TableState.ACTION_RAISE, clamped, label)

# --- postflop: simple -------------------------------------------------------

static func _decide_simple_postflop(game: PokerRound, player_index: int, legal: Dictionary, profile: Dictionary, rng: RandomNumberGenerator, analysis: Dictionary) -> Dictionary:
	var actions: Array = legal.actions
	var to_call := game.get_to_call(player_index)
	var result := game.best_hand_for(player_index)
	var strength := clampf(0.12 + float(result.rank_value) * 0.10 + float(profile.looseness) * 0.05, 0.0, 0.95)
	var pot_after := maxi(1, game.total_pot() + to_call)
	var pot_odds := float(to_call) / float(pot_after)
	analysis["simple_strength"] = strength
	if to_call > 0 and strength + float(profile.call_tolerance) < pot_odds:
		if actions.has(TableState.ACTION_RAISE) and rng.randf() < float(profile.bluff_rate):
			return _raise_action(game, player_index, legal, int(round(float(maxi(int(game.current_bet), int(game.big_blind))) * 2.5)), "诈唬加注")
		if actions.has(TableState.ACTION_FOLD):
			return _decision(TableState.ACTION_FOLD, 0, "谨慎弃牌")
	var value_threshold := 0.58 - float(profile.aggression) * 0.1
	if actions.has(TableState.ACTION_RAISE) and strength >= value_threshold and rng.randf() < float(profile.aggression):
		return _raise_action(game, player_index, legal, int(round(float(maxi(int(game.current_bet), int(game.big_blind))) * 2.0)), "价值加注")
	if to_call > 0 and actions.has(TableState.ACTION_CALL):
		return _decision(TableState.ACTION_CALL, 0, "赔率跟注")
	if actions.has(TableState.ACTION_CHECK):
		return _decision(TableState.ACTION_CHECK, 0, "控池让牌")
	return _fallback(legal)

# --- postflop: EV comparison ------------------------------------------------

static func _decide_ev_postflop(game: PokerRound, player_index: int, legal: Dictionary, profile: Dictionary, rng: RandomNumberGenerator, analysis: Dictionary) -> Dictionary:
	var result := ActionEV.evaluate(game, player_index, profile, {"rng": rng})
	analysis["action_ev"] = {
		"assumptions": result.get("assumptions", ""),
		"world_count": int(result.get("world_count", 0)),
		"requested_world_count": int(result.get("requested_world_count", 0)),
		"sampling_insufficient": bool(result.get("sampling_insufficient", false)),
		"response_model": str(result.get("response_model", "")),
		"equity": float(result.get("equity", 0.0)),
		"candidates": result.get("candidates", [])
	}
	var candidates: Array = result.get("candidates", [])
	if candidates.is_empty() or (int(result.get("world_count", 0)) == 0 and bool(result.get("sampling_insufficient", false))):
		# A fully rejected joint sampler has no evidence for an EV choice.
		if legal.actions.has(TableState.ACTION_CHECK):
			return _decision(TableState.ACTION_CHECK, 0, "采样不足，保守让牌")
		if legal.actions.has(TableState.ACTION_FOLD):
			return _decision(TableState.ACTION_FOLD, 0, "采样不足，保守弃牌")
		return _fallback(legal)
	var chosen := _choose_candidate(game, candidates, profile, rng)
	return _decision(str(chosen.get("action_type", TableState.ACTION_CHECK)), int(chosen.get("amount", 0)), _candidate_label(chosen))

static func _choose_candidate(game: PokerRound, candidates: Array, profile: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var big_blind := maxf(1.0, float(game.big_blind))
	var best_ev := -INF
	for candidate in candidates:
		best_ev = maxf(best_ev, float(candidate.get("ev", 0.0)))
	var noise := float(profile.get("action_noise", 0.06))
	var margin := (0.35 + 0.6 * noise) * big_blind
	var allowed := []
	for candidate in candidates:
		if float(candidate.get("ev", 0.0)) >= best_ev - margin:
			allowed.append(candidate)
	if allowed.is_empty():
		allowed = [candidates[0]]
	# Allocate preference by action category, then choose a size in that
	# category. Extra legal raise sizes therefore do not increase aggression.
	var categories := {}
	for candidate in allowed:
		var category := _candidate_category(game, candidate)
		if not categories.has(category):
			categories[category] = []
		categories[category].append(candidate)
	var category_total := 0.0
	var category_weights := {}
	for category in categories:
		var category_weight := maxf(0.01, _candidate_weight(str(category), profile) * (1.0 + noise * (rng.randf() - 0.5)))
		category_weights[category] = category_weight
		category_total += category_weight
	var roll := rng.randf() * category_total
	var running := 0.0
	var chosen_category := str(categories.keys()[0])
	for category in categories:
		running += float(category_weights[category])
		if roll <= running:
			chosen_category = str(category)
			break
	var category_candidates: Array = categories[chosen_category]
	return category_candidates[rng.randi_range(0, category_candidates.size() - 1)]

static func _candidate_category(game: PokerRound, candidate: Dictionary) -> String:
	var action := str(candidate.get("action_type", ""))
	if action == TableState.ACTION_ALL_IN:
		if candidate.has("is_aggressive"):
			return "aggressive" if bool(candidate.is_aggressive) else TableState.ACTION_CALL
		var player: Dictionary = game.players[int(game.current_player_index)]
		if int(player.current_bet) + int(player.stack) <= int(game.current_bet):
			return TableState.ACTION_CALL
	return "aggressive" if action == TableState.ACTION_RAISE or action == TableState.ACTION_ALL_IN else action

static func _candidate_weight(action_type: String, profile: Dictionary) -> float:
	var aggression := float(profile.get("aggression", 0.5))
	var looseness := float(profile.get("looseness", 0.35))
	match action_type:
		TableState.ACTION_FOLD:
			return maxf(0.05, 0.6 - 0.5 * looseness - 0.2 * aggression)
		TableState.ACTION_CALL, TableState.ACTION_CHECK:
			return 1.0 + float(profile.get("call_tolerance", 0.0))
		"aggressive":
			return 0.6 + 1.2 * aggression + 0.6 * float(profile.get("bluff_rate", 0.0))
	return 1.0

static func _candidate_label(candidate: Dictionary) -> String:
	match str(candidate.get("action_type", "")):
		TableState.ACTION_FOLD:
			return "EV弃牌"
		TableState.ACTION_CHECK:
			return "EV让牌"
		TableState.ACTION_CALL:
			return "EV跟注"
		TableState.ACTION_RAISE:
			return "EV加注"
		TableState.ACTION_ALL_IN:
			return "EV全下"
	return "EV行动"

# --- helpers ----------------------------------------------------------------

static func _fallback(legal: Dictionary) -> Dictionary:
	var actions: Array = legal.actions
	if actions.has(TableState.ACTION_CHECK):
		return _decision(TableState.ACTION_CHECK, 0, "免费看牌")
	if actions.has(TableState.ACTION_CALL):
		return _decision(TableState.ACTION_CALL, 0, "跟注")
	if actions.has(TableState.ACTION_FOLD):
		return _decision(TableState.ACTION_FOLD, 0, "弃牌")
	if actions.has(TableState.ACTION_RAISE):
		return _decision(TableState.ACTION_RAISE, int(legal.min_raise_to), "继续")
	if actions.has(TableState.ACTION_ALL_IN):
		return _decision(TableState.ACTION_ALL_IN, 0, "全下")
	if actions.is_empty():
		return _decision(TableState.ACTION_CHECK, 0, "无可用行动")
	return _decision(str(actions[0]), 0, "继续")

static func _decision(action_type: String, amount: int, label: String) -> Dictionary:
	return {"action_type": action_type, "amount": amount, "decision_label": label}

static func _local_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng
