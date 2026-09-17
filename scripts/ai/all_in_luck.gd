class_name AllInLuck
extends RefCounted
## Conditional payout variability after all betting has irrevocably finished.
## Decision coaching never uses these showdown holdings. Folded cards are not
## blockers. PokerRound owns rankings, pot eligibility, refunds and odd chips.

static func calculate(record: Dictionary, options: Dictionary = {}) -> Dictionary:
	var cancellation: Variant = options.get("cancellation")
	if FiniteSearch._is_cancelled(cancellation): return _unavailable("cancelled")
	var lock := _find_lock(record)
	if lock.is_empty(): return _unavailable("no_complete_all_in_lock")
	var frames: Array = record.frames
	var showdown: Dictionary = {}
	for frame in frames:
		if frame.get("type") == "showdown": showdown = frame
	if showdown.is_empty(): return _unavailable("missing_showdown")
	var board: Variant = CoachContext._parse_cards(lock.community_cards)
	var final_board: Variant = CoachContext._parse_cards(showdown.get("community_cards"))
	if board == null or final_board == null or final_board.size() != 5 or final_board.slice(0, board.size()) != board:
		return _unavailable("invalid_board")
	var people: Array = lock.players.duplicate(true)
	var shown: Variant = showdown.get("players")
	if not shown is Array or shown.size() != people.size(): return _unavailable("missing_holdings")
	var known: Array = board.duplicate(true)
	for i in range(people.size()):
		people[i].hole_cards = []
		if not _contender(people[i]): continue
		if not shown[i] is Dictionary or not _contender(shown[i]): return _unavailable("changed_contenders")
		var cards: Variant = CoachContext._parse_cards(shown[i].get("hole_cards"))
		if cards == null or cards.size() != 2: return _unavailable("missing_holdings")
		people[i].hole_cards = cards
		known.append_array(cards)
	if not _contender(people[0]) or not _unique(known): return _unavailable("hero_folded_or_duplicate_cards")
	if not _unique(known + final_board.slice(board.size())): return _unavailable("invalid_runout")
	if not record.get("config") is Dictionary: return _unavailable("invalid_config")
	var bb: Variant = record.config.get("big_blind")
	if not _integer(bb) or bb <= 0: return _unavailable("invalid_blind")
	var actual_game := _settle(final_board, people, int(lock.button_index))
	# Recompute the REAL result first. Missing/corrupt eligible seats, payouts,
	# winners, pot amounts or refunds cannot silently become an expected payout.
	var actual_pots := _pot_signature(record.get("pots"), people.size())
	if actual_pots.is_empty() or actual_pots != _pot_signature(actual_game.side_pots, people.size()):
		return _unavailable("inconsistent_pots")
	var refunds: Variant = record.get("refunds")
	if not refunds is Array or (not refunds.is_empty() and _payments(refunds, people.size()).is_empty()) or _payments(refunds, people.size()) != _payments(actual_game._refunds, people.size()):
		return _unavailable("inconsistent_refunds")
	var actual := _hero_payout(actual_game.side_pots)
	var unseen := CardUtil.full_deck()
	for card in known:
		for i in range(unseen.size() - 1, -1, -1):
			if CardUtil.card_key(unseen[i]) == CardUtil.card_key(card): unseen.remove_at(i)
	var needed: int = 5 - board.size()
	var exhaustive := needed == 1
	var requested := unseen.size() if exhaustive else clampi(int(options.get("luck_worlds", 128)), 2, 512)
	var deadline := Time.get_ticks_msec() + clampi(int(options.get("time_budget_ms", 2000)), 1, 10000)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", 9173))
	var n := 0
	var mean := 0.0
	var m2 := 0.0
	for sample in range(requested):
		if FiniteSearch._is_cancelled(cancellation): return _unavailable("cancelled")
		if Time.get_ticks_msec() > deadline: break
		var runout: Array = board + [unseen[sample]] if exhaustive else _draw_board(board, unseen, rng)
		var simulation := _settle(runout, people, int(lock.button_index))
		var payout := _hero_payout(simulation.side_pots)
		n += 1
		var delta := payout - mean
		mean += delta / n
		m2 += delta * (payout - mean)
	if FiniteSearch._is_cancelled(cancellation): return _unavailable("cancelled")
	# A truncated enumeration is ordered, not a random sample; never use it.
	if n < 2 or (exhaustive and n != requested): return _unavailable("time_budget")
	var variance := maxf(0.0, m2 / (n if exhaustive else n - 1))
	# Identical sampled payouts do not establish zero true variance.
	if not exhaustive and variance == 0.0: return _unavailable("unresolved_variance")
	return {"qualifying":true, "worlds":n, "exhaustive":exhaustive, "timed_out":n < requested,
		"actual_payout":actual, "expected_payout":mean, "delta_bb":(actual - mean) / float(bb),
		"variance_bb2":variance / (float(bb) * float(bb))}

static func _find_lock(record: Dictionary) -> Dictionary:
	var frames: Variant = record.get("frames")
	if not frames is Array or frames.is_empty(): return {}
	for frame in frames:
		if not frame is Dictionary: return {}
	if frames.back().get("type") != "settlement" or frames.back().get("stage") != TableState.STAGE_HAND_OVER: return {}
	for i in range(frames.size()):
		var frame: Dictionary = frames[i]
		var board: Variant = frame.get("community_cards")
		if frame.get("type") != "action" or not board is Array or not board.size() in [0, 3, 4]: continue
		var people: Variant = frame.get("players")
		if not people is Array or people.size() < 2 or people.size() > 6: continue
		if not _integer(frame.get("current_bet")) or not _integer(frame.get("button_index")): continue
		if frame.button_index < 0 or frame.button_index >= people.size(): continue
		var live := 0
		var active := 0
		var all_in := 0
		var valid := true
		for player in people:
			if not player is Dictionary:
				valid = false
				break
			for key in ["stack", "current_bet", "total_bet"]:
				if not _integer(player.get(key)) or player[key] < 0: valid = false
			if not valid: break
			if player.current_bet > player.total_bet: valid = false
			if not str(player.get("status")) in CoachContext._STATUSES: valid = false
			if not _contender(player): continue
			live += 1
			if player.status == TableState.STATUS_ALL_IN:
				all_in += 1
				if player.stack != 0: valid = false
			else:
				active += 1
				# The one remaining stack must owe nothing; otherwise it still
				# has a call/fold decision and betting is not locked.
				if player.stack <= 0 or player.current_bet < frame.current_bet: valid = false
		if not valid or live < 2 or all_in < 1 or active > 1: continue
		var showdown_seen := false
		var automatic_street := false
		for j in range(i + 1, frames.size()):
			var kind := str(frames[j].get("type"))
			if not kind in ["street", "refund", "showdown", "settlement"]: valid = false
			if kind == "street": automatic_street = true
			if kind == "showdown": showdown_seen = true
		if valid and showdown_seen and automatic_street: return frame
	return {}

static func _settle(board: Array, people: Array, button: int) -> PokerRound:
	var game := PokerRound.new()
	game.capture_decision_context = false
	game.record_frames = false
	game.record_events = false
	game.record_public_history = false
	game.players = people.duplicate(true)
	game.community_cards = board.duplicate(true)
	game.button_index = button
	# No player action remains at a validated lock. Use the original complete
	# showdown path, including its uncalled refund and every nested pot layer.
	game._showdown()
	return game

static func _draw_board(board: Array, unseen: Array, rng: RandomNumberGenerator) -> Array:
	var pool := unseen.duplicate()
	var out := board.duplicate()
	for i in range(5 - board.size()):
		var at := rng.randi_range(i, pool.size() - 1)
		var chosen: Dictionary = pool[at]
		pool[at] = pool[i]
		pool[i] = chosen
		out.append(chosen)
	return out

static func _contender(player: Dictionary) -> bool:
	return player.get("status") in [TableState.STATUS_ACTIVE, TableState.STATUS_ALL_IN]

static func _pot_signature(value: Variant, count: int) -> Array:
	if not value is Array: return []
	var out := []
	for pot in value:
		if not pot is Dictionary or not _integer(pot.get("amount")) or pot.amount <= 0: return []
		var eligible := _seats(pot.get("eligible"), count)
		var winners := _seats(pot.get("winner_indices"), count)
		var payouts := _payments(pot.get("payouts"), count)
		if eligible.is_empty() or winners.is_empty() or payouts.is_empty(): return []
		var total := 0
		var paid_seats := []
		for payout in payouts:
			if not winners.has(payout[0]) or not eligible.has(payout[0]): return []
			total += payout[1]
			paid_seats.append(payout[0])
		if total != int(pot.amount) or paid_seats != winners: return []
		out.append([int(pot.amount), eligible, winners, payouts])
	return out

static func _seats(value: Variant, count: int) -> Array:
	if not value is Array: return []
	var out := []
	for seat in value:
		if not _integer(seat) or seat < 0 or seat >= count or out.has(int(seat)): return []
		out.append(int(seat))
	out.sort()
	return out

static func _payments(value: Variant, count: int) -> Array:
	if not value is Array: return []
	var out := []
	var seen := {}
	for payment in value:
		if not payment is Dictionary or not _integer(payment.get("player_index")) or not _integer(payment.get("amount")): return []
		var seat := int(payment.player_index)
		if seat < 0 or seat >= count or payment.amount < 0 or seen.has(seat): return []
		seen[seat] = true
		out.append([seat, int(payment.amount)])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out

static func _hero_payout(pots: Array) -> float:
	var total := 0.0
	for pot in pots:
		for payout in pot.payouts:
			if int(payout.player_index) == 0: total += float(payout.amount)
	return total

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func _unique(cards: Array) -> bool:
	var seen := {}
	for card in cards:
		var key := CardUtil.card_key(card)
		if seen.has(key): return false
		seen[key] = true
	return true

static func _unavailable(reason: String) -> Dictionary:
	return {"qualifying":false, "reason":reason}
