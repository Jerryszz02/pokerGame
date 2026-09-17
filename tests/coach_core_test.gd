extends SceneTree
## Coach core tests: safe decision snapshots, finite-depth search accounting,
## hidden-card/RNG isolation, paired review, cancellation and hell legality.
## All sampling uses explicit seeds or explicit worlds so the checks are
## deterministic and independent of the real hidden deal.

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_capture_restore_legal_rights()
	_test_context_json_roundtrip_privacy()
	_test_invalid_and_old_contexts()
	_test_replay_context_is_before_action()
	_test_failed_action_has_no_context()
	_test_search_is_hidden_card_and_deck_independent()
	_test_search_does_not_mutate_state_or_rng()
	_test_tie_probability_versus_split_equity()
	_test_actual_unusual_raise_and_illegal_input()
	_test_future_streets_and_actions()
	_test_sidepot_refund_and_split()
	_test_cancellation_and_empty_sampling()
	_test_hell_legal_actions()
	_test_strict_schema_and_live_budget()
	if failures == 0:
		print("Coach core tests passed.")
	else:
		push_error("%d coach core tests failed." % failures)
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _test_strict_schema_and_live_budget() -> void:
	var game := _flop_table(1, 1000)
	var context := CoachContext.capture(game, 0)
	_assert(not FiniteSearch.evaluate(game, 1).available, "search cannot silently replace the current actor")
	for key in ["kind", "public_action_history", "legal_actions", "to_call"]:
		var incomplete := context.duplicate(true)
		incomplete.erase(key)
		_assert(CoachContext.restore(incomplete) == null, "missing %s must not invent a decision context" % key)
	for key in ["has_acted", "last_action_bet", "last_action"]:
		var incomplete := context.duplicate(true)
		incomplete.players[0].erase(key)
		_assert(CoachContext.restore(incomplete) == null, "missing reopening field %s is rejected" % key)
	var corrupt := context.duplicate(true)
	corrupt.to_call += 1
	_assert(CoachContext.restore(corrupt) == null, "cached price must match rules")
	corrupt = context.duplicate(true)
	corrupt.players[0].hole_cards[0] = corrupt.community_cards[0]
	_assert(CoachContext.restore(corrupt) == null, "duplicate visible cards rejected")
	corrupt = context.duplicate(true)
	corrupt.stage = TableState.STAGE_RIVER
	_assert(CoachContext.restore(corrupt) == null, "street and board must agree")
	var cancellation := CoachCancellation.new()
	cancellation.cancel()
	_assert(not CoachAnalysis.live(context, {"cancellation": cancellation}).available, "cancelled live job cannot produce advice")
	_assert(not CoachAnalysis.live(context, {"max_worlds": 0}).available, "zero requested samples are unavailable")
	var live := CoachAnalysis.live(context, {"seed": 23, "max_worlds": 96, "time_budget_ms": 5000})
	_assert(live.available and int(live.world_count) == 96, "live has its own budget beyond 64 search worlds")
	var one := CoachAnalysis.review(context, {"action_type": TableState.ACTION_CHECK}, {"seed": 23, "max_worlds": 1, "time_budget_ms": 5000})
	_assert(one.available and one.close and not one.uncertainty_available, "one world cannot establish decision certainty")
	var timeout := FiniteSearch.evaluate(game, 0, {"seed": 23, "max_worlds": 64, "time_budget_ms": 1})
	for candidate in timeout.get("candidates", []):
		_assert(candidate.samples == timeout.world_count, "timeout never includes a partial candidate batch")
	var invalid_world := {"opponents": [[game.players[0].hole_cards[0], c(2, "H")]], "board": game.community_cards + [c(4, "C"), c(5, "D")]}
	_assert(FiniteSearch._normalize_worlds([invalid_world], 1, game.players[0].hole_cards, game.community_cards).is_empty(), "sample world cannot reuse a hero card")

func c(rank: int, suit: String) -> Dictionary:
	return CardUtil.make_card(rank, suit)

func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _candidate_for(candidates: Array, action_type: String) -> Dictionary:
	for candidate in candidates:
		if str(candidate.get("action_type", "")) == action_type:
			return candidate
	return {}

func _last_action_frame_index(game) -> int:
	var found := -1
	for i in range(game._hand_frames.size()):
		if str(game._hand_frames[i].get("type", "")) == "action":
			found = i
	return found

func _context_count(game) -> int:
	var total := 0
	for frame in game._hand_frames:
		if frame.has("decision_context"):
			total += 1
	return total

## Deterministic 3-way flop table with deep stacks. The same seed reproduces
## the same hero cards and public board.
func _flop_table(ai_count: int, stack: int, difficulty: String = "medium") -> PokerRound:
	var game := PokerRound.new()
	game.shuffle_rng.seed = 4242
	game.start_new_match(ai_count, difficulty)
	game.community_cards = game.deck.draw(3)
	game.stage = TableState.STAGE_FLOP
	game.current_bet = 0
	game.min_raise = game.big_blind
	for player in game.players:
		player.stack = stack
		player.current_bet = 0
		player.total_bet = 0
		player.has_acted = false
		player.last_action_bet = 0
		player.last_action = ""
		player.status = TableState.STATUS_ACTIVE
	game.current_player_index = 0
	game.public_action_history = []
	return game

func _test_capture_restore_legal_rights() -> void:
	# Reproduce the short-all-in reopening spot: a player who already acted
	# must keep the no-reraise right after a JSON round trip.
	var game := PokerRound.new()
	game.start_new_match(3, "simple")
	_assert(game.apply_action(TableState.ACTION_RAISE, 100), "opener can raise")
	_assert(game.apply_action(TableState.ACTION_CALL), "button can call")
	game.players[1].stack = 140
	_assert(game.apply_action(TableState.ACTION_ALL_IN), "short all-in raise")
	_assert(game.apply_action(TableState.ACTION_CALL), "big blind can call")
	_assert(game.current_player_index == 3, "action returns to the opener")
	var live_legal := game.get_legal_actions(3)
	_assert(not live_legal.actions.has(TableState.ACTION_RAISE), "fixture really closed raising")

	var context := CoachContext.capture(game, 3)
	_assert(not context.is_empty(), "capture returns a context")
	var parsed = JSON.parse_string(JSON.stringify(context))
	var restored = CoachContext.restore(parsed)
	_assert(restored != null, "restore accepts an integral-float JSON context")
	if restored == null:
		return
	var restored_legal: Dictionary = restored.get_legal_actions(3)
	_assert(restored_legal.actions == live_legal.actions, "legal actions survive restore")
	_assert(not restored_legal.actions.has(TableState.ACTION_RAISE), "short-all-in reopening right is preserved")
	_assert(int(restored.get_to_call(3)) == int(game.get_to_call(3)), "to-call is preserved")
	_assert(int(restored.current_bet) == int(game.current_bet), "current bet is preserved")
	_assert(int(restored.min_raise) == int(game.min_raise), "min raise is preserved")
	for i in range(game.players.size()):
		_assert(int(restored.players[i].stack) == int(game.players[i].stack), "stack restored for seat %d" % i)
		_assert(int(restored.players[i].current_bet) == int(game.players[i].current_bet), "current bet restored for seat %d" % i)
		_assert(bool(restored.players[i].has_acted) == bool(game.players[i].has_acted), "has_acted restored for seat %d" % i)
		_assert(int(restored.players[i].last_action_bet) == int(game.players[i].last_action_bet), "last_action_bet restored for seat %d" % i)

func _test_context_json_roundtrip_privacy() -> void:
	var game := _flop_table(2, 1000)
	var context := CoachContext.capture(game, 0)
	_assert(is_equal_approx(float(context.version), 1.0), "context carries a version marker")
	_assert(int(context.hero) == 0, "context records the hero index")
	_assert(int(context.hand_number) == int(game.hand_number), "context records the hand number")
	_assert(int(context.big_blind) == int(game.big_blind), "context records blinds")
	_assert((context.community_cards as Array).size() == 3, "context records the public board")
	_assert((context.public_action_history as Array).is_empty(), "context records public history")
	for i in range(game.players.size()):
		var entry: Dictionary = context.players[i]
		_assert(not entry.has("personality"), "player entry must not leak personality")
		_assert(not entry.has("last_action_note"), "player entry must not leak notes")
		if i == 0:
			_assert((entry.hole_cards as Array).size() == 2, "hero keeps own hole cards")
		else:
			_assert((entry.hole_cards as Array).is_empty(), "opponent hole cards are never stored")
	# Deep copy: mutating the snapshot must not touch the live game.
	context.players[0].hole_cards.append(c(14, "S"))
	context.community_cards[0].rank = 2
	_assert(game.players[0].hole_cards.size() == 2, "context is a deep copy of hole cards")
	_assert(CoachContext.restore(context) == null, "three-card corrupted context is rejected")
	context = CoachContext.capture(game, 0)
	var parsed = JSON.parse_string(JSON.stringify(context))
	var restored = CoachContext.restore(parsed)
	_assert(restored != null, "round-tripped context restores")
	if restored != null:
		_assert((restored.players[1].hole_cards as Array).is_empty(), "opponent cards stay hidden after restore")
		_assert(restored.deck.cards.is_empty(), "restored context has no future deck")

func _test_invalid_and_old_contexts() -> void:
	_assert(CoachContext.restore({}) == null, "empty context is unavailable")
	var context := CoachContext.capture(_flop_table(2, 1000), 0)
	var old := context.duplicate(true)
	old["version"] = 0
	_assert(CoachContext.restore(old) == null, "old version marker is unavailable")
	var unversioned := context.duplicate(true)
	unversioned.erase("version")
	_assert(CoachContext.restore(unversioned) == null, "unversioned data is unavailable")
	var fractional := context.duplicate(true)
	fractional.players[1].stack = 12.5
	_assert(CoachContext.restore(fractional) == null, "non-integral floats are rejected")
	var bad_status := context.duplicate(true)
	bad_status.players[1].status = "zombie"
	_assert(CoachContext.restore(bad_status) == null, "unknown status is rejected")
	var bad_card := context.duplicate(true)
	bad_card.community_cards[0].rank = 99
	_assert(CoachContext.restore(bad_card) == null, "impossible card rank is rejected")

func _test_replay_context_is_before_action() -> void:
	var game := PokerRound.new()
	game.shuffle_rng.seed = 7
	game.start_new_match(2, "simple")
	var actor := game.current_player_index
	var before := CoachContext.capture(game, actor)
	_assert(game.apply_action(TableState.ACTION_CALL, 0), "recorded action succeeds")
	var index := _last_action_frame_index(game)
	_assert(index >= 0, "action frame exists")
	_assert(game._hand_frames[index].has("decision_context"), "action frame carries a decision context")
	_assert(game._hand_frames[index].decision_context == before, "recorded context equals the live before-action capture")
	var steps := 0
	while game.stage != TableState.STAGE_HAND_OVER and steps < 60:
		steps += 1
		var next_actor: int = int(game.current_player_index)
		if next_actor < 0:
			break
		var action := TableState.ACTION_CHECK if int(game.get_to_call(next_actor)) == 0 else TableState.ACTION_CALL
		if not game.apply_action(action, 0):
			break
	_assert(game._hand_frames[index].decision_context == before, "later cards never rewrite the recorded context")

func _test_failed_action_has_no_context() -> void:
	var game := PokerRound.new()
	game.shuffle_rng.seed = 11
	game.start_new_match(1, "simple")
	var before := _context_count(game)
	_assert(not game.apply_action(TableState.ACTION_CHECK, 0), "illegal check fails")
	_assert(not game.apply_action(TableState.ACTION_RAISE, 5), "illegal raise fails")
	_assert(_context_count(game) == before, "failed actions never attach a decision context")

func _test_search_is_hidden_card_and_deck_independent() -> void:
	var a := _flop_table(2, 1000)
	var b := _flop_table(2, 1000)
	# Same visible state, different real opponent cards and a different deck.
	a.players[1].hole_cards = [c(13, "H"), c(12, "H")]
	b.players[1].hole_cards = [c(2, "H"), c(3, "H")]
	a.players[2].hole_cards = [c(11, "H"), c(10, "H")]
	b.players[2].hole_cards = [c(4, "H"), c(5, "H")]
	b.deck.cards = b.deck.cards.duplicate()
	b.deck.cards.reverse()
	var opts := {"seed": 2024, "max_worlds": 4, "max_depth": 3, "time_budget_ms": 5000}
	var ra := FiniteSearch.evaluate(a, 0, opts)
	var rb := FiniteSearch.evaluate(b, 0, opts)
	_assert(ra.available and rb.available, "both searches are available")
	_assert(ra.candidates.size() == rb.candidates.size(), "same visible state yields the same candidates")
	for i in range(mini(ra.candidates.size(), rb.candidates.size())):
		_assert(str(ra.candidates[i].action_type) == str(rb.candidates[i].action_type), "candidate type is seed-stable")
		_assert(is_equal_approx(float(ra.candidates[i].ev), float(rb.candidates[i].ev)), "fixed-seed EV ignores real hidden cards and deck")

func _test_search_does_not_mutate_state_or_rng() -> void:
	var game := _flop_table(2, 1000)
	var players_before := game.players.duplicate(true)
	var deck_before := game.deck.cards.duplicate(true)
	var board_before := CardUtil.clone_cards(game.community_cards)
	var history_before := game.public_action_history.duplicate(true)
	var rng_state := game.shuffle_rng.state
	var result := FiniteSearch.evaluate(game, 0, {"seed": 99, "max_worlds": 4, "max_depth": 3, "time_budget_ms": 5000})
	_assert(result.available, "search completes")
	_assert(game.players == players_before, "real players are unchanged")
	_assert(game.deck.cards == deck_before, "real deck is unchanged")
	_assert(game.community_cards == board_before, "public board is unchanged")
	_assert(game.public_action_history == history_before, "public history is unchanged")
	_assert(game.shuffle_rng.state == rng_state, "real shuffle RNG is untouched")

func _test_tie_probability_versus_split_equity() -> void:
	var board := [c(14, "C"), c(13, "D"), c(12, "H"), c(11, "S"), c(10, "D")]
	var hero := [c(2, "H"), c(3, "S")]
	var worlds := [{"opponents": [[c(4, "H"), c(5, "S")]], "board": board}]
	var result := MonteCarlo.evaluate_worlds(hero, worlds)
	_assert(is_equal_approx(float(result.tie_rate), 0.5), "board-locked tie keeps the split-equity share at one half")
	_assert(is_equal_approx(float(result.tie_probability), 1.0), "tie_probability is the distinct event rate (1.0 here)")
	_assert(not is_equal_approx(float(result.tie_rate), float(result.tie_probability)), "split share and tie event rate are distinct")
	_assert(is_equal_approx(float(result.equity), 0.5), "equity is the half pot")

func _test_actual_unusual_raise_and_illegal_input() -> void:
	var game := _flop_table(2, 1000)
	var legal := game.get_legal_actions(0)
	if not legal.actions.has(TableState.ACTION_RAISE):
		_assert(false, "flop fixture must allow a raise")
		return
	# An intentionally odd but legal raise-to size between the bounds.
	var amount: int = mini(int(legal.max_raise_to), int(legal.min_raise_to) + 7)
	var context := CoachContext.capture(game, 0)
	var reviewed := CoachAnalysis.review(context, {"action_type": TableState.ACTION_RAISE, "amount": amount}, {
		"seed": 5, "max_worlds": 4, "max_depth": 3, "time_budget_ms": 5000
	})
	_assert(reviewed.available, "legal review is available")
	_assert(bool(reviewed.actual.legal), "actual action is marked legal")
	_assert(str(reviewed.actual.action_type) == TableState.ACTION_RAISE, "actual action type is preserved")
	_assert(int(reviewed.actual.amount) == amount, "actual unusual raise size is preserved exactly")
	var matched := false
	for candidate in reviewed.candidates:
		_assert(candidate.has("ev") and candidate.has("ev_bb") and candidate.has("stderr_bb"), "candidate exposes EV fields")
		if str(candidate.action_type) == TableState.ACTION_RAISE and int(candidate.amount) == amount:
			matched = true
	_assert(matched, "the unusual legal raise is present among the candidates")
	_assert(reviewed.has("gap_bb") and reviewed.has("close") and reviewed.has("depth") and reviewed.has("model"), "review exposes paired comparison fields")
	_assert(int(reviewed.world_count) >= 2, "review uses at least two paired worlds")

	var illegal := CoachAnalysis.review(context, {"action_type": TableState.ACTION_RAISE, "amount": 1}, {"seed": 5, "max_worlds": 4})
	_assert(not illegal.available, "illegal actual action is unavailable")
	_assert(str(illegal.reason) == "illegal_actual_action", "illegal actual action is explained")
	_assert(not bool(illegal.actual.legal), "illegal actual action is flagged")
	_assert((illegal.candidates as Array).is_empty(), "illegal actual action never silently becomes another move")

func _test_future_streets_and_actions() -> void:
	var game := _flop_table(3, 2000)
	var shallow := FiniteSearch.evaluate(game, 0, {"seed": 3, "max_worlds": 4, "max_depth": 1, "time_budget_ms": 5000})
	var deep := FiniteSearch.evaluate(game, 0, {"seed": 3, "max_worlds": 4, "max_depth": 8, "time_budget_ms": 5000})
	_assert(shallow.available and deep.available, "depth variants are available")
	_assert(shallow.cutoff_used, "a one-decision budget uses the documented cutoff")
	_assert(deep.depth_reached >= 2, "deeper rollouts take future actions on later streets")
	_assert(deep.depth_reached > shallow.depth_reached, "depth budget actually extends the rollout")
	for candidate in deep.candidates:
		_assert(int(candidate.samples) == int(deep.world_count), "every candidate is compared over equal paired worlds")
		_assert(not is_nan(float(candidate.ev)) and not is_inf(float(candidate.ev)), "candidate EV is a finite real number")

func _test_sidepot_refund_and_split() -> void:
	# --- multiway side pot: hero calls two all-ins and wins both layers ---
	var side := PokerRound.new()
	side.start_new_match(2, "simple")
	var side_board := [c(2, "C"), c(7, "D"), c(9, "S"), c(4, "H"), c(3, "D")]
	side.community_cards = CardUtil.clone_cards(side_board)
	side.players[0].hole_cards = [c(14, "S"), c(14, "H")]
	side.players[0].stack = 100
	side.players[0].current_bet = 0
	side.players[0].total_bet = 0
	side.players[0].status = TableState.STATUS_ACTIVE
	side.players[1].stack = 0
	side.players[1].current_bet = 40
	side.players[1].total_bet = 40
	side.players[1].status = TableState.STATUS_ALL_IN
	side.players[2].stack = 0
	side.players[2].current_bet = 100
	side.players[2].total_bet = 100
	side.players[2].status = TableState.STATUS_ALL_IN
	side.current_bet = 100
	side.min_raise = 20
	side.stage = TableState.STAGE_RIVER
	side.current_player_index = 0
	var side_worlds := [{"opponents": [[c(13, "S"), c(13, "H")], [c(12, "S"), c(12, "H")]], "board": side_board}]
	var side_result := FiniteSearch.evaluate(side, 0, {"seed": 1, "max_worlds": 1, "max_depth": 2, "time_budget_ms": 5000, "worlds": side_worlds})
	_assert(side_result.available, "side-pot search is available")
	var side_call := _candidate_for(side_result.candidates, TableState.ACTION_CALL)
	var side_fold := _candidate_for(side_result.candidates, TableState.ACTION_FOLD)
	_assert(is_equal_approx(float(side_call.ev), 140.0), "calling wins both side-pot layers for 140 net")
	_assert(is_equal_approx(float(side_fold.ev), 0.0), "folding keeps the remaining stack")

	# --- unmatched refund: hero has 400 more committed than the all-in rival ---
	var refund := PokerRound.new()
	refund.start_new_match(1, "simple")
	var refund_board := [c(13, "D"), c(12, "D"), c(11, "C"), c(9, "H"), c(4, "C")]
	refund.community_cards = CardUtil.clone_cards(refund_board)
	refund.players[0].hole_cards = [c(2, "H"), c(3, "S")]
	refund.players[0].stack = 500
	refund.players[0].current_bet = 500
	refund.players[0].total_bet = 500
	refund.players[0].status = TableState.STATUS_ACTIVE
	refund.players[1].hole_cards = [c(14, "S"), c(14, "H")]
	refund.players[1].stack = 0
	refund.players[1].current_bet = 100
	refund.players[1].total_bet = 100
	refund.players[1].status = TableState.STATUS_ALL_IN
	refund.current_bet = 500
	refund.min_raise = 20
	refund.stage = TableState.STAGE_RIVER
	refund.current_player_index = 0
	var refund_worlds := [{"opponents": [[c(14, "S"), c(14, "H")]], "board": refund_board}]
	var refund_result := FiniteSearch.evaluate(refund, 0, {"seed": 2, "max_worlds": 1, "max_depth": 2, "time_budget_ms": 5000, "worlds": refund_worlds})
	_assert(refund_result.available, "refund search is available")
	var refund_check := _candidate_for(refund_result.candidates, TableState.ACTION_CHECK)
	_assert(is_equal_approx(float(refund_check.ev), 400.0), "unmatched excess is refunded even when the showdown is lost")

	# --- split with folded dead money: board-locked tie shares both layers ---
	var split := PokerRound.new()
	split.start_new_match(2, "simple")
	var split_board := [c(14, "C"), c(13, "D"), c(12, "H"), c(11, "S"), c(10, "C")]
	split.community_cards = CardUtil.clone_cards(split_board)
	split.players[0].hole_cards = [c(2, "H"), c(3, "S")]
	split.players[0].stack = 100
	split.players[0].current_bet = 0
	split.players[0].total_bet = 0
	split.players[0].status = TableState.STATUS_ACTIVE
	split.players[1].stack = 900
	split.players[1].current_bet = 0
	split.players[1].total_bet = 20
	split.players[1].status = TableState.STATUS_FOLDED
	split.players[2].stack = 0
	split.players[2].current_bet = 100
	split.players[2].total_bet = 100
	split.players[2].status = TableState.STATUS_ALL_IN
	split.current_bet = 100
	split.min_raise = 20
	split.stage = TableState.STAGE_RIVER
	split.current_player_index = 0
	var split_worlds := [{"opponents": [[c(4, "H"), c(5, "S")]], "board": split_board}]
	var split_result := FiniteSearch.evaluate(split, 0, {"seed": 3, "max_worlds": 1, "max_depth": 2, "time_budget_ms": 5000, "worlds": split_worlds})
	_assert(split_result.available, "split search is available")
	var split_call := _candidate_for(split_result.candidates, TableState.ACTION_CALL)
	_assert(is_equal_approx(float(split_call.ev), 10.0), "board-locked split shares the dead-money layers correctly")
	_assert(is_equal_approx(float(split_result.tie_probability), 1.0), "split world reports a certain tie event")

func _test_cancellation_and_empty_sampling() -> void:
	var game := _flop_table(2, 1000)
	var cancellation := CoachCancellation.new()
	cancellation.cancel()
	_assert(cancellation.is_cancelled(), "cancellation token latches")
	var cancelled := FiniteSearch.evaluate(game, 0, {"seed": 1, "cancellation": cancellation})
	_assert(not cancelled.available, "cancelled search is unavailable")
	_assert(str(cancelled.reason) == "cancelled", "cancelled search reports cancellation")
	_assert((cancelled.candidates as Array).is_empty(), "cancelled search returns no partial advice")
	var no_worlds := FiniteSearch.evaluate(game, 0, {"seed": 1, "worlds": [{"opponents": [], "board": []}]})
	_assert(not no_worlds.available, "empty explicit sampling is unavailable")
	_assert(str(no_worlds.reason) == "no_worlds", "empty sampling reports no worlds")
	var live_empty := CoachAnalysis.live({})
	_assert(not live_empty.available, "empty live context is unavailable")
	_assert(live_empty.equity == null, "unavailable live does not fake a zero probability")
	var context := CoachContext.capture(game, 0)
	var reviewed := CoachAnalysis.review(context, {"action_type": TableState.ACTION_CHECK, "amount": 0}, {"seed": 1, "cancellation": cancellation})
	_assert(not reviewed.available, "cancelled review is unavailable")
	_assert((reviewed.candidates as Array).is_empty(), "cancelled review returns no candidates")

func _test_hell_legal_actions() -> void:
	_assert(str(MatchConfig.normalize({"difficulty": "hell"}).difficulty) == "hell", "MatchConfig accepts hell")
	_assert(MatchConfig.validate(MatchConfig.normalize({"difficulty": "hell"})), "MatchConfig validates hell")
	_assert(MatchConfig.validate(MatchConfig.normalize({"difficulty": "medium"})), "other difficulties still validate")
	_assert(PersonalityProfiles.DIFFICULTIES.has("hell"), "hell is a known difficulty")
	_assert(str(AiDecision.profile_for_difficulty("hell").difficulty) == "hell", "hell profile resolves")
	var stages := [
		[TableState.STAGE_PREFLOP, 0],
		[TableState.STAGE_FLOP, 3],
		[TableState.STAGE_TURN, 4],
		[TableState.STAGE_RIVER, 5]
	]
	for entry in stages:
		var game := PokerRound.new()
		game.shuffle_rng.seed = 31
		game.start_new_match(3, "hell")
		if int(entry[1]) > 0:
			game.community_cards = game.deck.draw(int(entry[1]))
		game.stage = entry[0]
		game.current_bet = 0
		game.min_raise = game.big_blind
		for player in game.players:
			player.current_bet = 0
			player.total_bet = 0
			player.has_acted = false
			player.last_action_bet = 0
			player.status = TableState.STATUS_ACTIVE
		game.current_player_index = 3
		var decision := AiDecision.decide(game, 3, _seeded(77))
		var legal := game.get_legal_actions(3)
		_assert(legal.actions.has(str(decision.get("action_type", ""))), "hell action is legal at %s" % str(entry[0]))
		_assert(decision.has("decision_label"), "hell decision keeps a readable label")
		var analysis: Dictionary = decision.get("analysis", {})
		_assert(analysis.has("finite_search"), "hell exposes finite_search diagnostics")
