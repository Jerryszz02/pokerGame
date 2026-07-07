class_name PokerRound
extends RefCounted

var players: Array = []
var community_cards: Array = []
var deck := Deck.new()
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
var last_message := "Choose settings to start."
var difficulty := "simple"

func start_new_match(ai_count: int, selected_difficulty: String) -> void:
	difficulty = selected_difficulty
	players = []
	players.append(_make_player(0, "You", true, "human", {}))
	for i in range(ai_count):
		var personality := {}
		if selected_difficulty == "hard":
			personality = PersonalityProfiles.random_profile()
		players.append(_make_player(i + 1, "AI %d" % [i + 1], false, selected_difficulty, personality))
	button_index = 0
	hand_number = 0
	start_next_hand()

func start_next_hand() -> void:
	if players.is_empty():
		return
	if _players_with_chips().size() < 2:
		_reset_stacks()
	hand_number += 1
	button_index = _next_index_with_chips(button_index if hand_number == 1 else button_index + 1)
	small_blind_player_index = -1
	big_blind_player_index = -1
	deck = Deck.new()
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
		player.last_action = ""
		player.hand_result = {}
		player.status = TableState.STATUS_ACTIVE if player.stack > 0 else TableState.STATUS_OUT
	for _round in range(2):
		for offset in range(players.size()):
			var idx := (button_index + 1 + offset) % players.size()
			if players[idx].status != TableState.STATUS_OUT:
				players[idx].hole_cards.append_array(deck.draw(1))
	_post_blinds()
	current_player_index = _first_preflop_actor()
	last_message = "Hand %d started." % hand_number
	if active_player_count() == 1:
		_award_uncontested()
	elif _all_remaining_all_in():
		_deal_to_river()
		_showdown()
	elif current_player_index == -1:
		_showdown()

func apply_action(action_type: String, amount: int = 0) -> bool:
	if current_player_index < 0 or stage == TableState.STAGE_HAND_OVER:
		return false
	var player: Dictionary = players[current_player_index]
	if player.status != TableState.STATUS_ACTIVE:
		return false
	var legal := get_legal_actions(current_player_index)
	if not legal.actions.has(action_type):
		return false
	match action_type:
		TableState.ACTION_FOLD:
			player.status = TableState.STATUS_FOLDED
			player.has_acted = true
			player.last_action = "Fold"
		TableState.ACTION_CHECK:
			if get_to_call(current_player_index) != 0:
				return false
			player.has_acted = true
			player.last_action = "Check"
		TableState.ACTION_CALL:
			_pay_to_current_bet(current_player_index)
			player.has_acted = true
			player.last_action = "Call"
		TableState.ACTION_RAISE:
			var target := int(amount)
			if target < legal.min_raise_to or target > legal.max_raise_to:
				return false
			_raise_to(current_player_index, target)
			player.last_action = "Raise %d" % target
		TableState.ACTION_ALL_IN:
			_all_in(current_player_index)
			player.last_action = "All-in"
		_:
			return false
	_after_state_change()
	return true

func get_legal_actions(player_index: int) -> Dictionary:
	if player_index < 0 or player_index >= players.size():
		return {"actions": [], "min_raise_to": 0, "max_raise_to": 0}
	var player: Dictionary = players[player_index]
	if player.status != TableState.STATUS_ACTIVE:
		return {"actions": [], "min_raise_to": 0, "max_raise_to": 0}
	var to_call := get_to_call(player_index)
	var actions := [TableState.ACTION_FOLD, TableState.ACTION_ALL_IN]
	if to_call == 0:
		actions.append(TableState.ACTION_CHECK)
	else:
		actions.append(TableState.ACTION_CALL)
	var max_raise_to: int = player.current_bet + player.stack
	var min_raise_to: int = current_bet + min_raise
	if max_raise_to >= min_raise_to:
		actions.append(TableState.ACTION_RAISE)
	return {"actions": actions, "min_raise_to": min_raise_to, "max_raise_to": max_raise_to}

func get_to_call(player_index: int) -> int:
	return max(0, current_bet - players[player_index].current_bet)

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
			return "Preflop"
		TableState.STAGE_FLOP:
			return "Flop"
		TableState.STAGE_TURN:
			return "Turn"
		TableState.STAGE_RIVER:
			return "River"
		TableState.STAGE_SHOWDOWN:
			return "Showdown"
		TableState.STAGE_HAND_OVER:
			return "Hand Over"
	return stage

func best_hand_for(player_index: int) -> Dictionary:
	return HandEvaluator.evaluate(players[player_index].hole_cards + community_cards)

func _make_player(id: int, name: String, is_human: bool, player_difficulty: String, personality: Dictionary) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"is_human": is_human,
		"stack": TableState.INITIAL_STACK,
		"hole_cards": [],
		"current_bet": 0,
		"total_bet": 0,
		"status": TableState.STATUS_ACTIVE,
		"has_acted": false,
		"difficulty": player_difficulty,
		"personality": personality,
		"last_action": "",
		"hand_result": {}
	}

func _players_with_chips() -> Array:
	var result := []
	for i in range(players.size()):
		if players[i].stack > 0:
			result.append(i)
	return result

func _reset_stacks() -> void:
	for player in players:
		player.stack = TableState.INITIAL_STACK

func _next_index_with_chips(start: int) -> int:
	for i in range(players.size()):
		var idx := (start + i) % players.size()
		if players[idx].stack > 0:
			return idx
	return 0

func _post_blinds() -> void:
	small_blind_player_index = _small_blind_index()
	big_blind_player_index = _big_blind_index()
	_post_blind(small_blind_player_index, small_blind)
	_post_blind(big_blind_player_index, big_blind)
	current_bet = players[big_blind_player_index].current_bet

func _post_blind(player_index: int, amount: int) -> void:
	var player: Dictionary = players[player_index]
	var paid: int = min(amount, player.stack)
	player.stack -= paid
	player.current_bet += paid
	player.total_bet += paid
	if player.stack == 0:
		player.status = TableState.STATUS_ALL_IN
	player.last_action = "Blind %d" % paid

func _small_blind_index() -> int:
	if _players_with_chips().size() == 2:
		return button_index
	return _next_index_with_chips(button_index + 1)

func _big_blind_index() -> int:
	return _next_index_with_chips(_small_blind_index() + 1)

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
	var remaining := 0
	for player in players:
		if player.status != TableState.STATUS_FOLDED and player.status != TableState.STATUS_OUT:
			remaining += 1
			if player.status == TableState.STATUS_ACTIVE and player.stack > 0:
				active_with_stack += 1
	return remaining > 1 and active_with_stack <= 1

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
	last_message = "%s dealt." % describe_stage()
	if current_player_index == -1:
		_showdown()

func _reset_street_bets() -> void:
	current_bet = 0
	min_raise = big_blind
	for player in players:
		player.current_bet = 0
		player.has_acted = false

func _deal_to_river() -> void:
	while community_cards.size() < 5:
		if community_cards.size() == 0:
			community_cards.append_array(deck.draw(3))
		else:
			community_cards.append_array(deck.draw(1))

func _award_uncontested() -> void:
	var winner_index := -1
	for i in range(players.size()):
		if players[i].status != TableState.STATUS_FOLDED and players[i].status != TableState.STATUS_OUT:
			winner_index = i
	if winner_index >= 0:
		var pot := total_pot()
		players[winner_index].stack += pot
		winners = [{"player_index": winner_index, "amount": pot, "rank_name": "Uncontested"}]
		last_message = "%s wins %d uncontested." % [players[winner_index].name, pot]
	stage = TableState.STAGE_HAND_OVER
	current_player_index = -1

func _showdown() -> void:
	stage = TableState.STAGE_SHOWDOWN
	for i in range(players.size()):
		if players[i].status != TableState.STATUS_FOLDED and players[i].status != TableState.STATUS_OUT:
			players[i].hand_result = best_hand_for(i)
	_resolve_side_pots()
	stage = TableState.STAGE_HAND_OVER
	current_player_index = -1

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
		var share: int = int(pot.amount / best_indices.size())
		var remainder: int = int(pot.amount) % best_indices.size()
		for i in range(best_indices.size()):
			var idx: int = best_indices[i]
			var payout := share + (1 if i < remainder else 0)
			players[idx].stack += payout
			winners.append({"player_index": idx, "amount": payout, "rank_name": best_result.rank_name})
	if winners.size() == 1:
		last_message = "%s wins %d with %s." % [players[winners[0].player_index].name, winners[0].amount, winners[0].rank_name]
	else:
		last_message = "Showdown complete."

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
