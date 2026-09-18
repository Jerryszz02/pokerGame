extends SceneTree
var failures := 0
func _init() -> void: call_deferred("_run")
func c(rank: int, suit: String) -> Dictionary: return CardUtil.make_card(rank, suit)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var board := [c(2,"C"), c(7,"D"), c(9,"S"), c(4,"H")]
	var holes := [[c(14,"S"),c(14,"H")],[c(13,"S"),c(13,"H")]]
	var game := fixture(board, holes, [100,100], [100,0], c(13,"C"))
	check(game.apply_action(TableState.ACTION_CALL), "real final call locks heads-up hand")
	var record := game.completed_hand_record()
	var luck := AllInLuck.calculate(record, {"seed":9,"time_budget_ms":10000})
	check(luck.qualifying and luck.worlds == 44 and luck.exhaustive, "turn lock enumerates every remaining card")
	if luck.qualifying:
		check(is_equal_approx(luck.expected_payout, 200.0 * 42.0 / 44.0), "aces vs kings has exactly two losing river cards")
		check(luck.actual_payout == 0 and is_equal_approx(luck.delta_bb, -luck.expected_payout / game.big_blind), "actual loss compared to conditional expectation in BB")
		check(is_equal_approx(luck.variance_bb2, 40000.0 * 42.0 / 44.0 * 2.0 / 44.0 / pow(game.big_blind,2)), "exact population payout variance")
	var corrupt := record.duplicate(true)
	corrupt.pots[0].payouts[0].amount += 1
	check(not AllInLuck.calculate(corrupt).qualifying, "corrupt real payout is unavailable")
	corrupt = record.duplicate(true)
	corrupt.pots[0].erase("winner_indices")
	check(not AllInLuck.calculate(corrupt).qualifying, "missing winners cannot invent luck")
	corrupt = record.duplicate(true)
	corrupt.frames.back().stage = "turn"
	check(not AllInLuck.calculate(corrupt).qualifying, "incomplete hand is unavailable")
	var cancel := CoachCancellation.new()
	cancel.cancel()
	check(not AllInLuck.calculate(record, {"cancellation":cancel}).qualifying, "cancelled luck returns no sample")
	var json_record: Dictionary = JSON.parse_string(JSON.stringify(record))
	check(AllInLuck.calculate(json_record).qualifying, "JSON integral floats preserve real lock")

	var wheel := [c(2,"H"),c(3,"D"),c(4,"S"),c(5,"C")]
	var tied := fixture(wheel, [[c(14,"S"),c(14,"H")],[c(12,"S"),c(12,"H")],[c(14,"C"),c(14,"D")]], [100,1,100], [100,500,0], c(9,"H"))
	tied.players[1].status = TableState.STATUS_FOLDED
	check(tied.apply_action(TableState.ACTION_CALL), "tie fixture final call")
	var tie_record := tied.completed_hand_record()
	var tie := AllInLuck.calculate(tie_record)
	check(tie.qualifying and tie.worlds == 44, "folded cards are not blockers")
	if tie.qualifying:
		check(tie.actual_payout == 100 and tie.expected_payout == 100, "engine assigns odd chip to next winner after dealer")
		check(tie.variance_bb2 == 0 and tie.delta_bb == 0, "forced tie never invents a luck z score")
	for frame in tie_record.frames: frame.players[1].hole_cards = [c(14,"S"),c(14,"H")]
	check(AllInLuck.calculate(tie_record) == tie, "folded private cards cannot change luck")

	var side := fixture(board, [[c(14,"S"),c(14,"H")],[c(13,"S"),c(13,"H")],[c(12,"S"),c(12,"H")]], [100,40,100], [100,0,0], c(3,"D"))
	check(side.apply_action(TableState.ACTION_CALL), "side-pot fixture final call")
	var side_luck := AllInLuck.calculate(side.completed_hand_record())
	check(side_luck.qualifying and side.side_pots.size() == 2 and side_luck.actual_payout == 240, "nested pots use real eligibility and payout")

	var refund := fixture(board, [[c(14,"S"),c(14,"H")],[c(13,"S"),c(13,"H")]], [500,100], [500,0], c(13,"C"))
	refund.players[0].current_bet = 500
	refund.players[0].total_bet = 500
	check(refund.apply_action(TableState.ACTION_CHECK), "dry side pot checks into automatic runout")
	var refund_record := refund.completed_hand_record()
	var refund_luck := AllInLuck.calculate(refund_record)
	check(refund_luck.qualifying and refund_record.refunds[0].amount == 400, "uncalled excess handled by engine")
	if refund_luck.qualifying: check(refund_luck.actual_payout == 0, "refund is not luck payout")

	var river := fixture(board + [c(13,"C")], holes, [100,100], [100,0], c(3,"D"))
	river.apply_action(TableState.ACTION_CALL)
	check(not AllInLuck.calculate(river.completed_hand_record()).qualifying, "river lock has no remaining luck")
	var owed := record.duplicate(true)
	for frame in owed.frames:
		if frame.type == "action":
			frame.players[0].status = TableState.STATUS_ACTIVE
			frame.players[0].stack = 50
			frame.players[0].current_bet = 90
	check(not AllInLuck.calculate(owed).qualifying, "one live stack still owing a call is not locked")
	var preflop := fixture([],holes,[100,100],[100,0],c(13,"C"))
	preflop.stage = TableState.STAGE_PREFLOP
	preflop.deck.cards = [c(13,"C"),c(4,"H"),c(9,"S"),c(7,"D"),c(2,"C")]
	preflop.apply_action(TableState.ACTION_CALL)
	var unresolved := false
	for seed_value in range(8):
		var tiny := AllInLuck.calculate(preflop.completed_hand_record(),{"luck_worlds":2,"seed":seed_value})
		unresolved = unresolved or tiny.get("reason","") == "unresolved_variance"
	check(unresolved,"identical random outcomes cannot give a zero-variance luck score")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var positions := [{},{},{},{},{}]
	for i in range(30):
		var draw := AllInLuck._draw_board([], CardUtil.full_deck(), rng)
		check(AllInLuck._unique(draw) and draw.size() == 5, "sample deals five distinct cards")
		for j in range(5): positions[j][CardUtil.card_key(draw[j])] = true
	for seen in positions: check(seen.size() > 10, "every future board position is randomized")
	if failures == 0: print("All-in luck tests passed.")
	quit(failures)

func fixture(board: Array, holes: Array, investments: Array, stacks: Array, river: Dictionary) -> PokerRound:
	var game := PokerRound.new()
	game.start_new_match(holes.size()-1, "simple")
	game.community_cards = board.duplicate(true)
	game.stage = TableState.STAGE_RIVER if board.size() == 5 else TableState.STAGE_TURN
	game._hand_frames.clear()
	game.public_action_history.clear()
	game.current_bet = int(investments.max())
	game.button_index = 0
	game.current_player_index = 0
	game.deck.cards = [river]
	for i in range(holes.size()):
		game.players[i].hole_cards = holes[i].duplicate(true)
		game.players[i].stack = stacks[i]
		game.players[i].current_bet = maxi(0, int(investments[i]) - int(stacks[i])) if i == 0 else investments[i]
		game.players[i].total_bet = game.players[i].current_bet
		game.players[i].status = TableState.STATUS_ACTIVE if int(stacks[i]) > 0 else TableState.STATUS_ALL_IN
		game.players[i].has_acted = false
		game.players[i].last_action_bet = 0
	return game
