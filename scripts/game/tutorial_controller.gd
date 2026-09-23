class_name TutorialController
extends RefCounted

const HANDS := ["G1", "G2", "G3"]
const SEEDS := {"G1": 4, "G2": 16, "G3": 788}

var game: PokerRound
var lesson_id := ""
var completed := false
var _phase := ""
var _last_action := ""
var _has_acted := false

static func hand_title(id: String) -> String:
	match id:
		"G1": return GameLocalization.present("跟我走一遍")
		"G2": return GameLocalization.present("学会放下")
		"G3": return GameLocalization.present("这次你来")
	return GameLocalization.present("新手教程")

static func index_for(id: String) -> int:
	return HANDS.find(id)

static func lessons() -> Array:
	var result := []
	for id in HANDS:
		result.append({"id": id, "title": hand_title(id)})
	return result

func start(id: String = "G1") -> void:
	lesson_id = id if HANDS.has(id) else "G1"
	completed = false
	_phase = "free" if lesson_id == "G3" else "intro"
	_last_action = ""
	_has_acted = false
	game = PokerRound.new()
	game.shuffle_rng.seed = SEEDS[lesson_id]
	game.start_new_match(1, "simple", {"mode": "tutorial", "initial_stack": 1000, "small_blind": 10, "big_blind": 20})

func restart() -> void:
	start(lesson_id)

func current_step() -> Dictionary:
	if game == null:
		return _step("empty", "", "", [], false)
	if completed:
		return _result_step()
	match lesson_id:
		"G1": return _first_step()
		"G2": return _second_step()
		"G3": return _third_step()
	return _step("empty", "", "", [], false)

func advance() -> bool:
	if completed:
		return false
	match lesson_id:
		"G1":
			match _phase:
				"intro": _phase = "hole"
				"hole": _phase = "blinds"
				"blinds": _phase = "call"
				"flop": _phase = "flop_opponent"
				"turn": _phase = "turn_opponent"
				"river": _phase = "river_opponent"
				_: return false
		"G2":
			match _phase:
				"intro": _phase = "hole"
				"hole": _phase = "call"
				"flop": _phase = "flop_opponent"
				_: return false
		"G3": return false
		_: return false
	return true

func allows_action(action: String, amount: int = 0) -> bool:
	if completed or game == null or not game.is_human_turn():
		return false
	if lesson_id == "G1" and not ((_phase == "call" and action == TableState.ACTION_CALL) or (_phase in ["flop_check", "turn_check", "river_check"] and action == TableState.ACTION_CHECK)):
		return false
	if lesson_id == "G2" and not ((_phase == "call" and action == TableState.ACTION_CALL) or (_phase == "fold" and action == TableState.ACTION_FOLD)):
		return false
	if lesson_id == "G3" and _phase != "free":
		return false
	var legal := game.get_legal_actions(0)
	if not legal.actions.has(action):
		return false
	if action == TableState.ACTION_RAISE:
		return amount >= int(legal.min_raise_to) and amount <= int(legal.max_raise_to)
	return true

func submit_action(action: String, amount: int = 0) -> bool:
	if not allows_action(action, amount):
		return false
	if not game.apply_action(action, amount, "教程动作"):
		return false
	_last_action = action
	_has_acted = true
	if game.stage == TableState.STAGE_HAND_OVER:
		_finish()
		return true
	match lesson_id:
		"G1":
			match _phase:
				"call": _phase = "preflop_opponent"
				"flop_check": _phase = "turn"
				"turn_check": _phase = "river"
		"G2":
			if _phase == "call":
				_phase = "preflop_opponent"
	return true

func opponent_can_act() -> bool:
	if completed or game == null or not game.is_ai_turn():
		return false
	if lesson_id == "G3":
		return _phase == "free"
	return _phase in ["preflop_opponent", "flop_opponent", "turn_opponent", "river_opponent"]

func opponent_decision() -> Dictionary:
	if not opponent_can_act() or lesson_id == "G3":
		return {}
	var action := TableState.ACTION_RAISE if lesson_id == "G2" and _phase == "flop_opponent" else TableState.ACTION_CHECK
	var amount := 40 if action == TableState.ACTION_RAISE else 0
	var legal := game.get_legal_actions(game.current_player_index)
	if not legal.actions.has(action):
		return {}
	if action == TableState.ACTION_RAISE and (amount < int(legal.min_raise_to) or amount > int(legal.max_raise_to)):
		return {}
	return {"action_type": action, "amount": amount}

func after_opponent_action() -> void:
	if game == null or completed:
		return
	if game.stage == TableState.STAGE_HAND_OVER:
		_finish()
		return
	if lesson_id == "G3":
		_last_action = ""
		return
	if lesson_id == "G1":
		match _phase:
			"preflop_opponent": _phase = "flop"
			"flop_opponent": _phase = "flop_check"
			"turn_opponent": _phase = "turn_check"
			"river_opponent": _phase = "river_check"
	elif lesson_id == "G2":
		match _phase:
			"preflop_opponent": _phase = "flop"
			"flop_opponent": _phase = "fold"

func raise_explanation(amount: int) -> String:
	if game == null or game.players.is_empty():
		return ""
	var to_pay := maxi(0, amount - int(game.players[0].current_bet))
	return GameLocalization.present("加注到 %d，是本轮总投入；还需补 %d。") % [amount, to_pay]

func best_five() -> Array:
	if game == null or game.community_cards.size() < 5:
		return []
	return HandEvaluator.evaluate(game.players[0].hole_cards + game.community_cards).best_cards

func _first_step() -> Dictionary:
	match _phase:
		"intro": return _step("G1.intro", "先坐下", "坐吧，跟我打三手。规则用到时，我再告诉你。", ["Seat0HoleCards"], true)
		"hole": return _step("G1.hole", "看看底牌", "这是你的两张底牌，只有你能看到。", ["Seat0HoleCards"], true)
		"blinds": return _step("G1.blinds", "看看盲注", "你先放了 10，对手放了 20。桌上底池现在是 30。", ["PotDisplay"], true)
		"call": return _step("G1.call", "跟注入局", "再跟 10，就能看翻牌。点跟注。", ["Action_call"], false)
		"preflop_opponent": return _step("G1.preflop_opponent", "等对手行动", "对手还可以行动，看看他怎么做。", ["PotDisplay"], false)
		"flop": return _step("G1.flop", "看翻牌", "公共牌双方都能用。你和桌上的 5 凑成了一对。", ["CommunityCards"], true)
		"flop_opponent": return _step("G1.flop_opponent", "等对手行动", "对手先行动。", ["CommunityCards"], false)
		"flop_check": return _step("G1.flop_check", "让牌看转牌", "没有人下注。点让牌，继续看下一张。", ["Action_check"], false)
		"turn": return _step("G1.turn", "看转牌", "第四张公共牌是转牌。你的一对还在。", ["CommunityCards"], true)
		"turn_opponent": return _step("G1.turn_opponent", "等对手行动", "对手先行动。", ["CommunityCards"], false)
		"turn_check": return _step("G1.turn_check", "让牌看河牌", "点让牌，再看最后一张。", ["Action_check"], false)
		"river": return _step("G1.river", "看河牌", "最后一张是河牌。接下来会比较各自最好的五张牌。", ["CommunityCards"], true)
		"river_opponent": return _step("G1.river_opponent", "等对手行动", "对手先行动。", ["CommunityCards"], false)
		"river_check": return _step("G1.river_check", "进入摊牌", "点让牌，亮牌看结果。", ["Action_check"], false)
	return _step("G1.unknown", "", "", [], false)

func _second_step() -> Dictionary:
	match _phase:
		"intro": return _step("G2.intro", "第二手", "教学筹码补齐到 1000。接下来练习及时收手。", ["Seat0StackAmount"], true)
		"hole": return _step("G2.hole", "看弱牌", "这次底牌是 8 和 4，不成对也不同花。先看翻牌。", ["Seat0HoleCards"], true)
		"call": return _step("G2.call", "跟注看翻牌", "再跟 10 看翻牌。点跟注。", ["Action_call"], false)
		"preflop_opponent": return _step("G2.preflop_opponent", "等对手行动", "对手还要行动。", ["PotDisplay"], false)
		"flop": return _step("G2.flop", "看翻牌", "这三张牌还没帮你成对。先看对手行动。", ["CommunityCards"], true)
		"flop_opponent": return _step("G2.flop_opponent", "等对手行动", "对手先行动。", ["CommunityCards"], false)
		"fold": return _step("G2.fold", "练习弃牌", "继续要再付 40。这次点弃牌，留下其余筹码。", ["Action_fold"], false)
	return _step("G2.unknown", "", "", [], false)

func _third_step() -> Dictionary:
	var body := "教学筹码补齐到 1000。你拿到同花 A-K，这次你做主。"
	var focus: Array[String] = ["Seat0HoleCards"]
	if _has_acted:
		body = "看看牌桌和下注额，再选一个合法行动。"
		focus = ["PotDisplay"]
	if _last_action != "":
		body = _action_feedback()
		focus = ["PotDisplay"]
	if game.is_ai_turn() and _last_action.is_empty():
		body = "对手正在行动，看看牌桌变化。"
	elif game.community_cards.size() > 0 and _last_action == "":
		body = "看看公共牌和下注额，再选一个合法行动。"
		focus = ["CommunityCards"]
	return _step("G3.free", "自己决定", body, focus, false)

func _result_step() -> Dictionary:
	var outcome := "这手已结束。你的筹码现在是 %d。"
	var args: Array = [int(game.players[0].stack)]
	var focus: Array[String] = ["Seat0StackAmount"]
	if lesson_id == "G1":
		var hand := HandEvaluator.evaluate(game.players[0].hole_cards + game.community_cards)
		var opponent := HandEvaluator.evaluate(game.players[1].hole_cards + game.community_cards)
		outcome = "你的%s胜过对手的%s。亮起的五张牌就是你的最佳牌型。"
		args = [GameLocalization.present(str(hand.rank_name)), GameLocalization.present(str(opponent.rank_name))]
		focus = ["best_five"]
	elif lesson_id == "G2":
		outcome = "弃牌后保留了 %d 筹码。下一手会重新补齐教学筹码。"
		args = [int(game.players[0].stack)]
	elif game.players[0].status == TableState.STATUS_FOLDED:
		outcome = "你选择弃牌，保留了 %d 筹码。"
		args = [int(game.players[0].stack)]
	elif game.last_hand_human_won:
		outcome = "这手赢了 %d 筹码，现在有 %d。"
		args = [int(game.last_hand_human_delta), int(game.players[0].stack)]
	else:
		outcome = "这手结束，现在有 %d 筹码。"
		args = [int(game.players[0].stack)]
	return _step("%s.result" % lesson_id, "本手结束", outcome, focus, false, args)

func _action_feedback() -> String:
	match _last_action:
		TableState.ACTION_FOLD: return "你选择弃牌，保留剩余筹码。"
		TableState.ACTION_CHECK: return "你让牌了，没有再投入筹码。"
		TableState.ACTION_CALL: return "你刚才选择了跟注。现在看看对手的下注。"
		TableState.ACTION_RAISE: return "你加注了，对手需要决定是否跟上。"
		TableState.ACTION_ALL_IN: return "你把剩余筹码全下了，等待对手回应。"
	return "看看牌桌，再选一个合法行动。"

func _step(id: String, title: String, body: String, focus: Array[String], can_continue: bool, args: Array = []) -> Dictionary:
	var translated := GameLocalization.present(body)
	return {"id": id, "title": GameLocalization.present(title), "text": translated % args if not args.is_empty() else translated, "focus": focus, "can_continue": can_continue}

func _finish() -> void:
	completed = true
	_phase = "result"
