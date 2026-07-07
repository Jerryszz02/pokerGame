class_name AiDecision
extends RefCounted

static func decide(game: PokerRound, player_index: int) -> Dictionary:
	var player: Dictionary = game.players[player_index]
	var legal := game.get_legal_actions(player_index)
	var actions: Array = legal.actions
	if actions.is_empty():
		return _decision(TableState.ACTION_CHECK, 0, "无可用行动")
	var profile := _profile_for(player)
	var equity := _estimate_equity(game, player_index, profile)
	var to_call := game.get_to_call(player_index)
	var pot_after_call: int = max(1, game.total_pot() + to_call)
	var pot_odds := float(to_call) / float(pot_after_call)
	var can_raise := actions.has(TableState.ACTION_RAISE)
	var can_check := actions.has(TableState.ACTION_CHECK)

	if to_call > 0 and equity + profile.call_tolerance < pot_odds:
		if randf() < profile.bluff_rate and can_raise:
			return _raise_action(game, player_index, legal, profile, 0.65, "诈唬加注")
		return _decision(TableState.ACTION_FOLD, 0, "谨慎弃牌")

	if can_raise and _should_raise(equity, profile, to_call):
		var pot_fraction := 0.5
		var label := "价值加注"
		if equity > 0.72:
			pot_fraction = 0.8
		elif randf() < profile.bluff_rate:
			pot_fraction = 0.65
			label = "诈唬加注"
		return _raise_action(game, player_index, legal, profile, pot_fraction, label)

	if to_call > 0 and actions.has(TableState.ACTION_CALL):
		return _decision(TableState.ACTION_CALL, 0, "赔率跟注")
	if can_check:
		return _decision(TableState.ACTION_CHECK, 0, "控池让牌")
	return _decision(TableState.ACTION_ALL_IN, 0, "短筹码全下")

static func profile_for_difficulty(difficulty: String) -> Dictionary:
	return _profile_for({"difficulty": difficulty, "personality": {}})

static func _profile_for(player: Dictionary) -> Dictionary:
	if player.personality is Dictionary and not player.personality.is_empty():
		return player.personality
	match player.difficulty:
		"simple":
			return {
				"name": "Simple",
				"aggression": 0.35,
				"looseness": 0.28,
				"bluff_rate": 0.04,
				"call_tolerance": -0.02,
				"simulation_count": 0
			}
		"medium":
			return {
				"name": "Medium",
				"aggression": 0.5,
				"looseness": 0.35,
				"bluff_rate": 0.07,
				"call_tolerance": 0.04,
				"simulation_count": 0
			}
	return PersonalityProfiles.default_profile()

static func _estimate_equity(game: PokerRound, player_index: int, profile: Dictionary) -> float:
	var player: Dictionary = game.players[player_index]
	if game.stage == TableState.STAGE_PREFLOP:
		var preflop_score := StartingHandTable.score(player.hole_cards)
		var position_bonus := _position_bonus(game, player_index)
		var pressure_penalty: float = minf(0.18, float(game.get_to_call(player_index)) / 180.0)
		return clampf(float(preflop_score) / 100.0 + position_bonus - pressure_penalty, 0.02, 0.98)
	if player.difficulty == "hard":
		var opponents: int = maxi(1, game.active_player_count() - 1)
		var result := MonteCarlo.estimate_equity(player.hole_cards, game.community_cards, opponents, int(profile.simulation_count))
		return float(result.equity)
	return _rule_equity(game, player_index)

static func _rule_equity(game: PokerRound, player_index: int) -> float:
	var result := game.best_hand_for(player_index)
	var base := 0.18 + float(result.rank_value) * 0.09
	var to_call_pressure: float = minf(0.12, float(game.get_to_call(player_index)) / 220.0)
	return clampf(base - to_call_pressure, 0.05, 0.9)

static func _position_bonus(game: PokerRound, player_index: int) -> float:
	var distance := (player_index - game.button_index + game.players.size()) % game.players.size()
	if distance == 0:
		return 0.06
	if distance == game.players.size() - 1:
		return -0.04
	return 0.0

static func _should_raise(equity: float, profile: Dictionary, to_call: int) -> bool:
	var value_threshold: float = 0.58 - profile.aggression * 0.1
	if equity >= value_threshold:
		return randf() < profile.aggression
	if to_call == 0 and equity > 0.42 and randf() < profile.bluff_rate:
		return true
	return false

static func _raise_action(game: PokerRound, player_index: int, legal: Dictionary, profile: Dictionary, pot_fraction: float, label: String) -> Dictionary:
	var player: Dictionary = game.players[player_index]
	var desired: int = game.current_bet + int(max(game.big_blind, game.total_pot() * pot_fraction))
	var target: int = clampi(desired, legal.min_raise_to, legal.max_raise_to)
	if target >= player.current_bet + player.stack:
		return _decision(TableState.ACTION_ALL_IN, 0, "强牌压迫")
	return _decision(TableState.ACTION_RAISE, target, label)

static func _decision(action_type: String, amount: int, label: String) -> Dictionary:
	return {"action_type": action_type, "amount": amount, "decision_label": label}
