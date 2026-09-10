extends SceneTree
## Public observation and snapshot privacy tests. Every observation must be
## public-only, deep-copied, reset per hand/match and never appended for an
## invalid action; the worker snapshot must expose only the acting seat's own
## private information.

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_history_reset()
	_test_observation_fields_and_privacy()
	_test_invalid_actions_append_nothing()
	_test_all_in_call_and_raise_distinguished()
	_test_strategy_history_is_independent()
	_test_snapshot_is_secret_free()
	_test_opponent_cards_do_not_change_seeded_decision()
	_test_public_aggression_changes_range()
	if failures == 0:
		print("AI observation tests passed.")
	else:
		push_error("%d AI observation tests failed." % failures)
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

func _test_history_reset() -> void:
	var game := PokerRound.new()
	game.shuffle_rng.seed = 1
	game.start_new_match(1, "simple")
	_assert(game.public_action_history.is_empty(), "new match starts with empty strategy history")
	_assert(game.apply_action(TableState.ACTION_CALL, 0), "human call succeeds")
	_assert(game.public_action_history.size() == 1, "successful action appends one observation")
	game.start_next_hand()
	_assert(game.public_action_history.is_empty(), "new hand resets strategy history")
	game.apply_action(TableState.ACTION_CALL, 0)
	game.start_new_match(1, "simple")
	_assert(game.public_action_history.is_empty(), "new match resets strategy history")

func _test_observation_fields_and_privacy() -> void:
	var game := PokerRound.new()
	game.shuffle_rng.seed = 2
	game.start_new_match(3, "medium")
	_assert(game.current_player_index == 3, "full-ring first actor is after the blinds")
	_assert(game.apply_action(TableState.ACTION_RAISE, 100), "opening raise succeeds")
	var observation: Dictionary = game.public_action_history[0]
	for key in ["hand", "actor", "street", "board_before", "action", "pot_before", "to_call_before",
			"stack_before", "bet_before", "actor_bet_before", "actor_total_before", "big_blind",
			"button", "active_count", "paid", "raise_to", "increased_current_bet", "all_in",
			"is_all_in_call", "pot_after"]:
		_assert(observation.has(key), "observation exposes %s" % key)
	_assert(int(observation.actor) == 3, "observation records the actor")
	_assert(str(observation.street) == TableState.STAGE_PREFLOP, "observation records the street")
	_assert(str(observation.action) == TableState.ACTION_RAISE, "observation records the action")
	_assert(int(observation.paid) == 100, "observation records the actual paid chips")
	_assert(int(observation.raise_to) == 100, "observation records the raise target")
	_assert(bool(observation.increased_current_bet), "raise increased the current bet")
	_assert(not bool(observation.is_all_in_call), "raise is not an all-in call")
	_assert(not bool(observation.all_in), "full-stack raise is not all-in")
	for banned in ["hole_cards", "personality", "action_note", "decision_label", "equity",
			"hand_result", "last_action_note", "simulation_count"]:
		_assert(not observation.has(banned), "observation must not contain %s" % banned)

	# Board is snapshotted deeply at the action.
	var flop_game := PokerRound.new()
	flop_game.shuffle_rng.seed = 3
	flop_game.start_new_match(1, "simple")
	flop_game.stage = TableState.STAGE_FLOP
	flop_game.community_cards = [c(2, "C"), c(3, "D"), c(4, "H")]
	flop_game.current_bet = 0
	flop_game.min_raise = flop_game.big_blind
	for player in flop_game.players:
		player.current_bet = 0
		player.total_bet = 0
		player.status = TableState.STATUS_ACTIVE
		player.has_acted = false
	flop_game.current_player_index = 0
	_assert(flop_game.apply_action(TableState.ACTION_CHECK, 0), "flop check succeeds")
	var flop_observation: Dictionary = flop_game.public_action_history[0]
	var expected_board := CardUtil.clone_cards(flop_game.community_cards)
	flop_game.community_cards.append(c(5, "S"))
	_assert(flop_observation.board_before == expected_board, "board snapshot is deep-copied")

func _test_invalid_actions_append_nothing() -> void:
	var game := PokerRound.new()
	game.shuffle_rng.seed = 4
	game.start_new_match(1, "simple")
	var before := game.public_action_history.size()
	_assert(not game.apply_action(TableState.ACTION_CHECK, 0), "cannot check facing the big blind")
	_assert(game.public_action_history.size() == before, "illegal check appends nothing")
	_assert(not game.apply_action(TableState.ACTION_RAISE, 5), "raise below the minimum is rejected")
	_assert(game.public_action_history.size() == before, "illegal raise appends nothing")
	_assert(not game.apply_action("bogus", 0), "unknown action is rejected")
	_assert(game.public_action_history.size() == before, "unknown action appends nothing")

	var finished := PokerRound.new()
	finished.shuffle_rng.seed = 5
	finished.start_new_match(1, "simple")
	_assert(finished.apply_action(TableState.ACTION_FOLD, 0), "human can fold")
	var finished_count := finished.public_action_history.size()
	_assert(finished.stage == TableState.STAGE_HAND_OVER, "fold ends the heads-up hand")
	_assert(not finished.apply_action(TableState.ACTION_CALL, 0), "cannot act after the hand")
	_assert(finished.public_action_history.size() == finished_count, "post-hand action appends nothing")

func _test_all_in_call_and_raise_distinguished() -> void:
	var all_in_raise := PokerRound.new()
	all_in_raise.shuffle_rng.seed = 6
	all_in_raise.start_new_match(1, "simple")
	_assert(all_in_raise.apply_action(TableState.ACTION_ALL_IN, 0), "heads-up button can shove")
	var shove: Dictionary = all_in_raise.public_action_history[0]
	_assert(str(shove.action) == TableState.ACTION_ALL_IN, "shove recorded as all-in")
	_assert(bool(shove.increased_current_bet), "shove increased the current bet")
	_assert(not bool(shove.is_all_in_call), "shove is not an all-in call")
	_assert(int(shove.paid) == int(shove.stack_before), "shove records the actual remaining cost")
	_assert(int(shove.actor_total_before) + int(shove.paid) == 1000, "shove invests the full stack")

	var short_call := PokerRound.new()
	short_call.shuffle_rng.seed = 7
	short_call.start_new_match(3, "simple")
	_assert(short_call.current_player_index == 3, "full-ring first actor is after the blinds")
	_assert(short_call.apply_action(TableState.ACTION_RAISE, 500), "opening raise succeeds")
	short_call.players[0].stack = 100
	_assert(short_call.apply_action(TableState.ACTION_ALL_IN, 0), "short stack can shove below the raise")
	var short_observation: Dictionary = short_call.public_action_history[1]
	_assert(str(short_observation.action) == TableState.ACTION_ALL_IN, "short all-in recorded as all-in")
	_assert(not bool(short_observation.increased_current_bet), "short all-in did not increase the bet")
	_assert(bool(short_observation.is_all_in_call), "short all-in is distinguished as a call")
	_assert(int(short_observation.paid) == 100, "short all-in records only the actual cost")
	_assert(int(short_observation.raise_to) == 100, "short all-in records its reachable target")

func _test_strategy_history_is_independent() -> void:
	var game := PokerRound.new()
	game.shuffle_rng.seed = 8
	game.start_new_match(3, "simple")
	var actions := 0
	var steps := 0
	while game.stage != TableState.STAGE_HAND_OVER and steps < 60:
		steps += 1
		var actor := game.current_player_index
		if actor < 0:
			break
		var legal := game.get_legal_actions(actor)
		var action := TableState.ACTION_CHECK if game.get_to_call(actor) == 0 else TableState.ACTION_CALL
		if not legal.actions.has(action):
			action = TableState.ACTION_FOLD
		if game.apply_action(action, 0):
			actions += 1
	_assert(actions > 0, "a hand records at least one action")
	_assert(game.public_action_history.size() == actions, "strategy history keeps every successful action")
	_assert(game.event_log.size() <= 40, "human event log keeps its display cap")

func _test_snapshot_is_secret_free() -> void:
	var game := PokerRound.new()
	game.shuffle_rng.seed = 9
	game.start_new_match(3, "hard")
	game.apply_action(TableState.ACTION_CALL, 0)
	game.stage = TableState.STAGE_FLOP
	game.community_cards = [c(2, "C"), c(3, "D"), c(4, "H")]
	game.current_bet = 0
	game.min_raise = game.big_blind
	for player in game.players:
		player.current_bet = 0
		player.has_acted = false
	game.current_player_index = 1
	var snapshot := AiTurnWorker.make_snapshot(game, 1)
	_assert(snapshot is PokerRound, "make_snapshot returns a PokerRound")
	_assert(snapshot.players[1].hole_cards == game.players[1].hole_cards, "own hole cards are preserved")
	_assert(not snapshot.players[1].personality.is_empty(), "own personality is preserved")
	_assert(snapshot.deck.cards.is_empty(), "snapshot has no access to the real future deck")
	_assert(snapshot.public_action_history.size() == game.public_action_history.size(), "public history is copied")
	for i in range(snapshot.players.size()):
		if i != 1:
			_assert(snapshot.players[i].hole_cards.is_empty(), "opponent hole cards are hidden")
			_assert(snapshot.players[i].personality.is_empty(), "opponent personality is hidden")
		_assert(snapshot.players[i].hand_result.is_empty(), "hand results are hidden")
		_assert(str(snapshot.players[i].last_action_note) == "", "action notes never leak")

	var expected_board := CardUtil.clone_cards(game.community_cards)
	snapshot.community_cards.append(c(5, "S"))
	_assert(game.community_cards == expected_board, "snapshot board is deep-copied")
	snapshot.public_action_history[0]["paid"] = 999999
	_assert(int(game.public_action_history[0].paid) != 999999, "snapshot history is deep-copied")
	_assert(snapshot.get_legal_actions(1).actions == game.get_legal_actions(1).actions, "legality fields are preserved")
	var decision := AiDecision.decide(snapshot, 1, _seeded(21))
	_assert(snapshot.get_legal_actions(1).actions.has(str(decision.get("action_type", ""))), "snapshot decision is legal")

func _privacy_game(opponent_cards: Array, opponent_personality: Dictionary) -> PokerRound:
	var game := PokerRound.new()
	game.shuffle_rng.seed = 15
	game.start_new_match(1, "hard")
	game.community_cards = [c(2, "C"), c(3, "D"), c(4, "H")]
	game.stage = TableState.STAGE_FLOP
	game.players[0].hole_cards = [c(14, "H"), c(14, "S")]
	game.players[1].hole_cards = opponent_cards
	game.players[1].personality = opponent_personality
	game.current_bet = 0
	game.min_raise = game.big_blind
	for player in game.players:
		player.current_bet = 0
		player.total_bet = 40
		player.status = TableState.STATUS_ACTIVE
		player.has_acted = false
		player.last_action_note = "secret-note"
	game.current_player_index = 0
	return game

func _test_opponent_cards_do_not_change_seeded_decision() -> void:
	var first := _privacy_game([c(13, "H"), c(13, "S")], PersonalityProfiles.get_profile("Rock"))
	var second := _privacy_game([c(7, "D"), c(2, "S")], PersonalityProfiles.get_profile("LooseAggressive"))
	var first_decision := AiDecision.decide(first, 0, _seeded(555))
	var second_decision := AiDecision.decide(second, 0, _seeded(555))
	_assert(str(first_decision.action_type) == str(second_decision.action_type), "opponent cards cannot change the seeded action")
	_assert(int(first_decision.amount) == int(second_decision.amount), "opponent cards cannot change the seeded amount")
	_assert(first.get_legal_actions(0).actions.has(str(first_decision.action_type)), "decision stays legal")

func _test_public_aggression_changes_range() -> void:
	var hero := [c(14, "S"), c(14, "H")]
	var board := [c(2, "C"), c(7, "D"), c(9, "S")]
	var neutral := OpponentRange.new(hero, board)
	var raised := OpponentRange.new(hero, board)
	var observation := {
		"actor": 1,
		"action": TableState.ACTION_RAISE,
		"raise_to": 400,
		"to_call_before": 0,
		"board_before": board,
		"big_blind": 20,
		"increased_current_bet": true
	}
	_assert(raised.update_from_observation(observation, 1), "raise observation applies")
	var neutral_weights := neutral.normalized_weights()
	var raised_weights := raised.normalized_weights()
	var neutral_ratio := float(neutral_weights["AA"]) / maxf(0.0001, float(neutral_weights["72o"]))
	var raised_ratio := float(raised_weights["AA"]) / maxf(0.0001, float(raised_weights["72o"]))
	_assert(raised_ratio > neutral_ratio, "public aggression shifts weight towards strong hands")
	_assert(float(raised_weights["72o"]) > 0.0, "public aggression keeps a bluff tail")
	var history := [observation]
	var from_history := OpponentRange.new(hero, board)
	from_history.observe_history(history, 1, board)
	_assert(from_history.normalized_weights() == raised_weights, "history replay matches a direct update")
