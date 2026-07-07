class_name MonteCarlo
extends RefCounted

static func estimate_equity(hole_cards: Array, board: Array, opponent_count: int, iterations: int) -> Dictionary:
	if hole_cards.size() != 2:
		return {"win_rate": 0.0, "tie_rate": 0.0, "equity": 0.0}
	var wins := 0.0
	var ties := 0.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var known := CardUtil.clone_cards(hole_cards + board)
	var base_deck := CardUtil.without_known(CardUtil.full_deck(), known)
	var capped_iterations: int = max(1, iterations)
	for _i in range(capped_iterations):
		var sim_deck := CardUtil.clone_cards(base_deck)
		_shuffle_array(sim_deck, rng)
		var cursor := 0
		var opponents := []
		for _opp in range(opponent_count):
			opponents.append([sim_deck[cursor], sim_deck[cursor + 1]])
			cursor += 2
		var sim_board := CardUtil.clone_cards(board)
		while sim_board.size() < 5:
			sim_board.append(sim_deck[cursor])
			cursor += 1
		var hero_result := HandEvaluator.evaluate(hole_cards + sim_board)
		var hero_beaten := false
		var tied := 1
		for opp_cards in opponents:
			var opp_result := HandEvaluator.evaluate(opp_cards + sim_board)
			var compare := HandEvaluator.compare_results(opp_result, hero_result)
			if compare > 0:
				hero_beaten = true
				break
			elif compare == 0:
				tied += 1
		if hero_beaten:
			continue
		if tied == 1:
			wins += 1.0
		else:
			ties += 1.0 / tied
	var win_rate := wins / capped_iterations
	var tie_rate := ties / capped_iterations
	return {"win_rate": win_rate, "tie_rate": tie_rate, "equity": win_rate + tie_rate}

static func _shuffle_array(cards: Array, rng: RandomNumberGenerator) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
