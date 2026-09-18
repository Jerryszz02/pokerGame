extends SceneTree
var failures := 0

func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func numerical(actual: String = "call", alternative: String = "fold", gap: float = 2.0) -> Dictionary:
	return {"available": true, "actual": {"action_type": actual, "amount": 40, "ev_bb": -gap},
		"best": {"action_type": alternative, "amount": 120, "ev_bb": 0.0},
		"gap_bb": gap, "close": false, "uncertainty_available": true, "world_count": 32}

func review(results: Array, locale: String = "en") -> Dictionary:
	return LocalReplayReview.generate(DeepSeekReview.make_facts(results), locale)

func _run() -> void:
	check(not review([]).available and not review([{"available": false}]).available, "missing analysis produces no invented advice")
	var value := numerical()
	var saved := value.duplicate(true)
	var result := review([value])
	check(result.available and result.source == "local" and result.items.size() == 1, "offline review is explicitly local")
	check(result.items[0].explanation.contains("-2.00 BB") and result.items[0].explanation.contains("0.00 BB") and result.items[0].explanation.contains("32 shared samples"), "prose reports the actual sampled returns and count")
	check(result.items[0].next_step.contains("already invested"), "a supported fold comparison explains sunk investment")
	check(value == saved and review([value]) == result, "generation is deterministic and leaves inputs unchanged")
	value.opponent_hole_cards = ["secret"]
	value.final_board = ["future"]
	value.net_change = 99999
	check(review([value]) == result, "hidden cards and final outcome cannot change decision-time advice")
	value = numerical("raise", "raise")
	result = review([value])
	check(result.items[0].explanation.contains("40 chips in this betting round") and result.items[0].explanation.contains("120 chips in this betting round"), "raise totals remain distinct and include units")
	check(result.items[0].next_step.contains("two raise totals"), "same action with different sizing receives sizing guidance")
	value = numerical("call", "all_in")
	check(review([value]).items[0].next_step.contains("remaining stack") and not review([value]).items[0].next_step.contains("pressure"), "all-in advice does not assume it is a raise")
	for action in ["check", "call", "raise"]:
		value = numerical("fold", action)
		check(not review([value]).items[0].next_step.is_empty(), "supported alternative supplies a practical next step: " + action)
	value = numerical("check", "check", 0.0)
	result = review([value])
	check(result.items[0].explanation.contains("matches the highest") and result.items[0].next_step.contains("not a unique or optimal strategy"), "matching the sampled best is not called uniquely optimal")
	value = numerical()
	value.close = true
	result = review([value])
	check(result.items[0].explanation.contains("do not distinguish a clear difference"), "close estimates never turn a numeric gap into a correction")
	value.close = false
	value.uncertainty_available = false
	check(review([value]).items[0].explanation.contains("do not distinguish a clear difference"), "unavailable uncertainty overrides a nominal compare flag")
	value.world_count = 1
	check(review([value]).items[0].explanation.contains("too few samples"), "one sample is explicitly inconclusive")
	value.world_count = 0
	check(not review([value]).available, "zero samples do not become a zero-valued recommendation")
	value = numerical()
	value.actual.ev_bb = -4.0
	value.best.ev_bb = -2.0
	check(review([value]).items[0].explanation.contains("smaller expected loss"), "less-negative EV is not described as profit")
	var close := numerical("call", "fold", 100.0)
	close.close = true
	var small := numerical("call", "fold", 1.0)
	var large := numerical("call", "fold", 4.0)
	var sparse := numerical("call", "fold", 500.0)
	sparse.world_count = 1
	result = review([{"available": false}, close, small, large, sparse])
	check(result.items.size() == 3 and result.items[0].decision_id == 4 and result.items[1].decision_id == 3 and result.items[2].decision_id == 2, "prioritize supported gaps, retain original decision IDs and cap prose at three items")
	var facts := DeepSeekReview.make_facts([numerical()])
	for key in ["actual_ev_bb", "alternative_ev_bb", "gap_bb", "sample_count", "actual_amount"]:
		var bad: Array = facts.duplicate(true)
		bad[0][key] = NAN
		check(not LocalReplayReview.generate(bad, "en").available, "reject non-finite facts: " + key)
	for bad in [{}, {"sample_count": 1}, null, "not facts"]:
		check(not LocalReplayReview.generate([bad], "en").available, "malformed facts stay unavailable")
	var inconsistent: Array = facts.duplicate(true)
	inconsistent[0].gap_bb = 99.0
	check(not LocalReplayReview.generate(inconsistent, "en").available, "inconsistent means and gap cannot produce prose")
	var locale := TranslationServer.get_locale()
	result = review([numerical()], "zh_CN")
	check(result.items[0].explanation.contains("32 个共同样本") and result.items[0].next_step.contains("弃牌"), "Chinese has localized facts and action advice")
	check(TranslationServer.get_locale() == locale, "explicit output locale never mutates game language")
	var chinese := RegEx.new()
	chinese.compile("[一-龥]")
	check(chinese.search(JSON.stringify(review([numerical()], "en_US"))) == null, "English has no untranslated Chinese")
	if failures == 0: print("Local replay review tests passed.")
	quit(failures)
