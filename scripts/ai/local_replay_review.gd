class_name LocalReplayReview
extends RefCounted
## Deterministic prose from the same allowlisted numerical facts as the service.
## No cards, final winnings, network access or new poker estimates enter here.
const MAX_ITEMS := 3
const ACTIONS := ["fold", "check", "call", "raise", "all_in"]

static func generate(facts: Array, locale: String) -> Dictionary:
	var candidates: Array = []
	var seen := {}
	for fact in facts:
		if not _valid_fact(fact) or seen.has(fact.decision_id): continue
		seen[fact.decision_id] = true
		candidates.append(fact)
	if candidates.is_empty():
		return {"available": false, "source": "local", "reason": "no_reliable_facts"}
	candidates.sort_custom(_before)
	var items: Array = []
	for fact in candidates.slice(0, MAX_ITEMS):
		items.append(_explain(fact, locale.begins_with("en")))
	return {"available": true, "source": "local", "items": items}

static func _valid_fact(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.get("actual_action") not in ACTIONS or value.get("alternative_action") not in ACTIONS: return false
	if value.get("assessment") not in ["close", "compare"]: return false
	for key in ["actual_ev_bb", "alternative_ev_bb", "gap_bb", "decision_id", "sample_count", "actual_amount", "alternative_amount"]:
		var number: Variant = value.get(key)
		if not (number is int or number is float) or not is_finite(float(number)): return false
	for key in ["decision_id", "sample_count", "actual_amount", "alternative_amount"]:
		if float(value[key]) < 0 or float(value[key]) != floor(float(value[key])): return false
	if value.decision_id < 1 or value.sample_count < 1 or value.gap_bb < 0: return false
	# These are two means over the same worlds, expressed in big blinds.
	return absf(float(value.alternative_ev_bb) - float(value.actual_ev_bb) - float(value.gap_bb)) <= 0.0001

static func _priority(fact: Dictionary) -> int:
	if fact.sample_count < 2: return 0
	return 2 if fact.assessment == "compare" and fact.gap_bb > 0 else 1

static func _before(a: Dictionary, b: Dictionary) -> bool:
	var left := _priority(a)
	var right := _priority(b)
	if left != right: return left > right
	if left == 2 and a.gap_bb != b.gap_bb: return a.gap_bb > b.gap_bb
	return a.decision_id < b.decision_id

static func _same_action(fact: Dictionary) -> bool:
	return fact.actual_action == fact.alternative_action and (
		fact.actual_action not in ["raise", "all_in"] or fact.actual_amount == fact.alternative_amount)

static func _action(kind: String, amount: int, english: bool) -> String:
	var names := {"fold": "Fold" if english else "弃牌", "check": "Check" if english else "让牌",
		"call": "Call" if english else "跟注", "raise": "Raise" if english else "加注",
		"all_in": "All-in" if english else "全下"}
	var text: String = names[kind]
	if kind in ["raise", "all_in"]:
		text += (" to %d chips in this betting round" if english else "至本轮累计 %d 筹码") % amount
	return text

static func _explain(fact: Dictionary, english: bool) -> Dictionary:
	var actual := _action(fact.actual_action, int(fact.actual_amount), english)
	var alternative := _action(fact.alternative_action, int(fact.alternative_amount), english)
	var explanation: String
	if _same_action(fact):
		explanation = _text(english,
			"在 %d 个共同样本中，实际行动 %s 的估计收益为 %.2f BB，与本模型的最高估值行动一致。",
			"Across %d shared samples, your %s has an estimated return of %.2f BB and matches the highest-valued action in this model.") % [int(fact.sample_count), actual, float(fact.actual_ev_bb)]
	else:
		explanation = _text(english,
			"在 %d 个共同样本中，实际 %s 的估计收益为 %.2f BB，备选 %s 为 %.2f BB，估值差 %.2f BB。",
			"Across %d shared samples, your %s has an estimated return of %.2f BB versus %.2f BB for %s, a gap of %.2f BB.")
		# English puts the alternative's estimate before its action name.
		var values := [int(fact.sample_count), actual, float(fact.actual_ev_bb)]
		values.append_array([float(fact.alternative_ev_bb), alternative] if english else [alternative, float(fact.alternative_ev_bb)])
		values.append(float(fact.gap_bb))
		explanation = explanation % values
	var next_step: String
	if fact.sample_count < 2:
		explanation += _text(english, "样本不足以估计误差，暂不判断行动优劣。", " There are too few samples to estimate error or rank these choices reliably.")
		next_step = _text(english, "先保留不确定性，获得更多样本后再比较；不要根据本手最终输赢倒推行动对错。", "Keep the uncertainty explicit and compare again with more samples; do not judge the decision by this hand's final outcome.")
	elif _same_action(fact):
		next_step = _text(english, "可以保留这次思考过程，但仍要核对投入和后续风险；最高估值不代表唯一或最优策略。", "Keep the reasoning, while checking the investment and future risk; the highest estimate is not a unique or optimal strategy.")
	elif fact.assessment == "close" or fact.gap_bb == 0:
		explanation += _text(english, "当前样本没有区分出明确差异，不据此认定原行动需要纠正。", " The current samples do not distinguish a clear difference, so this does not establish that your action needs correcting.")
		next_step = _text(english, "下次先比较两种选择的投入和后续风险，不要仅凭这次估值排序改变打法。", "Compare the investment and future risk of both choices before changing your play based on this ranking.")
	else:
		explanation += _text(english, "差异超出当前配对采样误差，值得优先回看；范围和后续行动假设仍会影响结果。", " The gap exceeds the current paired sampling uncertainty and merits review; range and continuation assumptions still affect it.")
		next_step = _next_step(fact, english)
	if fact.actual_ev_bb < 0 and fact.alternative_ev_bb < 0 and not _same_action(fact):
		explanation += _text(english, "两种估值都为负；较高估值只表示预期损失较少。", " Both estimates are negative; the higher estimate only means a smaller expected loss.")
	return {"decision_id": int(fact.decision_id), "explanation": explanation, "next_step": next_step}

static func _next_step(fact: Dictionary, english: bool) -> String:
	if fact.actual_action == "raise" and fact.alternative_action == "raise":
		return _text(english, "下次比较这两个加注总额，核对额外投入和剩余筹码，再决定下注尺度。", "Compare these two raise totals, the additional investment and the remaining stack before choosing a size.")
	match fact.alternative_action:
		"fold":
			return _text(english, "下次面对类似价格，先比较继续投入与弃牌的估值；不要因为已经投入筹码就继续。", "At a similar price, compare committing more chips with folding; chips already invested are not a reason to continue.")
		"check":
			return _text(english, "下次允许免费让牌时，先比较保留筹码与原行动的收益和后续风险。", "When checking is free, compare preserving chips with the estimated return and future risk of your original action.")
		"call":
			return _text(english, "下次先核对跟住所需的投入，再与原行动的估值和后续风险比较。", "Check the cost of calling, then compare it with the estimated return and future risk of your original action.")
		"raise":
			return _text(english, "下次比较列出的加注总额与原行动，考虑对手继续参与后可能需要承担的投入。", "Compare the listed raise total with your original action, including the potential investment if opponents continue.")
		_:
			# An all-in may be a call or a raise; never assume it creates pressure.
			return _text(english, "全下会投入剩余筹码；先核对有效筹码和后续风险，不要仅凭一次估值差照做。", "An all-in commits the remaining stack; check effective stacks and risk before following a single estimated gap.")

static func _text(english: bool, chinese: String, translated: String) -> String:
	return translated if english else chinese
