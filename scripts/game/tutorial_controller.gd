class_name TutorialController
extends RefCounted

const COURSE_VERSION := 1

var game: PokerRound
var lesson_id := ""
var step_index := 0
var completed := false
var _selected: Array = []
var _t7_finished := false
var _t7_last_action := ""
var _settlement := {}

static func lessons() -> Array:
	return [
		{"id":"T1","title":"认识牌桌","summary":"分清区域，再从七张牌中选出最佳五张。"},
		{"id":"T2","title":"牌型大小","summary":"认识九类牌型、踢脚牌和公共牌平分。"},
		{"id":"T3","title":"轮到我怎么办","summary":"在真实合法局面中执行五种行动。"},
		{"id":"T4","title":"完整打一手","summary":"从翻前跟到河牌，再查看真实摊牌。"},
		{"id":"T5","title":"庄位与盲注","summary":"理解多人桌与单挑的行动顺序和轮换。"},
		{"id":"T6","title":"结算进阶","summary":"用真实结算结果认识主池、边池、返还与平分。"},
		{"id":"T7","title":"入门自测","summary":"按实际合法选项完成一手牌。"}
	]

func start(id: String) -> void:
	lesson_id = id if id in PracticeStore.LESSONS else "T1"; game = null; step_index = 0; completed = false; _selected = []; _t7_finished = false; _t7_last_action = ""; _settlement = {}
	match lesson_id:
		"T3": _prepare_t3(0)
		"T4": _new_game(1, 4004)
		"T5": _new_game(3, 5005)
		"T6": _prepare_t6()
		"T7": _new_game(1, 7007)

func restart() -> void: start(lesson_id)

func current_step() -> Dictionary:
	if completed: return {"title":"课程完成","text":"你已完成本课；可以重练。","kind":"summary","options":[],"cards":[],"detail":_summary()}
	var r := {"title":"","text":"","kind":"choice","options":[],"cards":[],"detail":""}
	match lesson_id:
		"T1": _step_t1(r)
		"T2": _step_t2(r)
		"T3": _step_t3(r)
		"T4": _step_t4(r)
		"T5": _step_t5(r)
		"T6": _step_t6(r)
		"T7": _step_t7(r)
	return r

func submit(choice: String) -> Dictionary:
	if completed: return {"ok":false,"message":"本课已经完成。","completed":true}
	var ok := false
	match lesson_id:
		"T1": ok = _submit_t1(choice)
		"T2": ok = choice == _t2_answer()
		"T3": ok = _submit_t3(choice)
		"T4": ok = _submit_t4(choice)
		"T5": ok = _submit_t5(choice)
		"T6": ok = choice == [str(_settlement.side.side_pots[0].amount),str(_settlement.side.side_pots[1].amount),str(_settlement.refund_amount),"split" if _settlement.split.side_pots[0].payouts.size() == 2 else "winner"][step_index]
		"T7": ok = _submit_t7(choice)
	if ok and not completed and lesson_id != "T7":
		step_index += 1
		if step_index >= {"T1":9,"T2":3,"T3":5,"T4":5,"T5":3,"T6":4,"T7":1}.get(lesson_id, 1): completed = true
	return {"ok":ok,"message":"回答正确，观察牌面和筹码的变化。" if ok else "请按提示重试。","completed":completed}

func _new_game(ai_count: int, seed: int) -> void:
	game = PokerRound.new()
	game.shuffle_rng.seed = seed
	game.start_new_match(ai_count, "simple", {"mode":"tutorial","initial_stack":1000,"small_blind":10,"big_blind":20})

func _t1_cards() -> Array: return [c(14,"S"),c(13,"S"),c(12,"S"),c(11,"S"),c(10,"S"),c(2,"D"),c(3,"C")]

func _step_t1(r: Dictionary) -> void:
	var ids := ["hole_cards","community_cards","chips","pot"]
	var labels := ["我的两张底牌","桌面中央的公共牌","座位旁的筹码","中央底池"]
	r.cards = _t1_cards()
	if step_index < 4:
		r.title = "指认牌桌区域"; r.text = ["底牌在哪一组？","公共牌在哪一组？","筹码信息在哪一组？","底池在哪一组？"][step_index]
		r.kind = "region"
		for i in range(ids.size()):
			r.options.append({"id":ids[i],"label":labels[i]})
		r.detail = "示意牌前两张为底牌、后五张为公共牌；实际桌面分别显示筹码与底池。"
		return
	r.title = "从七张牌中选最佳五张"; r.text = "请选择第 %d 张；只能选择当前七张牌且不能重复。" % (_selected.size() + 1); r.kind = "select_cards"
	for card in r.cards:
		var id := CardUtil.card_key(card)
		if not _selected.has(id): r.options.append({"id":id,"label":CardUtil.card_label(card)})
	r.detail = "已选：%s。完成后会与七张牌的最佳评估比较。" % " ".join(_selected)

func _submit_t1(choice: String) -> bool:
	if step_index < 4: return choice == ["hole_cards","community_cards","chips","pot"][step_index]
	var cards := {}; for card in _t1_cards(): cards[CardUtil.card_key(card)] = card
	if not cards.has(choice) or _selected.has(choice): return false
	_selected.append(choice)
	if _selected.size() < 5: return true
	var chosen := []; for key in _selected: chosen.append(cards[key])
	if HandEvaluator.compare_results(HandEvaluator.evaluate(chosen), HandEvaluator.evaluate(_t1_cards())) != 0:
		_selected = []; step_index = 4; return false
	return true

func _step_t2(r: Dictionary) -> void:
	var a := [c(14,"S"),c(14,"H"),c(13,"D"),c(9,"C"),c(4,"S")]
	var b := [c(14,"D"),c(14,"C"),c(12,"H"),c(9,"D"),c(4,"H")]
	var board := [c(14,"S"),c(13,"H"),c(12,"D"),c(11,"C"),c(10,"S")]
	r.title = "牌型大小"
	if step_index == 0:
		r.text = "九类牌型中，哪个高于四条？"; r.options = [{"id":"straight_flush","label":"同花顺"},{"id":"four_kind","label":"四条"}]; r.cards = PokerReference.hands()[0].cards
		r.detail = "从高到低：同花顺、四条、葫芦、同花、顺子、三条、两对、一对、高牌。皇家同花顺属于同花顺。"
	elif step_index == 1:
		r.text = "两手都是一对 A，哪一手获胜？"; r.options = [{"id":"a","label":"A 对，K 踢脚"},{"id":"b","label":"A 对，Q 踢脚"}]; r.cards = a + b
		r.detail = "实际比较结果 %d：K 踢脚更大。" % HandEvaluator.compare_results(HandEvaluator.evaluate(a), HandEvaluator.evaluate(b))
	else:
		r.text = "公共牌已经构成双方最佳顺子，双方结果是什么？"; r.options = [{"id":"tie","label":"平分底池"},{"id":"hole","label":"比较无关底牌"}]; r.cards = board
		r.detail = "双方七张牌评估均为 %s，公共牌可被双方使用。" % HandEvaluator.evaluate(board).rank_name

func _prepare_t3(index: int) -> void:
	_new_game(1, 3000 + index)
	if index == 0:
		game.apply_action(TableState.ACTION_CALL, 0, "教程预设")
		game.apply_action(TableState.ACTION_CHECK, 0, "教程预设")
		game.apply_action(TableState.ACTION_CHECK, 0, "教程预设")

func _step_t3(r: Dictionary) -> void:
	_prepare_t3(step_index)
	var action: String = [TableState.ACTION_CHECK,TableState.ACTION_CALL,TableState.ACTION_FOLD,TableState.ACTION_RAISE,TableState.ACTION_ALL_IN][step_index]
	var legal := game.get_legal_actions(game.current_player_index)
	r.title = "实际执行：" + _action_label(action); r.text = "请执行 %s。" % _action_label(action); r.kind = "action"
	r.options = [{"id":action,"label":_action_label(action) + ("到 100" if action == TableState.ACTION_RAISE else "")}]
	r.cards = game.players[game.current_player_index].hole_cards + game.community_cards
	r.detail = "阶段：%s；需跟注 %d；当前下注 %d；加注到 %d–%d。加注到 100 是本轮总投入，额外支付 %d。" % [game.describe_stage(),game.get_to_call(game.current_player_index),game.current_bet,legal.min_raise_to,legal.max_raise_to,100 - game.players[game.current_player_index].current_bet]

func _submit_t3(choice: String) -> bool:
	_prepare_t3(step_index)
	var action: String = [TableState.ACTION_CHECK,TableState.ACTION_CALL,TableState.ACTION_FOLD,TableState.ACTION_RAISE,TableState.ACTION_ALL_IN][step_index]
	return choice == action and game.apply_action(action, 100 if action == TableState.ACTION_RAISE else 0, "教程动作")

func _auto_opponents() -> void:
	var guard := 0
	while game != null and game.stage != TableState.STAGE_HAND_OVER and game.current_player_index != 0 and game.current_player_index >= 0 and guard < 20:
		var legal := game.get_legal_actions(game.current_player_index)
		var action := TableState.ACTION_CHECK if legal.actions.has(TableState.ACTION_CHECK) else TableState.ACTION_CALL
		if not legal.actions.has(action): action = TableState.ACTION_FOLD
		if not game.apply_action(action, 0, "教程预设对手"): break
		guard += 1

func _step_t4(r: Dictionary) -> void:
	_auto_opponents()
	if step_index == 4:
		r.title = "查看摊牌"; r.text = "本手已经完成摊牌结算。"; r.options = [{"id":"showdown","label":"查看结果"}]; r.cards = game.community_cards; r.detail = _game_result_detail(); return
	var action := TableState.ACTION_CALL if step_index == 0 else TableState.ACTION_CHECK
	r.title = ["翻前","翻牌","转牌","河牌"][step_index] + "行动"; r.text = "轮到你时执行%s，预设对手会真实跟注或让牌。" % _action_label(action)
	r.options = [{"id":action,"label":_action_label(action)}]; r.cards = game.players[0].hole_cards + game.community_cards
	r.detail = "阶段：%s；底池：%d；需跟注：%d。" % [game.describe_stage(),game.total_pot(),game.get_to_call(0)]

func _submit_t4(choice: String) -> bool:
	if step_index == 4: return choice == "showdown" and game.stage == TableState.STAGE_HAND_OVER
	_auto_opponents(); var action := TableState.ACTION_CALL if step_index == 0 else TableState.ACTION_CHECK
	return choice == action and game.current_player_index == 0 and game.apply_action(action, 0, "教程完整手牌")

func _step_t5(r: Dictionary) -> void:
	r.title = "庄位与盲注"
	if step_index == 0:
		r.text = "四人桌翻前，当前实际轮到哪个座位行动？"; r.options = [{"id":"seat_%d" % game.current_player_index,"label":"%d 号位" % game.current_player_index},{"id":"seat_%d" % game.big_blind_player_index,"label":"%d 号位（大盲）" % game.big_blind_player_index}]
		r.detail = "按钮 %d；小盲 %d；大盲 %d；当前行动者 %d。" % [game.button_index,game.small_blind_player_index,game.big_blind_player_index,game.current_player_index]
	elif step_index == 1:
		_new_game(1, 5051); r.text = "单挑中，按钮位与小盲的关系及翻前行动顺序是什么？"; r.options = [{"id":"button_small_blind","label":"按钮兼小盲，翻前先行动"},{"id":"big_blind_first","label":"大盲翻前先行动"}]
		r.detail = "实际按钮 %d，小盲 %d，大盲 %d，当前行动者 %d。" % [game.button_index,game.small_blind_player_index,game.big_blind_player_index,game.current_player_index]
	else:
		if game.players.size() != 2: _new_game(1, 5052)
		r.text = "完成当前手牌并开始下一手，按钮会如何变化？"; r.options = [{"id":"rotate","label":"按钮轮到另一位有筹码玩家"},{"id":"fixed","label":"按钮保持不动"}]; r.detail = "选择后将结束本手并开始下一手，观察庄位标记的位置变化。"

func _submit_t5(choice: String) -> bool:
	if step_index == 0: return choice == "seat_%d" % game.current_player_index
	if step_index == 1: return choice == "button_small_blind"
	if choice != "rotate": return false
	var before := game.button_index
	while game.stage != TableState.STAGE_HAND_OVER:
		if not game.apply_action(TableState.ACTION_FOLD, 0, "教程轮换演示"): return false
	game.start_next_hand()
	return game.button_index != before

func _prepare_t6() -> void:
	var side := _fixture([50,100,200,200],[c(14,"H"),c(14,"S"),c(13,"H"),c(13,"S"),c(12,"H"),c(12,"S"),c(10,"H"),c(10,"S")],[c(2,"C"),c(3,"D"),c(4,"H"),c(9,"S"),c(11,"D")])
	var refund := _fixture([1000,20],[c(14,"H"),c(14,"S"),c(7,"H"),c(9,"H")],[c(2,"C"),c(7,"D"),c(9,"S"),c(11,"H"),c(3,"C")])
	var split := _fixture([100,100],[c(2,"H"),c(3,"S"),c(4,"H"),c(5,"S")],[c(14,"C"),c(13,"D"),c(12,"H"),c(11,"S"),c(10,"D")])
	game = side; _settlement = {"side":side,"refund":refund,"split":split,"refund_amount":1000 - int(refund.players[0].total_bet),"conserved":_total(side)==550 and _total(refund)==1020 and _total(split)==200}

func _fixture(contributions: Array, holes: Array, board: Array) -> PokerRound:
	var target := PokerRound.new(); target.shuffle_rng.seed = 6060 + contributions.size(); target.start_new_match(contributions.size()-1,"simple",{"mode":"tutorial","initial_stack":1000,"small_blind":10,"big_blind":20})
	target.community_cards = CardUtil.clone_cards(board)
	for i in range(target.players.size()):
		target.players[i].hole_cards = [holes[i*2],holes[i*2+1]]; target.players[i].stack = 0; target.players[i].current_bet = int(contributions[i]); target.players[i].total_bet = int(contributions[i]); target.players[i].status = TableState.STATUS_ALL_IN
	target._hand_starting_stacks = contributions.duplicate()
	target.stage = TableState.STAGE_RIVER
	target.current_player_index = -1
	target.deck.cards = CardUtil.full_deck().filter(func(card): return not holes.has(card) and not board.has(card))
	target._showdown()
	return target

func _step_t6(r: Dictionary) -> void:
	var side: PokerRound = _settlement.side; var refund: PokerRound = _settlement.refund; var split: PokerRound = _settlement.split
	r.title = "结算进阶"; r.kind = "settlement_question"
	if step_index == 0: r.text = "四位玩家投入 50、100、200、200，主池是多少？"; r.options = [{"id":"200","label":"200"},{"id":"250","label":"250"}]; r.cards = side.community_cards; r.detail = "按每人最低投入 50 形成 200 主池；其余按下一档投入分层。"
	elif step_index == 1: r.text = "同一局中，第一个边池是多少？"; r.options = [{"id":"150","label":"150"},{"id":"200","label":"200"}]; r.detail = "第二层：三位玩家各追加 50，形成 150 边池；最后两位再各追加 100，形成 200 边池。"
	elif step_index == 2: r.text = "另一局投入 1000 与 20，无法被跟注的筹码返还多少？"; r.options = [{"id":"980","label":"980"},{"id":"1000","label":"1000"}]; r.detail = "实际可争夺底池 %d；返还 %d。" % [refund.total_pot(),_settlement.refund_amount]
	else: r.text = "公共牌构成双方相同顺子，200 底池如何结算？"; r.options = [{"id":"split","label":"各得 100，平分底池"},{"id":"winner","label":"按底牌花色决胜"}]; r.detail = "双方各得 100。投入合计 200，派奖合计 200。"

func _step_t7(r: Dictionary) -> void:
	_auto_opponents(); r.title = "入门自测"; r.cards = game.players[0].hole_cards + game.community_cards
	if _t7_finished:
		r.text = "本手已结束。未被跟注的多余筹码应怎样处理？"; r.options = [{"id":"refund","label":"返还下注者"},{"id":"pot","label":"放入无人可争夺底池"}]; r.detail = _game_result_detail(); return
	var legal := game.get_legal_actions(0); r.text = "请选择当前真实合法行动。加注会使用最小合法加注到 %d。" % legal.min_raise_to
	var options := []
	for action in legal.actions:
		options.append({"id":action,"label":_action_label(action) + ("到 %d" % legal.min_raise_to if action == TableState.ACTION_RAISE else "")})
	r.options = options
	r.detail = "阶段：%s；需跟注 %d；底池 %d。每个分支都能继续到结算。" % [game.describe_stage(),game.get_to_call(0),game.total_pot()]

func _submit_t7(choice: String) -> bool:
	if _t7_finished:
		if choice != "refund": return false
		completed = true; return true
	_auto_opponents(); var legal := game.get_legal_actions(0)
	if game.current_player_index != 0 or not legal.actions.has(choice): return false
	_t7_last_action = choice
	var ok := game.apply_action(choice, legal.min_raise_to if choice == TableState.ACTION_RAISE else 0, "教程自测")
	_auto_opponents()
	if game.stage == TableState.STAGE_HAND_OVER: _t7_finished = true
	return ok

func _total(target: PokerRound) -> int:
	var total := 0
	for p in target.players: total += int(p.stack)
	return total
func _action_label(action: String) -> String: return {TableState.ACTION_CHECK:"让牌",TableState.ACTION_CALL:"跟注",TableState.ACTION_FOLD:"弃牌",TableState.ACTION_RAISE:"加注",TableState.ACTION_ALL_IN:"全下"}.get(action,action)
func _game_result_detail() -> String: return "结算：%s；你的筹码 %d。" % [game.last_message,game.players[0].stack]
func _summary() -> String: return "你已完成本课练习。可以重练巩固或进入下一课；教程进度独立保存，不影响普通对战统计。"
func c(rank: int, suit: String) -> Dictionary: return CardUtil.make_card(rank,suit)

func _t2_answer() -> String:
	if step_index == 0:
		return "straight_flush" if HandEvaluator.compare_results(HandEvaluator.evaluate(PokerReference.hands()[0].cards), HandEvaluator.evaluate(PokerReference.hands()[1].cards)) > 0 else "four_kind"
	if step_index == 1:
		var a := [c(14,"S"),c(14,"H"),c(13,"D"),c(9,"C"),c(4,"S")]
		var b := [c(14,"D"),c(14,"C"),c(12,"H"),c(9,"D"),c(4,"H")]
		return "a" if HandEvaluator.compare_results(HandEvaluator.evaluate(a),HandEvaluator.evaluate(b)) > 0 else "b"
	var board := [c(14,"S"),c(13,"H"),c(12,"D"),c(11,"C"),c(10,"S")]
	return "tie" if HandEvaluator.compare_results(HandEvaluator.evaluate(board + [c(2,"D"),c(3,"D")]),HandEvaluator.evaluate(board + [c(4,"H"),c(5,"H")])) == 0 else "hole"
