extends SceneTree
var failures := 0
func _init() -> void: call_deferred("_run")
func _run() -> void:
	TranslationServer.set_locale("zh_CN") # This fixture asserts Chinese tutorial copy.
	_reference(); _t1(); _lessons(); _t3_t6(); _t7()
	if failures == 0: print("Tutorial tests passed.")
	quit(failures)
func _assert(v: bool, m: String) -> void:
	if not v: failures += 1; push_error(m)
func _reference() -> void:
	_assert(PokerReference.hands().size() == 9, "nine categories")
	for hand in PokerReference.hands(): _assert(HandEvaluator.evaluate(hand.cards).rank_value == hand.rank, "reference evaluates")
func _t1() -> void:
	var t := TutorialController.new(); t.start("T1")
	for a in ["hole_cards","community_cards","chips","pot"]: _assert(t.submit(a).ok, "T1 region")
	_assert(not t.submit("BAD").ok, "invalid ID rejected")
	for a in ["AS","KS","QS","JS","2D"]: t.submit(a)
	_assert(t.step_index == 4, "wrong selection resets")
	var cards := str(t.current_step().cards); t.restart()
	_assert(cards == str(t.current_step().cards), "restart deterministic")
	var keys := {}; for card in t.current_step().cards: keys[CardUtil.card_key(card)] = true
	_assert(keys.size() == t.current_step().cards.size(), "no duplicate cards")
func _lessons() -> void:
	var answers := {"T1":["hole_cards","community_cards","chips","pot","AS","KS","QS","JS","TS"],"T2":["straight_flush","a","tie"],"T3":["check","call","fold","raise","all_in"],"T4":["call","check","check","check","showdown"],"T5":["seat_3","button_small_blind","rotate"],"T6":["200","150","980","split"]}
	for id in answers:
		var t := TutorialController.new(); t.start(id); var guard := 0
		while not t.completed and guard < 20:
			var result := t.submit(answers[id][t.step_index]); _assert(result.ok, "%s accepts valid choice" % id); guard += 1
		_assert(t.completed, "%s completes" % id)
func _t3_t6() -> void:
	var t3 := TutorialController.new(); t3.start("T3")
	_assert(t3.current_step().detail.contains("需跟注 0"), "T3 actual check state")
	_assert(t3.submit("check").ok and t3.game.players[0].last_action == "Check", "T3 check engine action")
	t3.step_index = 3; _assert(t3.submit("raise").ok and t3.game.players[0].last_action == "Raise 100", "T3 raise 100")
	var t6 := TutorialController.new(); t6.start("T6")
	_assert(t6.game.side_pots[0].amount == 200 and t6.game.side_pots[1].amount == 150, "actual pots")
	_assert(t6._settlement.refund_amount == 980, "actual refund")
	_assert(t6._settlement.split.side_pots[0].payouts.size() == 2 and t6._settlement.conserved, "split and conservation")
func _t7() -> void:
	for branch in [TableState.ACTION_FOLD,TableState.ACTION_CALL,TableState.ACTION_RAISE,TableState.ACTION_ALL_IN]:
		var t := TutorialController.new(); t.start("T7"); _assert(t.submit(branch).ok, "T7 branch starts")
		var guard := 0
		while not t._t7_finished and guard < 8:
			var step := t.current_step()
			if step.options.is_empty():
				push_error("T7 exposed no continuation for %s" % branch)
				failures += 1
				break
			_assert(t.submit(step.options[0].id).ok, "T7 branch progresses"); guard += 1
		_assert(t._t7_finished, "T7 no deadlock")
		_assert(t.submit("refund").completed, "T7 finishes")
