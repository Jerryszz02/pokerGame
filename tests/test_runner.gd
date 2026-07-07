extends SceneTree

const LocalProfileScript := preload("res://scripts/game/local_profile.gd")

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
	_test_chinese_result_text()
	_test_event_log()
	_test_all_in_auto_deal_events()
	_test_match_goal_states()
	_test_local_profile_roundtrip()
	_test_ai_profiles_and_actions()
	_test_current_ai_action_event()
	_test_ai_sampling_and_difficulty_profiles()
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

func _test_chinese_result_text() -> void:
	var game := PokerRound.new()
	game.start_new_match(1, "simple")
	game.apply_action(TableState.ACTION_FOLD, 0)
	_assert(game.winners[0].rank_name == "无人跟注", "uncontested result should be Chinese")
	_assert(game.last_message.contains("赢得"), "result message should be Chinese")
	var result := HandEvaluator.evaluate([c(14, "S"), c(13, "S"), c(12, "S"), c(11, "S"), c(10, "S")])
	_assert(result.rank_name == "同花顺", "hand rank name should be Chinese")

func _test_event_log() -> void:
	var game := PokerRound.new()
	game.start_new_match(1, "simple")
	_assert(game.recent_events(8).size() >= 3, "new hand should record hand start and blinds")
	_assert(game.event_log[0].text.contains("第 1 手牌开始"), "event log should record hand start")
	_assert(game.apply_action(TableState.ACTION_CALL, 0), "human can call for event log test")
	var found_human_action := false
	for event in game.event_log:
		if event.text.contains("你") and event.text.contains("跟注"):
			found_human_action = true
	_assert(found_human_action, "event log should record human call")

func _test_all_in_auto_deal_events() -> void:
	var game := PokerRound.new()
	game.start_new_match(1, "simple")
	game.event_log = []
	game.community_cards = []
	game._deal_to_river()
	var street_events := 0
	for event in game.event_log:
		if event.type == "street" and event.text.contains("公共牌现在有"):
			street_events += 1
	_assert(game.community_cards.size() == 5, "auto deal should reach river")
	_assert(street_events == 3, "all-in auto deal should record flop, turn, and river events")

func _test_match_goal_states() -> void:
	var bust := PokerRound.new()
	bust.start_new_match(1, "simple")
	bust.players[0].stack = 0
	bust.players[1].stack = TableState.INITIAL_STACK * 2
	bust.start_next_hand()
	_assert(bust.match_over, "match should end when human has no chips")
	_assert(bust.match_result == "你已出局", "human bust result should be explicit")
	_assert(bust.match_summary.has("final_stack"), "match summary should include final stack")
	var win := PokerRound.new()
	win.start_new_match(1, "simple")
	win.players[0].stack = TableState.INITIAL_STACK * 2
	win.players[1].stack = 0
	win.start_next_hand()
	_assert(win.match_over, "match should end when only human has chips")
	_assert(win.match_result == "你赢得牌局", "human win result should be explicit")

func _test_local_profile_roundtrip() -> void:
	var path := "user://poker_profile_test.cfg"
	var profile := LocalProfileScript.default_profile()
	profile.settings.ai_count = 5
	profile.settings.difficulty = "hard"
	profile.settings.sound_enabled = false
	profile.stats.total_hands = 12
	profile.stats.total_net_profit = -40
	profile.stats.total_win_hands = 4
	profile.stats.max_single_hand_win = 180
	_assert(LocalProfileScript.save_profile(profile, path), "profile should save to user path")
	var loaded := LocalProfileScript.load_profile(path)
	_assert(loaded.settings.ai_count == 5, "profile should restore AI count")
	_assert(loaded.settings.difficulty == "hard", "profile should restore difficulty")
	_assert(not bool(loaded.settings.sound_enabled), "profile should restore sound toggle")
	_assert(loaded.stats.total_hands == 12, "profile should restore total hands")
	_assert(loaded.stats.total_net_profit == -40, "profile should restore net profit")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

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

func _test_current_ai_action_event() -> void:
	var game := PokerRound.new()
	game.start_new_match(3, "hard")
	var ai_index := game.current_player_index
	_assert(ai_index > 0, "multiway first actor should be an AI for integration test")
	var decision := AiDecision.decide(game, ai_index)
	var label := str(decision.get("decision_label", ""))
	_assert(game.apply_action(decision.action_type, int(decision.get("amount", 0)), label), "current AI decision should apply")
	var found_ai_event := false
	for event in game.event_log:
		if event.text.contains(game.players[ai_index].name) and event.text.contains(label):
			found_ai_event = true
	_assert(found_ai_event, "AI apply_action should record AI name and decision label")

func _test_ai_sampling_and_difficulty_profiles() -> void:
	var simple := AiDecision.profile_for_difficulty("simple")
	var medium := AiDecision.profile_for_difficulty("medium")
	var hard := AiDecision.profile_for_difficulty("hard")
	_assert(simple.aggression != medium.aggression, "simple and medium aggression should differ")
	_assert(medium.bluff_rate != hard.bluff_rate, "medium and hard bluff rates should differ")
	for i in range(100):
		var game := PokerRound.new()
		var difficulty := "hard" if i % 3 == 0 else ("medium" if i % 3 == 1 else "simple")
		game.start_new_match(3, difficulty)
		var ai_index := 1 + (i % 3)
		var decision := AiDecision.decide(game, ai_index)
		var legal := game.get_legal_actions(ai_index)
		_assert(legal.actions.has(decision.action_type), "sampled AI action should be legal")
		_assert(decision.has("decision_label"), "AI decision should include readable label")
