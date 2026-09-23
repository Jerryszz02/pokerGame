extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	TranslationServer.set_locale("zh_CN")
	_test_reference()
	_test_seeded_hands()
	_test_first_hand()
	_test_second_hand()
	_test_third_hand_branches()
	_test_restart_and_validation()
	if failures == 0:
		print("Tutorial tests passed.")
	quit(failures)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _keys(cards: Array) -> String:
	var keys := []
	for card in cards:
		keys.append(CardUtil.card_key(card))
	return " ".join(keys)

func _test_reference() -> void:
	_assert(PokerReference.hands().size() == 9, "reference covers all nine hand categories")
	for hand in PokerReference.hands():
		_assert(HandEvaluator.evaluate(hand.cards).rank_value == hand.rank, "reference example matches evaluator")

func _test_seeded_hands() -> void:
	var expected := {
		"G1": {"hole": "9D 5H", "opponent": "7H QD", "board": "2S AS 5D KD JS"},
		"G2": {"hole": "8S 4H", "opponent": "9D JS", "board": "TS 3D QC 8D 6C"},
		"G3": {"hole": "KS AS", "opponent": "4H JD", "board": "3H 4D 6C JH 7H"}
	}
	for id in expected:
		var tutorial := TutorialController.new()
		tutorial.start(id)
		_assert(tutorial.lesson_id == id and tutorial.game.match_config.mode == "tutorial", "%s uses a private tutorial match" % id)
		_assert(tutorial.game.players.size() == 2 and tutorial.game.initial_stack == 1000 and tutorial.game.small_blind == 10 and tutorial.game.big_blind == 20, "%s has fixed heads-up setup" % id)
		_assert(_keys(tutorial.game.players[0].hole_cards) == expected[id].hole, "%s human hole cards locked" % id)
		_assert(_keys(tutorial.game.players[1].hole_cards) == expected[id].opponent, "%s opponent hole cards locked" % id)
		var runout := []
		for offset in range(5):
			runout.append(tutorial.game.deck.cards[tutorial.game.deck.cards.size() - 1 - offset])
		_assert(_keys(runout) == expected[id].board, "%s board runout locked" % id)
		_assert(TutorialController.index_for(id) >= 0 and not TutorialController.hand_title(id).is_empty(), "%s has progress label" % id)

func _advance(tutorial: TutorialController, expected_id: String) -> void:
	_assert(tutorial.current_step().id == expected_id, "expected %s, got %s" % [expected_id, tutorial.current_step().id])
	_assert(tutorial.current_step().can_continue and tutorial.advance(), "%s advances as observation" % expected_id)

func _act_opponent(tutorial: TutorialController, expected_action: String, expected_amount: int = 0) -> void:
	_assert(tutorial.opponent_can_act(), "opponent can act when prompted")
	var decision := tutorial.opponent_decision()
	_assert(decision.get("action_type", "") == expected_action and int(decision.get("amount", -1)) == expected_amount, "scripted opponent chooses %s %d" % [expected_action, expected_amount])
	_assert(tutorial.game.apply_action(str(decision.action_type), int(decision.amount), "教程对手"), "scripted opponent action is legal")
	tutorial.after_opponent_action()

func _test_first_hand() -> void:
	var tutorial := TutorialController.new()
	tutorial.start("G1")
	_advance(tutorial, "G1.intro")
	_advance(tutorial, "G1.hole")
	_advance(tutorial, "G1.blinds")
	_assert(not tutorial.advance() and not tutorial.allows_action("fold") and tutorial.allows_action("call"), "first action only allows call")
	_assert(tutorial.submit_action("call") and not tutorial.submit_action("call"), "call is applied once")
	_act_opponent(tutorial, "check")
	_assert(tutorial.game.stage == TableState.STAGE_FLOP and _keys(tutorial.game.community_cards) == "2S AS 5D", "first hand reaches pair on flop")
	_assert(not tutorial.opponent_can_act(), "flop explanation pauses opponent")
	_advance(tutorial, "G1.flop")
	_act_opponent(tutorial, "check")
	_assert(tutorial.submit_action("check"), "human checks flop")
	_assert(tutorial.game.stage == TableState.STAGE_TURN and not tutorial.opponent_can_act(), "turn explanation pauses opponent")
	_advance(tutorial, "G1.turn")
	_act_opponent(tutorial, "check")
	_assert(tutorial.submit_action("check"), "human checks turn")
	_advance(tutorial, "G1.river")
	_act_opponent(tutorial, "check")
	_assert(tutorial.submit_action("check") and tutorial.completed, "river check completes showdown")
	_assert(tutorial.current_step().id == "G1.result" and tutorial.current_step().focus.has("best_five"), "showdown explains best five")
	_assert(tutorial.current_step().text.contains("一对胜过对手的高牌"), "showdown compares the actual evaluated hands")
	_assert(tutorial.game.last_hand_human_won and tutorial.game.players[0].stack == 1020, "pair wins real forty-chip pot")
	_assert(_keys(tutorial.best_five()) == "5H AS 5D KD JS", "best five comes from HandEvaluator")
	_assert(not tutorial.advance() and not tutorial.submit_action("check"), "completed hand cannot advance or act")

func _test_second_hand() -> void:
	var tutorial := TutorialController.new()
	tutorial.start("G2")
	_advance(tutorial, "G2.intro")
	_advance(tutorial, "G2.hole")
	_assert(tutorial.submit_action("call"), "second hand calls preflop")
	_act_opponent(tutorial, "check")
	_assert(HandEvaluator.evaluate(tutorial.game.players[0].hole_cards + tutorial.game.community_cards).rank_value == HandEvaluator.HIGH_CARD, "weak hand misses flop")
	_assert(not tutorial.opponent_can_act(), "flop explanation pauses bet")
	_advance(tutorial, "G2.flop")
	_act_opponent(tutorial, "raise", 40)
	_assert(tutorial.game.get_to_call(0) == 40 and tutorial.current_step().id == "G2.fold", "facing exact forty-chip bet")
	_assert(not tutorial.allows_action("call") and tutorial.allows_action("fold"), "fold practice gates action")
	_assert(tutorial.submit_action("fold") and tutorial.completed, "fold completes second hand")
	_assert(tutorial.game.players[0].stack == 980 and tutorial.game.players[1].stack == 1020, "fold settlement conserves chips")

func _test_third_hand_branches() -> void:
	var feedback := TutorialController.new()
	feedback.start("G3")
	_assert(feedback.submit_action("call"), "free hand can call")
	_assert(feedback.current_step().text.contains("刚才选择了跟注"), "action feedback stays visible while opponent is thinking")
	_assert(feedback.game.apply_action("check"), "opponent checks after call")
	feedback.after_opponent_action()
	_assert(not feedback.current_step().text.contains("刚才选择了跟注"), "opponent response clears stale feedback")
	var folded := TutorialController.new()
	folded.start("G3")
	_assert(folded.allows_action("fold") and not folded.opponent_can_act(), "third hand opens with legal actions")
	_assert(folded.submit_action("fold") and folded.completed and folded.current_step().id == "G3.result", "third-hand fold completes")
	var shoved := TutorialController.new()
	shoved.start("G3")
	_assert(shoved.raise_explanation(100).contains("还需补 90"), "raise explanation distinguishes total from additional chips")
	_assert(shoved.submit_action("all_in") and shoved.opponent_can_act(), "third-hand all-in waits for opponent")
	_assert(shoved.opponent_decision().is_empty(), "third hand delegates decision to simple AI")
	_assert(shoved.game.apply_action("call", 0, "测试对手跟注"), "opponent calls all-in through engine")
	shoved.after_opponent_action()
	_assert(shoved.completed and shoved.game.stage == TableState.STAGE_HAND_OVER and shoved.game.community_cards.size() == 5, "all-in runout completes")
	var raised := TutorialController.new()
	raised.start("G3")
	_assert(not raised.allows_action("raise", 30) and raised.allows_action("raise", 100), "raise bounds checked")
	_assert(raised.submit_action("raise", 100) and raised.game.players[0].current_bet == 100, "raise uses real round")
	_assert(raised.opponent_can_act() and raised.opponent_decision().is_empty(), "AI turn follows free raise")
	_assert(raised.game.apply_action("call", 0, "测试对手跟注"), "opponent calls raise")
	raised.after_opponent_action()
	var guard := 0
	while not raised.completed and guard < 16:
		if raised.game.is_ai_turn():
			var ai_action := "check" if raised.game.get_legal_actions(1).actions.has("check") else "call"
			_assert(raised.game.apply_action(ai_action, 0, "测试对手"), "free-hand AI action remains legal")
			raised.after_opponent_action()
		else:
			var human_action := "check" if raised.game.get_legal_actions(0).actions.has("check") else "call"
			_assert(raised.submit_action(human_action), "free-hand human action remains legal")
		guard += 1
	_assert(raised.completed and guard < 16, "free hand can reach normal showdown")
	var won := TutorialController.new()
	won.start("G3")
	_assert(won.submit_action("raise", 100), "third hand can raise before opponent fold")
	_assert(won.game.apply_action("fold", 0, "测试对手弃牌"), "opponent fold is legal")
	won.after_opponent_action()
	_assert(won.completed and won.game.last_hand_human_won and won.game.players[0].stack == 1020, "third hand completes winning fold branch")

func _test_restart_and_validation() -> void:
	var tutorial := TutorialController.new()
	tutorial.start("G1")
	var original := _keys(tutorial.game.players[0].hole_cards)
	tutorial.advance()
	tutorial.restart()
	_assert(tutorial.current_step().id == "G1.intro" and _keys(tutorial.game.players[0].hole_cards) == original, "restart resets phase and cards")
	tutorial.start("unknown")
	_assert(tutorial.lesson_id == "G1", "unknown hand defaults to first hand")
	_assert(tutorial.best_five().is_empty(), "best five unavailable before board")
	_assert(tutorial.current_step().id == tutorial.current_step().id, "step read is pure")
