extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_card_labels()
	_test_deck_unique()
	_test_hand_rankings()
	_test_kickers()
	_test_action_validation()
	_test_side_pot()
	_test_split_pot()
	_test_ai_profiles_and_actions()
	if failures == 0:
		print("All poker tests passed.")
	else:
		push_error("%d poker tests failed." % failures)
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func c(rank: int, suit: String) -> Dictionary:
	return CardUtil.make_card(rank, suit)

func _test_card_labels() -> void:
	_assert(CardUtil.card_key(c(7, "C")) == "7C", "card key should stay compact")
	_assert(CardUtil.card_label(c(7, "C")) == "7♣", "club label should use suit symbol")
	_assert(CardUtil.card_label(c(8, "H")) == "8♥", "heart label should use suit symbol")
	_assert(CardUtil.card_label(c(10, "S")) == "10♠", "ten label should use full rank")

func _test_deck_unique() -> void:
	var deck := Deck.new()
	deck.shuffle()
	var seen := {}
	var drawn := deck.draw(52)
	_assert(drawn.size() == 52, "deck should draw 52 cards")
	for card in drawn:
		seen[CardUtil.card_key(card)] = true
	_assert(seen.size() == 52, "deck should contain 52 unique cards")
	_assert(deck.remaining_count() == 0, "deck should be empty after 52 draws")

func _test_hand_rankings() -> void:
	var hands := [
		{"cards": [c(14, "S"), c(13, "S"), c(12, "S"), c(11, "S"), c(10, "S")], "rank": HandEvaluator.STRAIGHT_FLUSH},
		{"cards": [c(9, "S"), c(9, "H"), c(9, "D"), c(9, "C"), c(2, "S")], "rank": HandEvaluator.FOUR_KIND},
		{"cards": [c(8, "S"), c(8, "H"), c(8, "D"), c(4, "C"), c(4, "S")], "rank": HandEvaluator.FULL_HOUSE},
		{"cards": [c(14, "H"), c(11, "H"), c(8, "H"), c(6, "H"), c(2, "H")], "rank": HandEvaluator.FLUSH},
		{"cards": [c(5, "S"), c(4, "H"), c(3, "D"), c(2, "C"), c(14, "S")], "rank": HandEvaluator.STRAIGHT},
		{"cards": [c(7, "S"), c(7, "H"), c(7, "D"), c(13, "C"), c(2, "S")], "rank": HandEvaluator.THREE_KIND},
		{"cards": [c(10, "S"), c(10, "H"), c(6, "D"), c(6, "C"), c(3, "S")], "rank": HandEvaluator.TWO_PAIR},
		{"cards": [c(12, "S"), c(12, "H"), c(9, "D"), c(5, "C"), c(2, "S")], "rank": HandEvaluator.ONE_PAIR},
		{"cards": [c(14, "S"), c(11, "H"), c(9, "D"), c(5, "C"), c(2, "S")], "rank": HandEvaluator.HIGH_CARD}
	]
	for item in hands:
		var result := HandEvaluator.evaluate(item.cards)
		_assert(result.rank_value == item.rank, "expected %s, got %s" % [item.rank, result.rank_value])

func _test_kickers() -> void:
	var ace_pair := HandEvaluator.evaluate([c(14, "S"), c(14, "H"), c(13, "D"), c(8, "C"), c(2, "S")])
	var king_pair := HandEvaluator.evaluate([c(13, "S"), c(13, "H"), c(14, "D"), c(8, "C"), c(2, "S")])
	_assert(HandEvaluator.compare_results(ace_pair, king_pair) > 0, "higher pair should win")
	var king_kicker := HandEvaluator.evaluate([c(12, "S"), c(12, "H"), c(13, "D"), c(8, "C"), c(2, "S")])
	var jack_kicker := HandEvaluator.evaluate([c(12, "D"), c(12, "C"), c(11, "S"), c(8, "H"), c(2, "D")])
	_assert(HandEvaluator.compare_results(king_kicker, jack_kicker) > 0, "kicker should break equal pair")

func _test_action_validation() -> void:
	var game := PokerRound.new()
	game.start_new_match(1, "simple")
	_assert(game.small_blind_player_index == 0, "heads-up human should post small blind")
	_assert(game.big_blind_player_index == 1, "heads-up AI should post big blind")
	_assert(game.community_cards.size() == 0, "preflop should have no board cards")
	_assert(game.players[0].hole_cards.size() == 2, "human should have two cards")
	_assert(not game.apply_action(TableState.ACTION_CHECK, 0), "human cannot check facing big blind")
	_assert(game.apply_action(TableState.ACTION_CALL, 0), "human can call big blind")
	var multiway := PokerRound.new()
	multiway.start_new_match(3, "simple")
	_assert(multiway.small_blind_player_index == 1, "multiway AI 1 should post small blind")
	_assert(multiway.big_blind_player_index == 2, "multiway AI 2 should post big blind")
	_assert(multiway.current_player_index == 3, "multiway first preflop actor should be after big blind")
	_assert(multiway.apply_action(TableState.ACTION_CALL, 0), "first multiway actor can call")
	_assert(multiway.big_blind_player_index == 2, "big blind marker should persist after actions")

func _test_side_pot() -> void:
	var game := PokerRound.new()
	game.start_new_match(2, "hard")
	game.community_cards = [c(2, "C"), c(3, "D"), c(4, "H"), c(9, "S"), c(11, "D")]
	game.players[0].hole_cards = [c(14, "H"), c(14, "S")]
	game.players[1].hole_cards = [c(13, "H"), c(13, "S")]
	game.players[2].hole_cards = [c(12, "H"), c(12, "S")]
	for i in range(3):
		game.players[i].stack = 0
		game.players[i].status = TableState.STATUS_ALL_IN
	game.players[0].total_bet = 100
	game.players[1].total_bet = 200
	game.players[2].total_bet = 200
	game._showdown()
	_assert(game.players[0].stack == 300, "short all-in winner should win main pot")
	_assert(game.players[1].stack == 200, "second best hand should win side pot")
	_assert(game.players[2].stack == 0, "third hand should not win pot")

func _test_split_pot() -> void:
	var game := PokerRound.new()
	game.start_new_match(1, "medium")
	game.community_cards = [c(14, "C"), c(13, "D"), c(12, "H"), c(11, "S"), c(10, "D")]
	game.players[0].hole_cards = [c(2, "H"), c(3, "S")]
	game.players[1].hole_cards = [c(4, "H"), c(5, "S")]
	for i in range(2):
		game.players[i].stack = 0
		game.players[i].status = TableState.STATUS_ALL_IN
		game.players[i].total_bet = 100
	game._showdown()
	_assert(game.players[0].stack == 100, "split pot should pay first player equally")
	_assert(game.players[1].stack == 100, "split pot should pay second player equally")

func _test_ai_profiles_and_actions() -> void:
	var game := PokerRound.new()
	game.start_new_match(3, "hard")
	for i in range(1, game.players.size()):
		_assert(not game.players[i].personality.is_empty(), "hard AI should have personality")
	var ai_index := 1
	var decision := AiDecision.decide(game, ai_index)
	var legal := game.get_legal_actions(ai_index)
	_assert(legal.actions.has(decision.action_type), "AI action should be legal")
	var equity := MonteCarlo.estimate_equity([c(14, "S"), c(14, "H")], [c(2, "S"), c(7, "D"), c(9, "C")], 1, 50)
	_assert(equity.equity >= 0.0 and equity.equity <= 1.0, "Monte Carlo equity should be within 0..1")
