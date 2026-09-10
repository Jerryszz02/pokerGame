class_name MonteCarlo
extends RefCounted
## Bounded Monte Carlo equity for weighted opponent ranges.
##
## The original `estimate_equity` API is preserved. All randomness comes from a
## local RandomNumberGenerator (optionally seeded/injected) so a decision never
## mutates the game's dealing RNG or the global shuffle sequence. Opponent
## combinations are sampled jointly without replacement from their public
## ranges; folded opponents' actual cards are never read.

const MAX_ITERATIONS := 4000

static func estimate_equity(hole_cards: Array, board: Array, opponent_count: int, iterations: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var ranges := []
	for _index in range(maxi(0, opponent_count)):
		ranges.append(OpponentRange.new(hole_cards, board))
	var result := estimate_equity_weighted(hole_cards, board, ranges, iterations, rng)
	return {
		"win_rate": result.win_rate,
		"tie_rate": result.tie_rate,
		"equity": result.equity
	}

## Sample `count` independent worlds (opponent holdings + completed board).
## Each world is safe to reuse across candidate actions.
static func sample_worlds(hole_cards: Array, board: Array, opponent_ranges: Array, count: int, rng: RandomNumberGenerator = null) -> Array:
	var local_rng := rng if rng != null else _new_rng()
	var capped := clampi(count, 1, MAX_ITERATIONS)
	var worlds := []
	for _index in range(capped):
		var world := _sample_world(hole_cards, board, opponent_ranges, local_rng)
		if not world.is_empty():
			worlds.append(world)
	return worlds

## Equity over already-sampled worlds. Shared with ActionEV so candidate
## actions are scored on the same sampled future.
static func evaluate_worlds(hole_cards: Array, worlds: Array) -> Dictionary:
	if hole_cards.size() != 2 or worlds.is_empty():
		return {"win_rate": 0.0, "tie_rate": 0.0, "equity": 0.0, "count": 0}
	var wins := 0.0
	var ties := 0.0
	for world in worlds:
		var board: Array = world.board
		var opponents: Array = world.opponents
		var hero_result := HandEvaluator.evaluate(hole_cards + board)
		var hero_beaten := false
		var tied := 1
		for opponent_cards in opponents:
			var opponent_result := HandEvaluator.evaluate(opponent_cards + board)
			var comparison := HandEvaluator.compare_results(opponent_result, hero_result)
			if comparison > 0:
				hero_beaten = true
				break
			elif comparison == 0:
				tied += 1
		if hero_beaten:
			continue
		if tied == 1:
			wins += 1.0
		else:
			ties += 1.0 / tied
	var count := worlds.size()
	return {
		"win_rate": wins / count,
		"tie_rate": ties / count,
		"equity": (wins + ties) / count,
		"count": count
	}

## Weighted-range equity. Returns the sampled worlds for reuse (bounded by the
## caller's iteration budget).
static func estimate_equity_weighted(hole_cards: Array, board: Array, opponent_ranges: Array, iterations: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var worlds := sample_worlds(hole_cards, board, opponent_ranges, iterations, rng)
	var summary := evaluate_worlds(hole_cards, worlds)
	summary["worlds"] = worlds
	return summary

static func _sample_world(hole_cards: Array, board: Array, opponent_ranges: Array, rng: RandomNumberGenerator) -> Dictionary:
	# A failed later draw rejects the complete assignment. Retrying the whole
	# assignment preserves each player's marginal range instead of conditioning
	# later seats on whichever earlier draw happened to work.
	for _attempt in range(24):
		var used := {}
		for card in hole_cards:
			used[CardUtil.card_key(card)] = true
		for card in board:
			used[CardUtil.card_key(card)] = true
		var opponents := []
		var valid := true
		for opponent_range in opponent_ranges:
			# Each seat is sampled from its own hero+public-board-conditioned
			# distribution. Inter-player collisions reject the whole assignment.
			var combo: Array = opponent_range.sample_combo(rng)
			if combo.size() != 2:
				valid = false
				break
			if used.has(CardUtil.card_key(combo[0])) or used.has(CardUtil.card_key(combo[1])):
				valid = false
				break
			opponents.append([combo[0], combo[1]])
			used[CardUtil.card_key(combo[0])] = true
			used[CardUtil.card_key(combo[1])] = true
		if not valid:
			continue
		var full_board := CardUtil.clone_cards(board)
		if full_board.size() < 5:
			var remaining := []
			for card in CardUtil.full_deck():
				if not used.has(CardUtil.card_key(card)):
					remaining.append(card)
			_shuffle_array(remaining, rng)
			var cursor := 0
			while full_board.size() < 5 and cursor < remaining.size():
				full_board.append(remaining[cursor])
				cursor += 1
		if full_board.size() >= 5:
			return {"opponents": opponents, "board": full_board}
	return {}

static func _new_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng

static func _shuffle_array(cards: Array, rng: RandomNumberGenerator) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
