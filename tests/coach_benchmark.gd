extends SceneTree
## Diagnostic finite-search benchmark. This is NOT a strength measurement: the
## sample is deliberately tiny and the only claims are timing/sample-count
## descriptives plus a determinism sanity check. It covers 2 and 6 seats at
## 10 BB and 100 BB effective depths, with a duplicated deal and seat rotation.

var failures := 0

const HELL_WORLDS := 16
const HELL_DEPTH := 8
const HELL_TIME_MS := 600
const HARD_WORLDS := 60

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("Coach finite-search benchmark (diagnostic only; no strength claims)")
	print("Sample is intentionally small: %d configs x up to 3 hero rotations x 2 duplicate deals." % 4)
	var configs := [
		{"seats": 2, "depth_bb": 10},
		{"seats": 2, "depth_bb": 100},
		{"seats": 6, "depth_bb": 10},
		{"seats": 6, "depth_bb": 100}
	]
	var all_hell_times := []
	var all_hard_times := []
	var all_worlds := []
	for config in configs:
		var seats: int = int(config.seats)
		var big_blind := 20
		var stack: int = big_blind * int(config.depth_bb)
		var rotations: int = mini(seats, 3)
		var hell_times := []
		var hard_times := []
		var hell_worlds := []
		var hell_depths := []
		var hell_actions := {}
		var hard_actions := {}
		var duplicate_match := true
		for rotation in range(rotations):
			var game_a := _table(seats, stack, big_blind, 1000 + rotation)
			var game_b := _table(seats, stack, big_blind, 1000 + rotation)
			if not _same_visible(game_a, game_b):
				duplicate_match = false
			var hero := rotation
			game_a.current_player_index = hero
			game_b.current_player_index = hero
			var options := {"seed": 555 + rotation, "max_worlds": HELL_WORLDS, "max_depth": HELL_DEPTH, "time_budget_ms": HELL_TIME_MS}
			var hell_start := Time.get_ticks_msec()
			var hell := FiniteSearch.evaluate(game_a, hero, options)
			hell_times.append(Time.get_ticks_msec() - hell_start)
			var hell_repeat := FiniteSearch.evaluate(game_b, hero, options)
			hell_worlds.append(int(hell.get("world_count", 0)))
			hell_depths.append(int(hell.get("depth_reached", 0)))
			_increment(hell_actions, _best_action(hell))
			_assert(bool(hell.get("available", false)), "hell search is available for %d seats / %d BB" % [seats, int(config.depth_bb)])
			_assert(int(hell.get("world_count", 0)) >= 2, "hell search uses paired worlds")
			if _best_action(hell) != _best_action(hell_repeat):
				duplicate_match = false
			for candidate in hell.get("candidates", []):
				_assert(not is_nan(float(candidate.get("ev", 0.0))) and not is_inf(float(candidate.get("ev", 0.0))), "finite-search EV is finite")

			var hard_start := Time.get_ticks_msec()
			var hard := ActionEV.evaluate(game_a, hero, AiDecision.profile_for_difficulty("hard"), {"rng": _seeded(555 + rotation), "world_count": HARD_WORLDS})
			hard_times.append(Time.get_ticks_msec() - hard_start)
			_increment(hard_actions, _best_action(hard))
		all_hell_times.append_array(hell_times)
		all_hard_times.append_array(hard_times)
		all_worlds.append_array(hell_worlds)
		print("--- %d seats / %d BB (stack %d) ---" % [seats, int(config.depth_bb), stack])
		print("  hell : p50 %d ms, max %d ms, worlds %s, depth %s, best actions %s" % [
			_percentile(hell_times, 50), _max_value(hell_times), str(hell_worlds), str(hell_depths), str(hell_actions)
		])
		print("  hard : p50 %d ms, max %d ms, world budget %d, best actions %s" % [
			_percentile(hard_times, 50), _max_value(hard_times), HARD_WORLDS, str(hard_actions)
		])
		print("  duplicate deal + seat rotation determinism: %s" % ("matched" if duplicate_match else "MISMATCH"))
	print("=== aggregate ===")
	print("  hell evals %d: p50 %d ms, max %d ms, worlds p50 %d" % [
		all_hell_times.size(), _percentile(all_hell_times, 50), _max_value(all_hell_times), _percentile(all_worlds, 50)
	])
	print("  hard evals %d: p50 %d ms, max %d ms" % [
		all_hard_times.size(), _percentile(all_hard_times, 50), _max_value(all_hard_times)
	])
	_paired_hand_pilot()
	if failures == 0:
		print("Coach benchmark sanity checks passed.")
	else:
		push_error("%d coach benchmark checks failed." % failures)
	quit(failures)

func _paired_hand_pilot() -> void:
	var started := Time.get_ticks_msec()
	var hands := 0
	for seats in [2, 6]:
		for depth in [10, 100]:
			var total_bb := 0.0
			var first_deal := ""
			for hell_seat in range(seats):
				var game := PokerRound.new()
				game.capture_decision_context = false
				game.record_frames = false
				game.record_events = false
				game.shuffle_rng.seed = 91017 + seats + depth
				var bb := 100 if depth == 10 else 10
				game.start_new_match(seats - 1, "hard", {"initial_stack": 1000, "small_blind": bb / 2, "big_blind": bb})
				var cards := []
				var rngs := []
				for seat in range(seats):
					cards.append(game.players[seat].hole_cards)
					game.players[seat].difficulty = "hell" if seat == hell_seat else "hard"
					game.players[seat].personality = {}
					rngs.append(_seeded(1709 + seat))
				if first_deal.is_empty(): first_deal = JSON.stringify(cards)
				_assert(first_deal == JSON.stringify(cards), "rotated opponents receive identical deals")
				var steps := 0
				while game.stage != TableState.STAGE_HAND_OVER and steps < 160:
					var actor := game.current_player_index
					var snapshot := AiTurnWorker.make_snapshot(game, actor)
					var action := AiDecision.decide(snapshot, actor, rngs[actor])
					var accepted := game.apply_action(action.action_type, int(action.amount))
					_assert(accepted, "paired pilot action passes the rules engine")
					if not accepted: break
					steps += 1
				_assert(game.stage == TableState.STAGE_HAND_OVER, "paired pilot completes full hand")
				var chips := 0
				for player in game.players: chips += int(player.stack)
				_assert(chips == seats * 1000, "paired pilot conserves chips")
				total_bb += float(game.players[hell_seat].stack - 1000) / bb
				hands += 1
			print("Full-hand pilot: %d seats / %d BB, %d rotated hands, hell net %+.2f BB (tiny sample; no strength conclusion)" % [seats, depth, seats, total_bb])
	print("Full-hand pilot completed: %d hands, %d ms" % [hands, Time.get_ticks_msec() - started])

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func c(rank: int, suit: String) -> Dictionary:
	return CardUtil.make_card(rank, suit)

func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

## Deterministic table: all seats active on a fresh flop with the requested
## stack, big blind and deal seed.
func _table(seats: int, stack: int, big_blind: int, seed_value: int) -> PokerRound:
	var game := PokerRound.new()
	game.shuffle_rng.seed = seed_value
	game.start_new_match(seats - 1, "hell")
	game.small_blind = big_blind / 2
	game.big_blind = big_blind
	game.min_raise = big_blind
	for player in game.players:
		player.stack = stack
		player.current_bet = 0
		player.total_bet = 0
		player.has_acted = false
		player.last_action_bet = 0
		player.last_action = ""
		player.status = TableState.STATUS_ACTIVE
	game.community_cards = game.deck.draw(3)
	game.stage = TableState.STAGE_FLOP
	game.current_bet = 0
	game.current_player_index = 0
	game.public_action_history = []
	return game

func _same_visible(a: PokerRound, b: PokerRound) -> bool:
	if a.players.size() != b.players.size():
		return false
	if a.community_cards != b.community_cards:
		return false
	for i in range(a.players.size()):
		if a.players[i].hole_cards != b.players[i].hole_cards:
			return false
		if int(a.players[i].stack) != int(b.players[i].stack):
			return false
	return true

func _best_action(result: Dictionary) -> String:
	var best: Dictionary = result.get("best", {})
	if best.is_empty():
		return "none"
	return str(best.get("action_type", "none"))

func _increment(counter: Dictionary, key: String) -> void:
	counter[key] = int(counter.get(key, 0)) + 1

func _percentile(values: Array, _percent: int) -> int:
	if values.is_empty():
		return 0
	var sorted := values.duplicate()
	sorted.sort()
	return int(sorted[sorted.size() / 2])

func _max_value(values: Array) -> int:
	var result := 0
	for value in values:
		result = maxi(result, int(value))
	return result
