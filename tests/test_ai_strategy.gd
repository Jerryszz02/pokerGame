extends SceneTree
## Bounded strategy tests: 169-class preflop coverage, position/stack context,
## personality normalization, weighted opponent ranges, MonteCarlo sampling and
## analytic ActionEV fixtures. Deterministic seeds are used where sampling is
## involved.

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_class_coverage()
	_test_strength_ordering()
	_test_position_and_heads_up()
	_test_context_conditioning()
	_test_looseness_is_operational()
	_test_chip_scale_invariance()
	_test_profile_validation()
	_test_opponent_range()
	_test_monte_carlo()
	_test_range_regressions()
	_test_final_boundaries()
	_test_action_ev_fixtures()
	_test_action_ev_game()
	_test_response_uses_current_board_only()
	_test_decision_legal_and_bounded()
	_test_preset_tendencies()
	if failures == 0:
		print("AI strategy tests passed.")
	else:
		push_error("%d AI strategy tests failed." % failures)
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func c(rank: int, suit: String) -> Dictionary:
	return CardUtil.make_card(rank, suit)

func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _base_context() -> Dictionary:
	return {
		"relative_position": 0.5,
		"live_players": 6,
		"raises_before": 0,
		"facing_bb": 1.0,
		"effective_stack_bb": 100.0,
		"looseness": 0.35,
		"aggression": 0.5,
		"is_button": false,
		"is_blind": false,
		"closing_action": false,
		"is_heads_up": false
	}

func _test_class_coverage() -> void:
	var keys: Array = StartingHandTable.all_class_keys()
	_assert(keys.size() == 169, "range must contain 169 classes")
	var seen := {}
	var pairs := 0
	var suited := 0
	var offsuit := 0
	for key in keys:
		_assert(not seen.has(key), "class keys must be unique: %s" % key)
		seen[key] = true
		var info: Dictionary = StartingHandTable.class_info(key)
		if info.is_empty():
			failures += 1
			push_error("class_info failed for %s" % key)
		elif info.pair:
			pairs += 1
		elif info.suited:
			suited += 1
		else:
			offsuit += 1
	_assert(pairs == 13, "expected 13 pairs, got %d" % pairs)
	_assert(suited == 78, "expected 78 suited, got %d" % suited)
	_assert(offsuit == 78, "expected 78 offsuit, got %d" % offsuit)
	_assert(StartingHandTable.class_key([c(14, "S"), c(13, "S")]) == "AKs", "suited class key")
	_assert(StartingHandTable.class_key([c(14, "S"), c(13, "H")]) == "AKo", "offsuit class key")
	_assert(StartingHandTable.class_key([c(14, "S"), c(14, "H")]) == "AA", "pair class key")
	_assert(StartingHandTable.class_combos("AA").size() == 6, "pair has 6 combos")
	_assert(StartingHandTable.class_combos("AKs").size() == 4, "suited has 4 combos")
	_assert(StartingHandTable.class_combos("AKo").size() == 12, "offsuit has 12 combos")

func _test_strength_ordering() -> void:
	var ordered := ["AA", "KK", "QQ", "JJ", "TT", "AKs", "AKo", "72o"]
	for i in range(ordered.size() - 1):
		_assert(StartingHandTable.class_strength(ordered[i]) > StartingHandTable.class_strength(ordered[i + 1]),
			"%s should outrank %s" % [ordered[i], ordered[i + 1]])
	_assert(StartingHandTable.class_strength("AA") > StartingHandTable.class_strength("AKs"), "premium pair beats suited ace")
	_assert(StartingHandTable.class_strength("22") > StartingHandTable.class_strength("72o"), "small pair beats junk")
	_assert(StartingHandTable.class_strength("AKs") > StartingHandTable.class_strength("AKo"), "suited beats offsuit")
	for key in StartingHandTable.all_class_keys():
		var strength := StartingHandTable.class_strength(key)
		_assert(not is_nan(strength) and not is_inf(strength), "finite strength for %s" % key)
		_assert(strength > 0.0 and strength <= 1.0, "strength range for %s" % key)

func _test_position_and_heads_up() -> void:
	var heads_up := PokerRound.new()
	heads_up.shuffle_rng.seed = 11
	heads_up.start_new_match(1, "medium")
	_assert(heads_up.small_blind_player_index == 0, "heads-up small blind is the button")
	_assert(heads_up.big_blind_player_index == 1, "heads-up big blind is the other seat")
	_assert(heads_up.current_player_index == 0, "heads-up button acts first preflop")
	var sb_context := StartingHandTable.context_from_game(heads_up, 0, {})
	var bb_context := StartingHandTable.context_from_game(heads_up, 1, {})
	_assert(bool(sb_context.is_button), "heads-up small blind holds the button")
	_assert(not bool(bb_context.is_button), "heads-up big blind is not the button")
	_assert(bool(sb_context.is_blind) and bool(bb_context.is_blind), "both heads-up seats post blinds")
	_assert(not bool(bb_context.closing_action), "big blind is not closed before the button acts")
	_assert(not bool(sb_context.closing_action), "heads-up button does not close preflop")
	_assert(heads_up.apply_action(TableState.ACTION_CALL), "heads-up button can limp")
	bb_context = StartingHandTable.context_from_game(heads_up, 1, {})
	_assert(bool(bb_context.closing_action), "big blind closes only after the button limps")
	_assert(float(sb_context.relative_position) > float(bb_context.relative_position), "button has postflop positional advantage")

	var full_ring := PokerRound.new()
	full_ring.shuffle_rng.seed = 12
	full_ring.start_new_match(5, "medium")
	_assert(full_ring.current_player_index == 3, "first full-ring actor is after the big blind")
	var early_context := StartingHandTable.context_from_game(full_ring, 3, {})
	var button_context := StartingHandTable.context_from_game(full_ring, 0, {})
	_assert(float(button_context.relative_position) > float(early_context.relative_position), "button is later than the first actor")
	var marginal := [c(10, "S"), c(8, "S")]
	var early_frequencies := StartingHandTable.action_frequencies(marginal, early_context)
	var button_frequencies := StartingHandTable.action_frequencies(marginal, button_context)
	_assert(float(button_frequencies.open_frequency) >= float(early_frequencies.open_frequency), "button opens at least as wide as first position")

func _test_context_conditioning() -> void:
	var base := _base_context()
	var deep = base.duplicate(true)
	deep.effective_stack_bb = 200.0
	var short = base.duplicate(true)
	short.effective_stack_bb = 15.0
	var connector := [c(9, "S"), c(8, "S")]
	var deep_frequencies := StartingHandTable.action_frequencies(connector, deep)
	var short_frequencies := StartingHandTable.action_frequencies(connector, short)
	_assert(float(deep_frequencies.open_frequency) > float(short_frequencies.open_frequency), "deep stacks widen suited connectors")
	var small_pair := [c(5, "S"), c(5, "H")]
	_assert(float(StartingHandTable.action_frequencies(small_pair, deep).open_frequency) > float(StartingHandTable.action_frequencies(small_pair, short).open_frequency), "deep stacks widen small pairs")

	var versus_small = base.duplicate(true)
	versus_small.raises_before = 1
	versus_small.facing_bb = 3.0
	var versus_big = base.duplicate(true)
	versus_big.raises_before = 1
	versus_big.facing_bb = 12.0
	var hand := [c(11, "S"), c(10, "S")]
	_assert(float(StartingHandTable.action_frequencies(hand, versus_small).continue_frequency) > float(StartingHandTable.action_frequencies(hand, versus_big).continue_frequency), "bigger price tightens the continue range")

	var one_raise = base.duplicate(true)
	one_raise.raises_before = 1
	one_raise.facing_bb = 3.0
	var many_raises = base.duplicate(true)
	many_raises.raises_before = 3
	many_raises.facing_bb = 3.0
	_assert(float(StartingHandTable.action_frequencies(hand, one_raise).continue_frequency) >= float(StartingHandTable.action_frequencies(hand, many_raises).continue_frequency), "more raises tighten the continue range")
	var premium := [c(14, "S"), c(14, "H")]
	_assert(float(StartingHandTable.action_frequencies(premium, many_raises).reraise_frequency) > float(StartingHandTable.action_frequencies(hand, many_raises).reraise_frequency), "premium hands reraise more")

	# Unopened frequency and facing-raise frequency are distinct decisions.
	var open_frequencies := StartingHandTable.action_frequencies(premium, base)
	_assert(open_frequencies.has("open_frequency") and open_frequencies.has("continue_frequency") and open_frequencies.has("reraise_frequency"), "open/continue/reraise are distinct")

func _test_looseness_is_operational() -> void:
	var tight := _base_context()
	tight.looseness = 0.10
	var loose := _base_context()
	loose.looseness = 0.85
	var facing_tight := tight.duplicate(true)
	facing_tight.raises_before = 1
	facing_tight.facing_bb = 3.0
	var facing_loose := loose.duplicate(true)
	facing_loose.raises_before = 1
	facing_loose.facing_bb = 3.0
	for hand in [[c(12, "S"), c(11, "S")], [c(6, "S"), c(6, "H")], [c(14, "S"), c(9, "H")]]:
		_assert(float(StartingHandTable.action_frequencies(hand, loose).open_frequency) > float(StartingHandTable.action_frequencies(hand, tight).open_frequency), "looseness widens opens")
		_assert(float(StartingHandTable.action_frequencies(hand, facing_loose).continue_frequency) >= float(StartingHandTable.action_frequencies(hand, facing_tight).continue_frequency), "looseness widens continues")

func _test_chip_scale_invariance() -> void:
	var normal := PokerRound.new()
	normal.shuffle_rng.seed = 21
	normal.start_new_match(3, "medium")
	var scaled := PokerRound.new()
	scaled.shuffle_rng.seed = 21
	scaled.start_new_match(3, "medium")
	scaled.big_blind *= 10
	scaled.small_blind *= 10
	scaled.current_bet *= 10
	scaled.min_raise *= 10
	for player in scaled.players:
		player.stack *= 10
		player.current_bet *= 10
		player.total_bet *= 10
	var normal_context := StartingHandTable.context_from_game(normal, 3, {})
	var scaled_context := StartingHandTable.context_from_game(scaled, 3, {})
	_assert(is_equal_approx(float(normal_context.facing_bb), float(scaled_context.facing_bb)), "facing amount is BB-relative")
	_assert(is_equal_approx(float(normal_context.effective_stack_bb), float(scaled_context.effective_stack_bb)), "effective stack is BB-relative")
	var hand := [c(11, "S"), c(11, "H")]
	var normal_frequencies := StartingHandTable.action_frequencies(hand, normal_context)
	var scaled_frequencies := StartingHandTable.action_frequencies(hand, scaled_context)
	_assert(is_equal_approx(float(normal_frequencies.open_frequency), float(scaled_frequencies.open_frequency)), "open frequency is chip-scale invariant")
	_assert(is_equal_approx(float(normal_frequencies.continue_frequency), float(scaled_frequencies.continue_frequency)), "continue frequency is chip-scale invariant")

func _test_profile_validation() -> void:
	var unknown := PersonalityProfiles.get_profile("NoSuchProfile")
	_assert(str(unknown.name) == "Balanced", "unknown profile falls back to Balanced")
	var rock := PersonalityProfiles.get_profile("Rock")
	for field in ["name", "label", "aggression", "looseness", "bluff_rate", "call_tolerance", "simulation_count"]:
		_assert(rock.has(field), "profile keeps compatible field %s" % field)
	var dirty := PersonalityProfiles.get_profile("Rock", {
		"aggression": NAN,
		"looseness": INF,
		"bluff_rate": "not a number",
		"simulation_count": 999999,
		"history_detail": -50,
		"action_noise": 42.0,
		"unknown_field": "ignored"
	})
	_assert(not is_nan(float(dirty.aggression)) and not is_inf(float(dirty.aggression)), "NaN/Inf aggression is replaced")
	_assert(float(dirty.aggression) >= 0.0 and float(dirty.aggression) <= 1.0, "aggression stays bounded")
	_assert(float(dirty.looseness) >= 0.0 and float(dirty.looseness) <= 1.0, "Inf looseness is replaced")
	_assert(float(dirty.bluff_rate) >= 0.0 and float(dirty.bluff_rate) <= 1.0, "non-numeric bluff rate is replaced")
	_assert(int(dirty.simulation_count) <= PersonalityProfiles.MAX_SIMULATIONS, "simulation budget is bounded")
	_assert(int(dirty.history_detail) == 0, "negative history detail clamps to zero")
	_assert(float(dirty.action_noise) <= 0.5, "action noise stays bounded")
	_assert(not dirty.has("unknown_field"), "unknown fields are dropped")
	var simple := AiDecision.profile_for_difficulty("simple")
	var medium := AiDecision.profile_for_difficulty("medium")
	var hard := AiDecision.profile_for_difficulty("hard")
	_assert(float(simple.aggression) != float(medium.aggression), "simple and medium aggression differ")
	_assert(float(medium.bluff_rate) != float(hard.bluff_rate), "medium and hard bluff rates differ")
	_assert(int(simple.model_effort) == 0 and int(medium.model_effort) == 1 and int(hard.model_effort) == 2, "difficulty owns model effort")
	_assert(int(hard.simulation_count) <= PersonalityProfiles.MAX_SIMULATIONS, "hard simulation budget is bounded")
	_assert(float(simple.aggression) == float(PersonalityProfiles.get_profile("Balanced", {"aggression": 0.35}).aggression), "preset override path is normalized")

func _test_opponent_range() -> void:
	var hero := [c(14, "S"), c(14, "H")]
	var board := [c(2, "C"), c(7, "D"), c(9, "S")]
	var opponent_range := OpponentRange.new(hero, board)
	_assert(opponent_range.total_weight() > 0.0, "neutral range has support")
	_assert(opponent_range.combo_weight(c(14, "S"), c(14, "D")) == 0.0, "hero blocker excluded")
	_assert(opponent_range.combo_weight(c(2, "C"), c(3, "C")) == 0.0, "board blocker excluded")
	_assert(opponent_range.combo_weight(c(14, "S"), c(13, "S")) == 0.0, "combo touching a hero card is blocked")
	_assert(opponent_range.combo_weight(c(13, "S"), c(12, "S")) > 0.0, "legal combo keeps weight")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for _i in range(40):
		var combo: Array = opponent_range.sample_combo(rng)
		_assert(combo.size() == 2, "sampled combo has two cards")
		_assert(not opponent_range.is_blocked(combo[0]) and not opponent_range.is_blocked(combo[1]), "sampled combo avoids blockers")

	var before := opponent_range.normalized_weights()
	var observation := {"actor": 1, "action": "raise", "raise_to": 300, "to_call_before": 0, "board_before": board, "big_blind": 20}
	_assert(opponent_range.update_from_observation(observation, 1), "valid observation applies")
	var after := opponent_range.normalized_weights()
	_assert(float(after["72o"]) < float(before["72o"]), "aggression reduces junk support")
	_assert(float(after["72o"]) > 0.0, "bluff support is never zeroed")
	_assert(float(after["AA"]) / maxf(0.0001, float(after["72o"])) > float(before["AA"]) / maxf(0.0001, float(before["72o"])), "aggression shifts support towards value")
	opponent_range.update_from_observation(observation, 1)
	var after_two := opponent_range.normalized_weights()
	_assert(float(after_two["72o"]) < float(after["72o"]) + 0.0001, "multiple observations accumulate rather than overwrite")
	_assert(not opponent_range.update_from_observation(observation, 2), "other actors are ignored")
	_assert(not opponent_range.update_from_observation({"actor": 1}, 1), "missing action is ignored")
	_assert(not opponent_range.update_from_observation("junk", 1), "non-dictionary observation is ignored")

	var fully_blocked := {}
	for card in CardUtil.full_deck():
		fully_blocked[CardUtil.card_key(card)] = true
	_assert(opponent_range.sample_combo(rng, fully_blocked).size() == 0, "invalid/empty range fails safely")

func _test_monte_carlo() -> void:
	var hero := [c(14, "S"), c(14, "H")]
	var board := [c(2, "S"), c(7, "D"), c(9, "C")]
	var legacy := MonteCarlo.estimate_equity(hero, board, 1, 50)
	_assert(legacy.equity >= 0.0 and legacy.equity <= 1.0, "legacy estimate_equity API stays in 0..1")
	_assert(legacy.has("win_rate") and legacy.has("tie_rate") and legacy.has("equity"), "legacy estimate_equity keys preserved")

	var range_a := OpponentRange.new(hero, board)
	var range_b := OpponentRange.new(hero, board)
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 123
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 123
	var worlds_a := MonteCarlo.sample_worlds(hero, board, [range_a], 20, rng_a)
	var worlds_b := MonteCarlo.sample_worlds(hero, board, [range_b], 20, rng_b)
	_assert(worlds_a.size() == 20, "seeded sampling produces worlds")
	_assert(JSON.stringify(worlds_a) == JSON.stringify(worlds_b), "seeded sampling is reproducible")

	var joint := MonteCarlo.sample_worlds(hero, board, [OpponentRange.new(hero, board), OpponentRange.new(hero, board)], 25, rng_a)
	for world in joint:
		var used := {}
		for card in hero + board:
			used[CardUtil.card_key(card)] = true
		for combo in world.opponents:
			_assert(combo.size() == 2, "joint sample has two cards per opponent")
			_assert(CardUtil.card_key(combo[0]) != CardUtil.card_key(combo[1]), "opponent combo is not duplicated")
			for card in combo:
				_assert(not used.has(CardUtil.card_key(card)), "joint sampling never reuses a card")
				used[CardUtil.card_key(card)] = true

	var medium_hero := [c(12, "S"), c(11, "D")]
	var tight := OpponentRange.new(medium_hero, board)
	for key in tight.class_weights:
		tight.class_weights[key] = 1.0 if key == "AA" else 0.0
	var wide := OpponentRange.new(medium_hero, board)
	var tight_rng := RandomNumberGenerator.new()
	tight_rng.seed = 77
	var wide_rng := RandomNumberGenerator.new()
	wide_rng.seed = 77
	var tight_equity := MonteCarlo.estimate_equity_weighted(medium_hero, board, [tight], 200, tight_rng)
	var wide_equity := MonteCarlo.estimate_equity_weighted(medium_hero, board, [wide], 200, wide_rng)
	_assert(float(tight_equity.equity) < float(wide_equity.equity), "tight weighted range lowers hero equity")

	var tie_equity := MonteCarlo.estimate_equity([c(2, "H"), c(3, "S")], [c(14, "C"), c(13, "D"), c(12, "H"), c(11, "S"), c(10, "C")], 1, 40, rng_b)
	_assert(is_equal_approx(float(tie_equity.tie_rate), 0.5), "board-locked straight splits the pot in half")
	_assert(is_equal_approx(float(tie_equity.equity), 0.5), "tie share is preserved")

func _mass_key(cards: Array) -> String:
	var a := CardUtil.card_key(cards[0])
	var b := CardUtil.card_key(cards[1])
	return (a if a < b else b) + "|" + (b if a < b else a)

func _test_range_regressions() -> void:
	var hero := [c(2, "C"), c(3, "D")]
	var p1 := OpponentRange.new(hero, [])
	var p2 := OpponentRange.new(hero, [])
	p1.set_combo_masses({_mass_key([c(14, "S"), c(13, "S")]): 1.0, _mass_key([c(12, "S"), c(11, "S")]): 1.0})
	p2.set_combo_masses({_mass_key([c(14, "S"), c(10, "S")]): 1.0, _mass_key([c(9, "S"), c(8, "S")]): 1.0})
	var rng := _seeded(741)
	var worlds := MonteCarlo.sample_worlds(hero, [], [p1, p2], 1200, rng)
	_assert(worlds.size() == 1200, "joint restricted ranges retain requested worlds")
	var assignments := {}
	for world in worlds:
		var assignment := _mass_key(world.opponents[0]) + "/" + _mass_key(world.opponents[1])
		assignments[assignment] = int(assignments.get(assignment, 0)) + 1
	_assert(assignments.size() == 3, "collision rejection leaves exactly three joint assignments")
	for assignment in assignments:
		_assert(absf(float(assignments[assignment]) / 1200.0 - 1.0 / 3.0) < 0.05, "joint assignments are equiprobable")

	var blocked_hero := [c(14, "C"), c(2, "D")]
	var prior := OpponentRange.new(blocked_hero, [])
	for key in prior.class_weights:
		prior.class_weights[key] = 1.0 if key == "AA" or key == "KK" else 0.0
	var aa := 0
	for _i in range(900):
		var combo := prior.sample_combo(rng)
		if StartingHandTable.class_key(combo) == "AA":
			aa += 1
	_assert(absf(float(aa) / 900.0 - 1.0 / 3.0) < 0.07, "blockers leave three AA versus six KK masses")

	var range_call := OpponentRange.new(hero, [c(7, "H"), c(8, "H"), c(9, "C")])
	var range_all_in_call := OpponentRange.new(hero, [c(7, "H"), c(8, "H"), c(9, "C")])
	var call_obs := {"actor": 1, "action": "call", "to_call_before": 50, "paid": 50, "pot_before": 150, "board_before": [c(7, "H"), c(8, "H"), c(9, "C")], "big_blind": 20}
	var all_in_call := call_obs.duplicate(true)
	all_in_call.action = "all_in"
	all_in_call.increased_current_bet = false
	all_in_call.is_all_in_call = true
	_assert(range_call.update_from_observation(call_obs, 1) and range_all_in_call.update_from_observation(all_in_call, 1), "calls and short all-in calls are accepted")
	_assert(is_equal_approx(float(range_call.normalized_weights()["AA"]), float(range_all_in_call.normalized_weights()["AA"])), "all-in call uses call likelihood")
	_assert(not range_call.update_from_observation({"actor": 1, "action": "teleport"}, 1), "unknown action does not update")

func _test_action_ev_fixtures() -> void:
	var ace_high := {"rank_value": 8, "tiebreakers": [14], "best_cards": []}
	var pair_low := {"rank_value": 1, "tiebreakers": [13], "best_cards": []}
	var high_card := {"rank_value": 0, "tiebreakers": [10], "best_cards": []}
	_assert(is_equal_approx(ActionEV.compute_payout([100, 200, 200], [true, true, true], [ace_high, pair_low, high_card], 0), 300.0), "short-stack side pot pays the main pot")
	_assert(is_equal_approx(ActionEV.compute_payout([100], [true], [ace_high], 0), 100.0), "all opponents fold returns the whole pot")
	var tied := {"rank_value": 4, "tiebreakers": [12]}
	_assert(is_equal_approx(ActionEV.compute_payout([100, 100], [true, true], [tied, tied], 0), 100.0), "chop shares the pot exactly")
	_assert(is_equal_approx(ActionEV.compute_payout([100, 50], [false, true], [{}, pair_low], 0), 0.0), "folded hero is never paid")

func _river_game(board: Array, hero: Array, opponent: Array, hero_bet: int, opponent_bet: int, hero_stack: int, opponent_stack: int) -> PokerRound:
	var game := PokerRound.new()
	game.shuffle_rng.seed = 3
	game.start_new_match(1, "medium")
	game.community_cards = board
	game.stage = TableState.STAGE_RIVER
	game.players[0].hole_cards = hero
	game.players[1].hole_cards = opponent
	game.players[0].stack = hero_stack
	game.players[1].stack = opponent_stack
	game.players[0].current_bet = hero_bet
	game.players[1].current_bet = opponent_bet
	game.players[0].total_bet = hero_bet
	game.players[1].total_bet = opponent_bet
	game.players[0].status = TableState.STATUS_ACTIVE
	game.players[1].status = TableState.STATUS_ACTIVE
	game.current_bet = maxi(hero_bet, opponent_bet)
	game.min_raise = game.big_blind
	game.current_player_index = 0
	return game

func _has_candidate(candidates: Array, action_type: String) -> bool:
	for candidate in candidates:
		if str(candidate.get("action_type", "")) == action_type:
			return true
	return false

func _candidate_for(candidates: Array, action_type: String) -> Dictionary:
	for candidate in candidates:
		if str(candidate.get("action_type", "")) == action_type:
			return candidate
	return {}

func _test_action_ev_game() -> void:
	var board := [c(2, "C"), c(3, "D"), c(4, "H"), c(9, "S"), c(11, "D")]
	var hero := [c(14, "H"), c(14, "S")]
	var opponent := [c(13, "H"), c(13, "S")]
	var profile := AiDecision.profile_for_difficulty("hard")
	var worlds := [{"opponents": [opponent], "board": board}]

	var called_game := _river_game(board, hero, opponent, 0, 100, 1000, 900)
	var called := ActionEV.evaluate(called_game, 0, profile, {"worlds": worlds, "response_model": ActionEV.RESPONSE_ALWAYS_CALL})
	_assert(float(_candidate_for(called.candidates, "call").get("ev", -1.0)) == 100.0, "call EV equals the opponent's dead money when hero always wins")
	_assert(float(_candidate_for(called.candidates, "all_in").get("ev", -1.0)) == 1000.0, "all-in EV counts only the matched opponent chips")
	_assert(int(called.world_count) == 1, "injected worlds are used")

	var folded := ActionEV.evaluate(called_game, 0, profile, {"worlds": worlds, "response_model": ActionEV.RESPONSE_ALWAYS_FOLD})
	_assert(float(_candidate_for(folded.candidates, "raise").get("ev", -1.0)) == 100.0, "raise EV with all opponents folding is the dead money")
	_assert(float(_candidate_for(folded.candidates, "fold").get("ev", -1.0)) == 0.0, "fold baseline is zero")

	var no_bet_game := _river_game(board, hero, opponent, 0, 0, 1000, 1000)
	var no_bet := ActionEV.evaluate(no_bet_game, 0, profile, {"worlds": worlds, "response_model": ActionEV.RESPONSE_ALWAYS_CALL})
	_assert(not _has_candidate(no_bet.candidates, "fold"), "fold is suppressed when a free check exists")
	_assert(_has_candidate(no_bet.candidates, "check"), "free check is offered")

	var all_in_caller := _river_game(board, hero, opponent, 0, 100, 1000, 0)
	all_in_caller.players[1].status = TableState.STATUS_ALL_IN
	all_in_caller.players[1].stack = 0
	var caller := ActionEV.evaluate(all_in_caller, 0, profile, {"worlds": worlds, "response_model": ActionEV.RESPONSE_ALWAYS_FOLD})
	_assert(not _has_candidate(caller.candidates, "raise"), "no raise into a dry side pot")
	var caller_call := _candidate_for(caller.candidates, "call")
	_assert(not caller_call.is_empty(), "all-in caller can still call")
	_assert(float(caller_call.get("ev", -1.0)) == 100.0, "all-in opponents cannot fold and their chips stay matched")
	for candidate in called.candidates:
		_assert(not is_nan(float(candidate.get("ev", 0.0))) and not is_inf(float(candidate.get("ev", 0.0))), "candidate EVs are finite")

func _test_response_uses_current_board_only() -> void:
	var current_board := [c(2, "C"), c(7, "D"), c(9, "S")]
	var hero := [c(14, "H"), c(14, "S")]
	var opponent := [c(13, "H"), c(12, "H")]
	var strong_runout := [c(2, "C"), c(7, "D"), c(9, "S"), c(13, "S"), c(12, "D")]
	var weak_runout := [c(2, "C"), c(7, "D"), c(9, "S"), c(3, "H"), c(4, "C")]
	_assert(HandEvaluator.compare_results(HandEvaluator.evaluate(opponent + strong_runout), HandEvaluator.evaluate(opponent + weak_runout)) > 0, "fixture runouts really change the opponent's final hand")
	var game := _river_game(current_board, hero, opponent, 0, 0, 1000, 1000)
	game.stage = TableState.STAGE_FLOP
	var profile := AiDecision.profile_for_difficulty("hard")
	var strong_world := ActionEV.evaluate(game, 0, profile, {
		"worlds": [{"opponents": [opponent], "board": strong_runout}],
		"response_model": ActionEV.RESPONSE_HEURISTIC,
		"rng": _seeded(321)
	})
	var weak_world := ActionEV.evaluate(game, 0, profile, {
		"worlds": [{"opponents": [opponent], "board": weak_runout}],
		"response_model": ActionEV.RESPONSE_HEURISTIC,
		"rng": _seeded(321)
	})
	var strong_raise := _candidate_for(strong_world.candidates, "raise")
	var weak_raise := _candidate_for(weak_world.candidates, "raise")
	_assert(not strong_raise.is_empty(), "raise candidate exists on the flop")
	_assert(is_equal_approx(float(strong_raise.get("fold_rate", -1.0)), float(weak_raise.get("fold_rate", -2.0))), "response folding never reads the sampled future board")

func _test_decision_legal_and_bounded() -> void:
	var stages := [
		[TableState.STAGE_FLOP, 3],
		[TableState.STAGE_TURN, 4],
		[TableState.STAGE_RIVER, 5]
	]
	for difficulty in ["simple", "medium", "hard"]:
		for stage in stages:
			var game := PokerRound.new()
			game.shuffle_rng.seed = 31
			game.start_new_match(2, difficulty)
			game.community_cards = game.deck.draw(int(stage[1]))
			game.stage = stage[0]
			game.current_bet = 0
			game.min_raise = game.big_blind
			for player in game.players:
				player.current_bet = 0
				player.total_bet = 0
				player.status = TableState.STATUS_ACTIVE
			game.current_player_index = 1
			var rng := RandomNumberGenerator.new()
			rng.seed = 99
			var decision := AiDecision.decide(game, 1, rng)
			var legal := game.get_legal_actions(1)
			_assert(legal.actions.has(str(decision.get("action_type", ""))), "decision is legal for %s/%s" % [difficulty, stage[0]])
			_assert(decision.has("decision_label"), "decision keeps a readable label")
			_assert(decision.has("analysis"), "decision exposes analysis diagnostics")
			if difficulty == "hard":
				var analysis: Dictionary = decision.get("analysis", {})
				var action_ev: Dictionary = analysis.get("action_ev", {})
				_assert(int(action_ev.get("world_count", 0)) > 0, "hard postflop samples MonteCarlo worlds")
				var equity := float(action_ev.get("equity", -1.0))
				_assert(equity >= 0.0 and equity <= 1.0, "hard postflop equity is bounded")

func _test_preset_tendencies() -> void:
	var samples := 240
	var aggressive := _reraise_rate("TightAggressive", samples)
	var passive := _reraise_rate("CallingStation", samples)
	var loose := _style_rate("LooseAggressive", samples)
	var tight := _style_rate("Rock", samples)
	var station := _style_rate("CallingStation", samples)
	_assert(float(aggressive) > float(passive), "aggressive preset reraises more than the calling station")
	_assert(float(loose.continue_rate) > float(tight.continue_rate), "loose preset continues more than the rock")
	_assert(float(loose.raise_rate) > float(tight.raise_rate), "loose-aggressive preset raises more than the rock")
	_assert(float(loose.raise_rate) > float(station.raise_rate) + 0.10, "calling station enters more passively than loose-aggressive")
	_assert(float(station.continue_rate) - float(station.raise_rate) > float(loose.continue_rate) - float(loose.raise_rate), "calling station actually calls more often")

func _style_rate(profile_name: String, samples: int) -> Dictionary:
	var raises := 0
	var continues := 0
	for i in range(samples):
		var game := PokerRound.new()
		game.shuffle_rng.seed = 7000 + i
		game.start_new_match(1, "hard")
		game.players[0].personality = PersonalityProfiles.get_profile(profile_name)
		game.players[0].difficulty = "hard"
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + i
		var decision := AiDecision.decide(game, 0, rng)
		var action := str(decision.get("action_type", ""))
		if action == TableState.ACTION_RAISE or action == TableState.ACTION_ALL_IN:
			raises += 1
		if action == TableState.ACTION_CALL or action == TableState.ACTION_RAISE or action == TableState.ACTION_ALL_IN:
			continues += 1
	return {
		"raise_rate": float(raises) / float(samples),
		"continue_rate": float(continues) / float(samples)
	}

## Reraise tendency when facing a voluntary raise: aggression, not looseness,
## should drive this decision.
func _reraise_rate(profile_name: String, samples: int) -> float:
	var raises := 0
	for i in range(samples):
		var game := PokerRound.new()
		game.shuffle_rng.seed = 7700 + i
		game.start_new_match(1, "hard")
		game.current_bet = 60
		game.players[0].current_bet = 60
		game.players[0].total_bet = 60
		game.players[0].last_action = "Raise 60"
		game.public_action_history.append({
			"actor": 0,
			"street": TableState.STAGE_PREFLOP,
			"action": TableState.ACTION_RAISE,
			"raise_to": 60,
			"increased_current_bet": true,
			"big_blind": 20,
			"board_before": []
		})
		game.current_player_index = 1
		game.players[1].personality = PersonalityProfiles.get_profile(profile_name)
		game.players[1].difficulty = "hard"
		var rng := RandomNumberGenerator.new()
		rng.seed = 9800 + i
		var decision := AiDecision.decide(game, 1, rng)
		var action := str(decision.get("action_type", ""))
		if action == TableState.ACTION_RAISE or action == TableState.ACTION_ALL_IN:
			raises += 1
	return float(raises) / float(samples)

func _test_final_boundaries() -> void:
	var preflop := PokerRound.new()
	preflop.start_new_match(2, "hard")
	_assert(preflop.apply_action("raise", 60), "button opens in three-seat fixture")
	_assert(preflop.apply_action("raise", 180), "small blind reraises")
	var bb := StartingHandTable.context_from_game(preflop, 2)
	_assert(not bool(bb.closing_action), "BB does not close while earlier raiser must respond to reraise")
	_assert(int(bb.raises_before) == 2, "public history distinguishes open and reraise")
	_assert(float(StartingHandTable.context_from_game(preflop, 0).relative_position) > float(bb.relative_position), "button has more positional advantage than BB")
	var depths := PokerRound.new()
	depths.start_new_match(2, "hard")
	depths.players[0].stack = 1000
	depths.players[0].current_bet = 0
	depths.players[1].stack = 30
	depths.players[1].current_bet = 10
	depths.players[2].stack = 980
	depths.players[2].current_bet = 20
	_assert(is_equal_approx(float(StartingHandTable.context_from_game(depths, 0).effective_stack_bb), 50.0), "short third player cannot erase deep side-pot depth")
	depths.players[2].status = TableState.STATUS_FOLDED
	var shallow := StartingHandTable.context_from_game(depths, 0)
	_assert(int(shallow.live_players) == 2 and not bool(shallow.is_heads_up), "folded seat is not live but table was dealt multiway")
	_assert(is_equal_approx(float(shallow.effective_stack_bb), 2.0), "folded deep stack no longer contributes effective depth")
	depths.players[2].status = TableState.STATUS_OUT
	_assert(bool(StartingHandTable.context_from_game(depths, 0).is_heads_up), "two surviving seats support heads-up after elimination")

	var board := [c(2, "S"), c(7, "S"), c(9, "D")]
	var hero := [c(3, "C"), c(4, "H")]
	var features := {}
	var range_a := OpponentRange.new(hero, board, {}, features)
	var range_b := OpponentRange.new(hero, board, {}, features)
	var observation := {"actor": 1, "action": "raise", "increased_current_bet": true, "paid": 70, "raise_to": 70, "pot_before": 100, "big_blind": 20, "board_before": board}
	_assert(range_a.update_from_observation(observation, 1), "raise updates combo posterior")
	_assert(range_a.combo_weight(c(14, "S"), c(13, "S")) > range_a.combo_weight(c(14, "H"), c(13, "H")), "same AKs class separates actual spade draw from hearts")
	var feature_count: int = features.values()[0].size()
	var shove := observation.duplicate(true)
	shove.action = "all_in"
	_assert(range_b.update_from_observation(shove, 1), "all-in raise updates posterior")
	_assert(range_a.combo_weights == range_b.combo_weights, "all-in raise and ordinary raise have identical evidence at same price")
	_assert(features.values()[0].size() == feature_count, "opponents reuse board/combo feature cache")
	_assert(range_a.combo_weight(c(2, "S"), c(14, "S")) == 0.0, "board duplicates have zero legal mass")
	var original_history := OpponentRange.new(hero, board)
	var future_filtered := OpponentRange.new(hero, board + [c(13, "C")])
	original_history.update_from_observation(observation, 1)
	future_filtered.update_from_observation(observation, 1)
	var original_ratio := original_history.combo_weight(c(14, "S"), c(13, "S")) / original_history.combo_weight(c(14, "H"), c(13, "H"))
	var future_ratio := future_filtered.combo_weight(c(14, "S"), c(13, "S")) / future_filtered.combo_weight(c(14, "H"), c(13, "H"))
	_assert(is_equal_approx(original_ratio, future_ratio), "future blockers filter support without explaining old actions using future board")
	var neutral := OpponentRange.new(hero, board)
	neutral.set_combo_masses({})
	_assert(neutral.is_empty(), "empty posterior reports no modeled mass")
	var seen := {}
	for i in range(60):
		var combo := neutral.sample_combo(_seeded(i + 300))
		_assert(combo.size() == 2 and not neutral.is_blocked(combo[0]) and not neutral.is_blocked(combo[1]), "empty posterior fallback stays legal")
		seen[_mass_key(combo)] = true
	_assert(seen.size() > 30, "neutral fallback is not fixed to one holding")
	_assert(ActionEV.world_count_for({}, {"world_count": NAN}) == 1, "NaN world count falls back")
	_assert(ActionEV.world_count_for({}, {"world_count": 1e100}) == ActionEV.MAX_WORLDS, "huge finite budget clamps before integer conversion")

	var river := [c(2, "C"), c(3, "D"), c(4, "H"), c(9, "S"), c(11, "D")]
	var aces := [c(14, "H"), c(14, "S")]
	var kings := [c(13, "H"), c(13, "S")]
	var queens := [c(12, "H"), c(12, "S")]
	var short := PokerRound.new()
	short.start_new_match(2, "hard")
	short.stage = TableState.STAGE_RIVER
	short.community_cards = river
	short.current_player_index = 0
	short.current_bet = 200
	short.min_raise = 100
	for i in range(3):
		short.players[i].hole_cards = [aces, kings, queens][i]
		short.players[i].current_bet = [0, 200, 0][i]
		short.players[i].total_bet = [50, 250, 50][i]
		short.players[i].stack = [50, 750, 950][i]
		short.players[i].status = TableState.STATUS_ACTIVE
		short.players[i].has_acted = i == 1
	var worlds := [{"opponents": [kings, queens], "board": river}]
	var called := ActionEV.evaluate(short, 0, {}, {"worlds": worlds, "response_model": ActionEV.RESPONSE_ALWAYS_CALL})
	_assert(float(_candidate_for(called.candidates, "call").ev) == 250.0, "short caller wins 300 main pot minus 50 new cost, not deep side pot")
	_assert(ActionEV._action_target(short, 0, {"action_type": "all_in"}) == 200, "short all-in cannot lower other players' 200 call target")
	var folded := ActionEV.evaluate(short, 0, {}, {"worlds": worlds, "response_model": ActionEV.RESPONSE_ALWAYS_FOLD})
	var fold_call := _candidate_for(folded.candidates, "call")
	_assert(float(fold_call.ev) == 200.0 and float(fold_call.fold_rate) == 0.5, "pending opponent can fold original wager even after hero only calls")
	_assert(AiDecision._candidate_category(short, {"action_type": "all_in", "is_aggressive": false}) == "call", "short all-in is a passive category")
	var best := HandEvaluator.evaluate(aces + river)
	var lesser := HandEvaluator.evaluate(kings + river)
	_assert(ActionEV.compute_payout([120, 60], [true, false], [best, lesser], 0) - 80.0 == 100.0, "all-fold payout includes uncalled refund without double-deducting sunk cost")
	_assert(ActionEV.compute_payout([100, 250, 250, 50], [true, true, true, false], [best, lesser, lesser, {}], 0) == 350.0, "folded dead money belongs in eligible main-pot layers")

	var sizes := _river_game(river, aces, kings, 0, 100, 200, 900)
	var sized := ActionEV.evaluate(sizes, 0, {}, {"worlds": [{"opponents": [kings], "board": river}]})
	var costs := {}
	for candidate in sized.candidates:
		if candidate.action_type == "fold":
			continue
		_assert(not costs.has(candidate.cost), "same maximum raise/all-in investment appears once")
		costs[candidate.cost] = true
	sizes.players[0].stack = 1000
	var large := ActionEV.evaluate(sizes, 0, {}, {"worlds": [{"opponents": [kings], "board": river}]})
	var found_pot_raise := false
	for candidate in large.candidates:
		if candidate.action_type == "raise" and int(candidate.amount) == 300:
			found_pot_raise = true
	_assert(found_pot_raise, "pot raise adds 200 pot-after-call to 100 call target")
	var one_size := [{"action_type": "check", "amount": 0, "ev": 0.0}, {"action_type": "raise", "amount": 100, "ev": 0.0}]
	var many_sizes := one_size.duplicate(true)
	many_sizes.append({"action_type": "raise", "amount": 200, "ev": 0.0})
	many_sizes.append({"action_type": "all_in", "amount": 0, "ev": 0.0, "is_aggressive": true})
	var passive := PersonalityProfiles.get_profile("CallingStation")
	var aggressive := PersonalityProfiles.get_profile("LooseAggressive")
	var passive_raises := 0
	var aggressive_raises := 0
	for i in range(1000):
		var a := AiDecision._choose_candidate(sizes, one_size, passive, _seeded(i + 10000))
		var b := AiDecision._choose_candidate(sizes, many_sizes, passive, _seeded(i + 10000))
		_assert((a.action_type == "check") == (b.action_type == "check"), "adding sizes preserves seeded category probability")
		passive_raises += int(a.action_type != "check")
		var ag := AiDecision._choose_candidate(sizes, many_sizes, aggressive, _seeded(i + 10000))
		aggressive_raises += int(ag.action_type != "check")
	_assert(aggressive_raises > passive_raises + 70, "aggressive style remains measurably distinct within equal-EV categories")
