extends SceneTree

const HANDS := 10000
const SEED := 20260906
var failures := 0
var rng := RandomNumberGenerator.new()
var action_count := 0

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, context: String) -> void:
	if not ok:
		failures += 1
		push_error(context)

func _run() -> void:
	rng.seed = SEED
	var started := Time.get_ticks_msec()
	for hand in range(HANDS):
		var game := PokerRound.new()
		game.shuffle_rng.seed = SEED + hand
		game.start_new_match(1 + hand % 5, "simple")
		# Exercise uneven, tiny and eliminated stacks at each blind position.
		for player in game.players:
			player.stack = rng.randi_range(1, 2000)
			if rng.randf() < 0.3:
				player.stack = rng.randi_range(1, 25)
		game.hand_number = 0
		game.button_index = hand % game.players.size()
		var bank := 0
		for player in game.players:
			bank += int(player.stack)
		game.start_next_hand()
		var steps := 0
		while game.stage != TableState.STAGE_HAND_OVER and steps < 300:
			_validate(game, bank, hand, steps)
			var legal := game.get_legal_actions(game.current_player_index)
			_check(not legal.actions.is_empty(), "seed %d hand %d has no legal action" % [SEED, hand])
			if legal.actions.is_empty():
				break
			var action: String = legal.actions[rng.randi_range(0, legal.actions.size() - 1)]
			# Half of hands favor calls/checks to exercise every street.
			if hand % 2 == 0 and rng.randf() < 0.8:
				action = "check" if legal.actions.has("check") else "call"
			var amount := rng.randi_range(legal.min_raise_to, legal.max_raise_to) if action == "raise" else 0
			_check(game.apply_action(action, amount), "seed %d hand %d step %d rejected advertised %s %d" % [SEED, hand, steps, action, amount])
			steps += 1
			action_count += 1
		_validate(game, bank, hand, steps)
		_check(game.stage == TableState.STAGE_HAND_OVER, "seed %d hand %d exceeded 300 actions" % [SEED, hand])
		if failures > 0:
			break
	if failures == 0:
		print("Rules soak passed: seed=%d hands=%d actions=%d elapsed_ms=%d" % [SEED, HANDS, action_count, Time.get_ticks_msec() - started])
	quit(failures)

func _validate(game: PokerRound, bank: int, hand: int, step: int) -> void:
	var context := "seed=%d hand=%d step=%d" % [SEED, hand, step]
	var money := 0
	var seen := {}
	var cards := game.community_cards.duplicate()
	cards.append_array(game.deck.cards)
	for player in game.players:
		_check(player.stack >= 0 and player.total_bet >= 0 and player.current_bet >= 0, context + " negative chips")
		money += int(player.stack)
		if game.stage != TableState.STAGE_HAND_OVER:
			money += int(player.total_bet)
		cards.append_array(player.hole_cards)
	_check(money == bank, context + " chip conservation")
	for card in cards:
		var key := CardUtil.card_key(card)
		_check(not seen.has(key), context + " duplicate card " + key)
		seen[key] = true
	_check(cards.size() == 52, context + " deck conservation")
	if game.stage != TableState.STAGE_HAND_OVER:
		_check(game.current_player_index >= 0 and game.players[game.current_player_index].status == TableState.STATUS_ACTIVE, context + " invalid actor")
