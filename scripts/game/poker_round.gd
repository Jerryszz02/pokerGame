class_name PokerRound
extends RefCounted

var players: Array = []
var community_cards: Array = []
var deck := Deck.new()
var shuffle_rng := RandomNumberGenerator.new()
var button_index := 0
var small_blind_player_index := -1
var big_blind_player_index := -1
var small_blind := TableState.SMALL_BLIND
var big_blind := TableState.BIG_BLIND
var current_bet := 0
var min_raise := TableState.BIG_BLIND
var stage := TableState.STAGE_HAND_OVER
var current_player_index := -1
var hand_number := 0
var winners: Array = []
var side_pots: Array = []
var last_message := "请选择设置后开始。"
var difficulty := "simple"
var event_log: Array = []
var match_over := false
var match_result := ""
var match_summary := {}
var hands_completed := 0
var max_single_hand_win := 0
var last_hand_human_delta := 0
var last_hand_human_won := false
var _human_stack_at_hand_start := TableState.INITIAL_STACK
var match_config: Dictionary = MatchConfig.normalize({})
var match_id := ""
var initial_stack := TableState.INITIAL_STACK
var _hand_frames: Array = []
var _hand_starting_stacks: Array = []
var _refunds: Array = []
var _hand_id := ""
var _assistance_viewed := false
var _hand_created_at := ""
var _completed_record: Dictionary = {}
var _hand_peak_stack := 0

func _init() -> void:
	shuffle_rng.randomize()

func start_new_match(ai_count: int, selected_difficulty: String, options: Dictionary = {}) -> void:
	var raw := options.duplicate(true)
	raw.ai_count = ai_count
	raw.difficulty = selected_difficulty
	match_config = MatchConfig.normalize(raw)
	difficulty = match_config.difficulty
	initial_stack = match_config.initial_stack
	small_blind = match_config.small_blind
	big_blind = match_config.big_blind
	match_id = _new_id("match")
	players = []
	players.append(_make_player(0, "你", true, "human", {}))
	for i in range(int(match_config.ai_count)):
		var personality := {}
		if difficulty == "hard":
			personality = PersonalityProfiles.random_profile()
		players.append(_make_player(i + 1, "AI %d" % [i + 1], false, difficulty, personality))
	button_index = 0
	hand_number = 0
	hands_completed = 0
	max_single_hand_win = 0
	last_hand_human_delta = 0
	last_hand_human_won = false
	match_over = false
	match_result = ""
	match_summary = {}
	event_log = []
	start_next_hand()

func start_next_hand() -> void:
	if players.is_empty() or match_over:
		return
	if players[0].stack <= 0 or _players_with_chips().size() < 2:
		_finish_match()
		return
	_select_positions()
	hand_number += 1
	last_hand_human_delta = 0
	last_hand_human_won = false
	_human_stack_at_hand_start = players[0].stack
	_hand_starting_stacks = []
	for p in players: _hand_starting_stacks.append(int(p.stack))
	_hand_peak_stack = int(players[0].stack)
	_hand_frames = []
	_refunds = []
	_hand_id = _new_id("hand")
	_hand_created_at = Time.get_datetime_string_from_system(true)
	_completed_record = {}
	_assistance_viewed = false
	deck = Deck.new()
	deck.rng.seed = shuffle_rng.randi()
	deck.shuffle()
	community_cards = []
	winners = []
	side_pots = []
	stage = TableState.STAGE_PREFLOP
	current_bet = 0
	min_raise = big_blind
	for player in players:
		player.hole_cards = []
		player.current_bet = 0
		player.total_bet = 0
		player.has_acted = false
		player.last_action_bet = 0
		player.last_action = ""
		player.hand_result = {}
		player.status = TableState.STATUS_ACTIVE if player.stack > 0 else TableState.STATUS_OUT
	for _round in range(2):
		for offset in range(players.size()):
			var idx := (button_index + 1 + offset) % players.size()
			if players[idx].status != TableState.STATUS_OUT:
				players[idx].hole_cards.append_array(deck.draw(1))
	last_message = "第 %d 手牌开始。" % hand_number
	_record_event("hand", "%s 庄位在 %s。" % [last_message, players[button_index].name])
	current_player_index = -1
	_append_frame("start", "发牌（收盲前）", {})
	_post_blinds()
	current_player_index = _first_preflop_actor()
	_append_frame("blinds", "收取盲注", {})
	if active_player_count() == 1:
		_award_uncontested()
	elif _all_remaining_all_in():
		_deal_to_river()
		_showdown()
	elif current_player_index == -1:
		_showdown()

func apply_action(action_type: String, amount: int = 0, action_note: String = "") -> bool:
	if current_player_index < 0 or stage == TableState.STAGE_HAND_OVER:
		return false
	var actor_index := current_player_index
	var player: Dictionary = players[current_player_index]
	if player.status != TableState.STATUS_ACTIVE:
		return false
	var legal := get_legal_actions(current_player_index)
	var actor_stack_before: int = player.stack
	if not legal.actions.has(action_type):
		return false
	match action_type:
		TableState.ACTION_FOLD:
			player.status = TableState.STATUS_FOLDED
			player.has_acted = true
			player.last_action = "Fold"
			player.last_action_note = action_note
		TableState.ACTION_CHECK:
			if get_to_call(current_player_index) != 0:
				return false
			player.has_acted = true
			player.last_action = "Check"
			player.last_action_note = action_note
		TableState.ACTION_CALL:
			_pay_to_current_bet(current_player_index)
			player.has_acted = true
			player.last_action = "Call"
			player.last_action_note = action_note
		TableState.ACTION_RAISE:
			var target := int(amount)
			if target < legal.min_raise_to or target > legal.max_raise_to:
				return false
			_raise_to(current_player_index, target)
			player.last_action = "Raise %d" % target
			player.last_action_note = action_note
		TableState.ACTION_ALL_IN:
			_all_in(current_player_index)
			player.last_action = "All-in"
			player.last_action_note = action_note
		_:
			return false
	_record_action_event(actor_index, action_type, amount, action_note)
	player.last_action_bet = current_bet
	_append_frame("action", "%s %s" % [player.name, _action_label(action_type, amount, player)], {"actor": actor_index, "type": action_type, "amount": amount, "paid": actor_stack_before - int(player.stack), "raise_to": player.current_bet, "note": action_note})
	var action_stage := stage
	_after_state_change()
	if stage == action_stage and stage != TableState.STAGE_HAND_OVER:
		_append_frame("turn", "轮到 %s" % players[current_player_index].name, {})
	return true

func get_legal_actions(player_index: int) -> Dictionary:
	if stage == TableState.STAGE_HAND_OVER or player_index < 0 or player_index >= players.size():
		return {"actions": [], "min_raise_to": 0, "max_raise_to": 0}
	var player: Dictionary = players[player_index]
	if player.status != TableState.STATUS_ACTIVE:
		return {"actions": [], "min_raise_to": 0, "max_raise_to": 0}
	var to_call := get_to_call(player_index)
	var actions := [TableState.ACTION_FOLD]
	# A shove is a raise when it exceeds the amount to call.
	if player.stack <= to_call or (_opponent_can_bet(player_index) and _raise_is_reopened(player)):
		actions.append(TableState.ACTION_ALL_IN)
	if to_call == 0:
		actions.append(TableState.ACTION_CHECK)
	else:
		actions.append(TableState.ACTION_CALL)
	var max_raise_to: int = player.current_bet + player.stack
	var min_raise_to: int = current_bet + min_raise
	if _opponent_can_bet(player_index) and _raise_is_reopened(player) and max_raise_to >= min_raise_to:
		actions.append(TableState.ACTION_RAISE)
	return {"actions": actions, "min_raise_to": min_raise_to, "max_raise_to": max_raise_to}

func _raise_is_reopened(player: Dictionary) -> bool:
	if not player.has_acted or str(player.last_action) == "Check":
		return true
	return current_bet - int(player.get("last_action_bet", current_bet)) >= min_raise

func _opponent_can_bet(player_index: int) -> bool:
	for i in range(players.size()):
		if i != player_index and players[i].status == TableState.STATUS_ACTIVE and players[i].stack > 0:
			return true
	return false

func get_to_call(player_index: int) -> int:
	var target := current_bet
	if not _opponent_can_bet(player_index):
		# With only all-in opponents, no extra wager or empty side pot exists.
		target = 0
		for i in range(players.size()):
			if i != player_index and players[i].status == TableState.STATUS_ALL_IN:
				target = maxi(target, int(players[i].current_bet))
	return max(0, target - players[player_index].current_bet)

func total_pot() -> int:
	var total := 0
	for player in players:
		total += int(player.total_bet)
	return total

func active_player_count() -> int:
	var count := 0
	for player in players:
		if player.status != TableState.STATUS_FOLDED and player.status != TableState.STATUS_OUT:
			count += 1
	return count

func is_human_turn() -> bool:
	return current_player_index >= 0 and players[current_player_index].is_human and stage != TableState.STAGE_HAND_OVER

func is_ai_turn() -> bool:
	return current_player_index >= 0 and not players[current_player_index].is_human and stage != TableState.STAGE_HAND_OVER

func describe_stage() -> String:
	match stage:
		TableState.STAGE_PREFLOP:
			return "翻前"
		TableState.STAGE_FLOP:
			return "翻牌"
		TableState.STAGE_TURN:
			return "转牌"
		TableState.STAGE_RIVER:
			return "河牌"
		TableState.STAGE_SHOWDOWN:
			return "摊牌"
		TableState.STAGE_HAND_OVER:
			return "结算"
	return stage

func best_hand_for(player_index: int) -> Dictionary:
	return HandEvaluator.evaluate(players[player_index].hole_cards + community_cards)

func recent_events(limit: int = 8) -> Array:
	var start: int = maxi(0, event_log.size() - limit)
	return event_log.slice(start, event_log.size())

func _make_player(id: int, name: String, is_human: bool, player_difficulty: String, personality: Dictionary) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"is_human": is_human,
		"stack": initial_stack,
		"hole_cards": [],
		"current_bet": 0,
			"total_bet": 0,
			"status": TableState.STATUS_ACTIVE,
			"has_acted": false,
			"last_action_bet": 0,
			"difficulty": player_difficulty,
		"personality": personality,
		"last_action": "",
		"last_action_note": "",
		"hand_result": {}
	}

func _players_with_chips() -> Array:
	var result := []
	for i in range(players.size()):
		if players[i].stack > 0:
			result.append(i)
	return result

func _next_index_with_chips(start: int) -> int:
	for i in range(players.size()):
		var idx := (start + i) % players.size()
		if players[idx].stack > 0:
			return idx
	return 0

func _select_positions() -> void:
	var live := _players_with_chips()
	if hand_number == 0:
		button_index = _next_index_with_chips(button_index)
		small_blind_player_index = button_index if live.size() == 2 else _next_index_with_chips(button_index + 1)
		big_blind_player_index = _next_index_with_chips(small_blind_player_index + 1)
		return
	# The big blind always moves to the next surviving seat. Use the previous
	# hand's occupied orbit for the dead button/small blind after elimination.
	var next_big := _next_index_with_chips(big_blind_player_index + 1)
	if live.size() == 2:
		button_index = _next_index_with_chips(next_big + 1)
		small_blind_player_index = button_index
	else:
		var previous_seats := []
		for i in range(players.size()):
			if not players[i].hole_cards.is_empty():
				previous_seats.append(i)
		var big_position := previous_seats.find(next_big)
		var small_seat: int = previous_seats[(big_position - 1 + previous_seats.size()) % previous_seats.size()]
		button_index = previous_seats[(big_position - 2 + previous_seats.size()) % previous_seats.size()]
		small_blind_player_index = small_seat if players[small_seat].stack > 0 else -1
	big_blind_player_index = next_big

func _post_blinds() -> void:
	if small_blind_player_index >= 0:
		_post_blind(small_blind_player_index, small_blind)
	_post_blind(big_blind_player_index, big_blind)
	# A short blind changes its contribution, never the full opening wager.
	current_bet = big_blind

func _post_blind(player_index: int, amount: int) -> void:
	var player: Dictionary = players[player_index]
	var paid: int = min(amount, player.stack)
	player.stack -= paid
	player.current_bet += paid
	player.total_bet += paid
	if player.stack == 0:
		player.status = TableState.STATUS_ALL_IN
	player.last_action = "Blind %d" % paid
	player.last_action_note = ""
	_record_event("blind", "%s 支付盲注 %d。" % [player.name, paid])

func _first_preflop_actor() -> int:
	return _next_active_actor(big_blind_player_index + 1)

func _first_postflop_actor() -> int:
	return _next_active_actor(button_index + 1)

func _pay_to_current_bet(player_index: int) -> void:
	var player: Dictionary = players[player_index]
	var paid: int = min(get_to_call(player_index), player.stack)
	player.stack -= paid
	player.current_bet += paid
	player.total_bet += paid
	if player.stack == 0:
		player.status = TableState.STATUS_ALL_IN

func _raise_to(player_index: int, target: int) -> void:
	var player: Dictionary = players[player_index]
	var previous_bet := current_bet
	var paid: int = target - player.current_bet
	player.stack -= paid
	player.current_bet += paid
	player.total_bet += paid
	if player.stack == 0:
		player.status = TableState.STATUS_ALL_IN
	current_bet = target
	min_raise = max(min_raise, current_bet - previous_bet)
	_mark_others_unacted(player_index)
	player.has_acted = true

func _all_in(player_index: int) -> void:
	var player: Dictionary = players[player_index]
	var target: int = player.current_bet + player.stack
	player.total_bet += player.stack
	player.current_bet = target
	player.stack = 0
	player.status = TableState.STATUS_ALL_IN
	if target > current_bet:
		var raise_size := target - current_bet
		if raise_size >= min_raise:
			min_raise = raise_size
			_mark_others_unacted(player_index)
		current_bet = target
	player.has_acted = true

func _mark_others_unacted(raiser_index: int) -> void:
	for i in range(players.size()):
		if i != raiser_index and players[i].status == TableState.STATUS_ACTIVE:
			players[i].has_acted = false

func _after_state_change() -> void:
	if active_player_count() == 1:
		_award_uncontested()
		return
	if _all_remaining_all_in():
		_deal_to_river()
		_showdown()
		return
	if _betting_round_complete():
		_advance_stage()
		return
	current_player_index = _next_active_actor(current_player_index + 1)

func _next_active_actor(start: int) -> int:
	for i in range(players.size()):
		var idx := (start + i) % players.size()
		if players[idx].status == TableState.STATUS_ACTIVE:
			return idx
	return -1

func _betting_round_complete() -> bool:
	for player in players:
		if player.status == TableState.STATUS_ACTIVE:
			if not player.has_acted:
				return false
			if player.current_bet != current_bet:
				return false
	return true

func _all_remaining_all_in() -> bool:
	var active_with_stack := 0
	var active_player_index := -1
	var remaining := 0
	for i in range(players.size()):
		var player: Dictionary = players[i]
		if player.status != TableState.STATUS_FOLDED and player.status != TableState.STATUS_OUT:
			remaining += 1
			if player.status == TableState.STATUS_ACTIVE and player.stack > 0:
				active_with_stack += 1
				active_player_index = i
	if remaining <= 1 or active_with_stack > 1:
		return false
	return active_player_index == -1 or get_to_call(active_player_index) == 0

func _advance_stage() -> void:
	match stage:
		TableState.STAGE_PREFLOP:
			stage = TableState.STAGE_FLOP
			community_cards.append_array(deck.draw(3))
		TableState.STAGE_FLOP:
			stage = TableState.STAGE_TURN
			community_cards.append_array(deck.draw(1))
		TableState.STAGE_TURN:
			stage = TableState.STAGE_RIVER
			community_cards.append_array(deck.draw(1))
		TableState.STAGE_RIVER:
			_showdown()
			return
	_reset_street_bets()
	current_player_index = _first_postflop_actor()
	last_message = "已发%s。" % describe_stage()
	_record_event("street", "%s 公共牌现在有 %d 张。" % [last_message, community_cards.size()])
	_append_frame("street", last_message, {})
	if current_player_index == -1:
		_showdown()

func _reset_street_bets() -> void:
	current_bet = 0
	min_raise = big_blind
	for player in players:
		player.current_bet = 0
		player.has_acted = false
		player.last_action_bet = 0

func _deal_to_river() -> void:
	while community_cards.size() < 5:
		if community_cards.size() == 0:
			community_cards.append_array(deck.draw(3))
		else:
			community_cards.append_array(deck.draw(1))
		_record_event("street", "全下后自动发牌，公共牌现在有 %d 张。" % community_cards.size())
		stage = TableState.STAGE_FLOP if community_cards.size() == 3 else (TableState.STAGE_TURN if community_cards.size() == 4 else TableState.STAGE_RIVER)
		current_player_index = -1
		_append_frame("street", "全下后发%s" % describe_stage(), {})

func _award_uncontested() -> void:
	var winner_index := -1
	for i in range(players.size()):
		if players[i].status != TableState.STATUS_FOLDED and players[i].status != TableState.STATUS_OUT:
			winner_index = i
	if winner_index >= 0:
		_refund_uncalled_bet()
		var pot := total_pot()
		side_pots = [{"amount": pot, "eligible": [winner_index], "winner_indices": [winner_index], "payouts": [{"player_index": winner_index, "amount": pot}]}]
		players[winner_index].stack += pot
		winners = [{"player_index": winner_index, "amount": pot, "rank_name": "无人跟注"}]
		last_message = "%s 无人跟注，赢得 %d。" % [players[winner_index].name, pot]
		_record_event("settlement", last_message)
	stage = TableState.STAGE_HAND_OVER
	current_player_index = -1
	_finish_hand()

func _showdown() -> void:
	stage = TableState.STAGE_SHOWDOWN
	_refund_uncalled_bet()
	for i in range(players.size()):
		if players[i].status != TableState.STATUS_FOLDED and players[i].status != TableState.STATUS_OUT:
			players[i].hand_result = best_hand_for(i)
	_append_frame("showdown", "摊牌比较", {})
	_resolve_side_pots()
	stage = TableState.STAGE_HAND_OVER
	current_player_index = -1
	_finish_hand()

func _refund_uncalled_bet() -> void:
	var highest_bet := 0
	var second_highest_bet := 0
	var highest_player_index := -1
	var highest_count := 0
	for i in range(players.size()):
		var contribution: int = players[i].total_bet
		if contribution > highest_bet:
			second_highest_bet = highest_bet
			highest_bet = contribution
			highest_player_index = i
			highest_count = 1
		elif contribution == highest_bet:
			highest_count += 1
		elif contribution > second_highest_bet:
			second_highest_bet = contribution
	if highest_count != 1 or highest_bet <= second_highest_bet:
		return
	var refund := highest_bet - second_highest_bet
	var player: Dictionary = players[highest_player_index]
	player.total_bet -= refund
	player.current_bet = max(0, int(player.current_bet) - refund)
	player.stack += refund
	_refunds.append({"player_index": highest_player_index, "amount": refund})
	if player.status == TableState.STATUS_ALL_IN:
		player.status = TableState.STATUS_ACTIVE
	_record_event("settlement", "%s 收回未被跟注的 %d。" % [player.name, refund])
	_append_frame("refund", "返还 %s 未被跟注的 %d" % [player.name, refund], {})

func _resolve_side_pots() -> void:
	side_pots = _build_side_pots()
	winners = []
	for pot in side_pots:
		var best_indices := []
		var best_result := {}
		for idx in pot.eligible:
			var result: Dictionary = players[idx].hand_result
			if best_indices.is_empty() or HandEvaluator.compare_results(result, best_result) > 0:
				best_indices = [idx]
				best_result = result
			elif HandEvaluator.compare_results(result, best_result) == 0:
				best_indices.append(idx)
		if best_indices.is_empty():
			continue
		# The odd chip belongs to the first winning seat after the button.
		best_indices.sort_custom(func(a, b): return (a - button_index - 1 + players.size()) % players.size() < (b - button_index - 1 + players.size()) % players.size())
		pot.winner_indices = best_indices.duplicate()
		pot.payouts = []
		var share: int = int(pot.amount / best_indices.size())
		var remainder: int = int(pot.amount) % best_indices.size()
		for i in range(best_indices.size()):
			var idx: int = best_indices[i]
			var payout := share + (1 if i < remainder else 0)
			players[idx].stack += payout
			pot.payouts.append({"player_index": idx, "amount": payout})
			winners.append({"player_index": idx, "amount": payout, "rank_name": best_result.rank_name})
	if winners.size() == 1:
		last_message = "%s 用%s赢得 %d。" % [players[winners[0].player_index].name, winners[0].rank_name, winners[0].amount]
	else:
		last_message = "摊牌结算完成。"
	_record_event("showdown", last_message)
	for i in range(players.size()):
		if players[i].hand_result is Dictionary and not players[i].hand_result.is_empty():
			_record_event("showdown", "%s 摊牌：%s。" % [players[i].name, players[i].hand_result.rank_name])

func _build_side_pots() -> Array:
	var levels := []
	for player in players:
		if player.total_bet > 0 and not levels.has(player.total_bet):
			levels.append(player.total_bet)
	levels.sort()
	var pots := []
	var previous := 0
	for level in levels:
		var amount := 0
		var eligible := []
		for i in range(players.size()):
			var contribution: int = players[i].total_bet
			if contribution >= level:
				amount += level - previous
				if players[i].status != TableState.STATUS_FOLDED and players[i].status != TableState.STATUS_OUT:
					eligible.append(i)
		if amount > 0:
			pots.append({"amount": amount, "eligible": eligible})
		previous = level
	return pots

func _record_action_event(player_index: int, action_type: String, amount: int, action_note: String) -> void:
	var player: Dictionary = players[player_index]
	var text := "%s %s" % [player.name, _action_label(action_type, amount, player)]
	if not action_note.is_empty():
		text += "（%s）" % action_note
	text += "。"
	_record_event("action", text)

func _action_label(action_type: String, amount: int, player: Dictionary) -> String:
	match action_type:
		TableState.ACTION_FOLD:
			return "弃牌"
		TableState.ACTION_CHECK:
			return "让牌"
		TableState.ACTION_CALL:
			return "跟注到 %d" % player.current_bet
		TableState.ACTION_RAISE:
			return "加注到 %d" % amount
		TableState.ACTION_ALL_IN:
			return "全下到 %d" % player.current_bet
	return action_type

func _record_event(event_type: String, text: String) -> void:
	if event_log.size() > 0 and event_log[event_log.size() - 1].text == text:
		return
	event_log.append({"type": event_type, "text": text, "hand": hand_number})
	if event_log.size() > 40:
		event_log.pop_front()

func _finish_hand() -> void:
	hands_completed += 1
	last_hand_human_delta = players[0].stack - _human_stack_at_hand_start
	last_hand_human_won = last_hand_human_delta > 0
	if last_hand_human_delta > max_single_hand_win:
		max_single_hand_win = last_hand_human_delta
	_hand_peak_stack = maxi(_hand_peak_stack, int(players[0].stack))
	if players[0].stack <= 0 or _players_with_chips().size() < 2:
		_finish_match()
	if not _hand_id.is_empty() and _hand_starting_stacks.size() == players.size():
		_append_frame("settlement", last_message, {})
		_completed_record = _build_completed_record()

func mark_assistance_viewed() -> void:
	if stage != TableState.STAGE_HAND_OVER:
		_assistance_viewed = true

func completed_hand_record() -> Dictionary:
	return _completed_record.duplicate(true)

func _build_completed_record() -> Dictionary:
	var net := {}
	for i in range(players.size()):
		net[str(i)] = int(players[i].stack) - int(_hand_starting_stacks[i])
	var split := false
	var exclusive := false
	for pot in side_pots:
		var indices: Array = pot.get("winner_indices", [])
		if indices.has(0):
			split = split or indices.size() > 1
			exclusive = exclusive or indices.size() == 1
	var showdown: bool = not players[0].hand_result.is_empty()
	var rank_value := int(players[0].hand_result.get("rank_value", -1))
	return {
		"schema_version": 1, "id": _hand_id, "match_id": match_id,
		"hand_number": hand_number, "created_at": _hand_created_at,
		"config": match_config.duplicate(true), "assistance_viewed": _assistance_viewed,
		"frames": _hand_frames.duplicate(true), "starting_stacks": _hand_starting_stacks.duplicate(),
		"net_changes": net, "refunds": _refunds.duplicate(true), "pots": side_pots.duplicate(true),
		"winners": winners.duplicate(true), "split": split, "exclusive_win": exclusive,
		"showdown_win": showdown and (exclusive or split),
		"uncontested_win": not showdown and exclusive,
		"rank_value": rank_value, "rank_name": players[0].hand_result.get("rank_name", ""),
		"net_change": net.get("0", 0), "peak_stack": _hand_peak_stack,
		"match_over": match_over, "summary": match_summary.duplicate(true)
	}

func _append_frame(frame_type: String, label: String, action: Dictionary) -> void:
	if not players.is_empty():
		_hand_peak_stack = maxi(_hand_peak_stack, int(players[0].stack))
	var snapshots := []
	for p in players:
		snapshots.append({
			"id": p.id, "name": p.name, "stack": p.stack,
			"hole_cards": CardUtil.clone_cards(p.hole_cards), "current_bet": p.current_bet,
			"total_bet": p.total_bet, "status": p.status, "hand_result": p.hand_result.duplicate(true)
		})
	_hand_frames.append({
		"type": frame_type, "label": label, "action": action.duplicate(true), "players": snapshots,
		"community_cards": CardUtil.clone_cards(community_cards), "stage": stage,
		"button_index": button_index, "small_blind_player_index": small_blind_player_index,
		"big_blind_player_index": big_blind_player_index, "current_player_index": current_player_index,
		"current_bet": current_bet, "min_raise": min_raise,
		"pot": 0 if stage == TableState.STAGE_HAND_OVER else total_pot(),
		"winners": winners.duplicate(true), "side_pots": side_pots.duplicate(true)
	})

func _new_id(prefix: String) -> String:
	return "%s-%s" % [prefix, Crypto.new().generate_random_bytes(16).hex_encode()]

func _finish_match() -> void:
	match_over = true
	stage = TableState.STAGE_HAND_OVER
	current_player_index = -1
	var chip_players := _players_with_chips()
	if players.size() > 0 and players[0].stack <= 0:
		match_result = "你已出局"
	elif chip_players.size() == 1 and chip_players[0] == 0:
		match_result = "你赢得牌局"
	elif chip_players.size() == 1:
		match_result = "%s 赢得牌局" % players[chip_players[0]].name
	else:
		match_result = "牌局结束"
	match_summary = {
		"hands": hands_completed,
		"final_stack": players[0].stack if players.size() > 0 else 0,
		"net_profit": (players[0].stack - initial_stack) if players.size() > 0 else 0,
		"max_single_hand_win": max_single_hand_win
	}
	last_message = "%s。总手数 %d，最终筹码 %d。" % [match_result, match_summary.hands, match_summary.final_stack]
	_record_event("match", last_message)
