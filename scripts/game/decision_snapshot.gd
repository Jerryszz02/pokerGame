class_name DecisionSnapshot
extends RefCounted
## Game-owned neutral decision snapshot for coaching, review and replay.
##
## capture() stores public table state plus the hero's own hole cards only.
## Opponent hole cards, opponent personality/notes/hand results and the real
## future deck are never stored. restore() validates a versioned dictionary
## (including the integral floats produced by a JSON round trip) and rebuilds a
## PokerRound with the same legal rights, or returns null for unsupported or
## malformed data.
##
## This is the single implementation of the neutral snapshot schema. The AI
## layer's CoachContext is a thin compatibility facade over it, and PokerRound
## preloads only this game-owned module. The game parameter of capture() is
## intentionally untyped so this module can be preloaded from poker_round.gd
## without a static cyclic class reference; restore() resolves PokerRound at
## runtime.

const VERSION := 1
const KIND := "coach_context"
const MAX_PLAYERS := 6

const _STATUSES := [TableState.STATUS_ACTIVE, TableState.STATUS_FOLDED, TableState.STATUS_ALL_IN, TableState.STATUS_OUT]
const _STAGES := [
	TableState.STAGE_PREFLOP, TableState.STAGE_FLOP, TableState.STAGE_TURN,
	TableState.STAGE_RIVER, TableState.STAGE_SHOWDOWN, TableState.STAGE_HAND_OVER
]
const _REQUIRED_INTS := [
	"hand_number", "small_blind", "big_blind", "button_index",
	"small_blind_player_index", "big_blind_player_index",
	"current_bet", "min_raise", "current_player_index"
]

static func capture(game, hero: int = 0) -> Dictionary:
	if game == null:
		return {}
	var table: Array = game.players
	if hero < 0 or hero >= table.size() or table.size() > MAX_PLAYERS:
		return {}
	var players_out := []
	for i in range(table.size()):
		var source: Dictionary = table[i]
		var entry := {
			"id": _int(source.get("id", i), i),
			"name": str(source.get("name", "")),
			"is_human": bool(source.get("is_human", false)),
			"stack": _int(source.get("stack", 0), 0),
			"current_bet": _int(source.get("current_bet", 0), 0),
			"total_bet": _int(source.get("total_bet", 0), 0),
			"status": str(source.get("status", TableState.STATUS_ACTIVE)),
			"has_acted": bool(source.get("has_acted", false)),
			"last_action_bet": _int(source.get("last_action_bet", 0), 0),
			"last_action": str(source.get("last_action", "")),
			# Only the hero's own cards are ever copied.
			"hole_cards": CardUtil.clone_cards(source.get("hole_cards", [])) if i == hero else []
		}
		players_out.append(entry)
	var legal: Dictionary = game.get_legal_actions(hero)
	var actions_out := []
	for action in legal.get("actions", []):
		actions_out.append(str(action))
	return {
		"kind": KIND,
		"version": VERSION,
		"hero": hero,
		"hand_number": _int(game.hand_number, 0),
		"stage": str(game.stage),
		"small_blind": _int(game.small_blind, TableState.SMALL_BLIND),
		"big_blind": _int(game.big_blind, TableState.BIG_BLIND),
		"button_index": _int(game.button_index, 0),
		"small_blind_player_index": _int(game.small_blind_player_index, -1),
		"big_blind_player_index": _int(game.big_blind_player_index, -1),
		"current_bet": _int(game.current_bet, 0),
		"min_raise": _int(game.min_raise, 0),
		"current_player_index": _int(game.current_player_index, -1),
		"community_cards": CardUtil.clone_cards(game.community_cards),
		"pot": _int(game.total_pot(), 0),
		"to_call": _int(game.get_to_call(hero), 0),
		"legal_actions": actions_out,
		"min_raise_to": _int(legal.get("min_raise_to", 0), 0),
		"max_raise_to": _int(legal.get("max_raise_to", 0), 0),
		"players": players_out,
		"public_action_history": _clone_history(game.public_action_history)
	}

## Rebuild a PokerRound from a captured context. Returns null when the version
## is unsupported (including old unversioned data) or any required field is
## malformed. Non-integral floats, unknown statuses/stages and card ranks
## outside 2..14 are rejected instead of being silently coerced.
static func restore(context: Dictionary) -> Variant:
	if not _valid_schema(context):
		return null
	if _int(context.get("version", -1), -1) != VERSION:
		return null
	if context.has("kind") and str(context.get("kind", "")) != KIND:
		return null
	for key in _REQUIRED_INTS:
		if not context.has(key) or not _is_int_like(context.get(key)):
			return null
	var hero := _int(context.get("hero", -1), -1)
	var players_raw: Variant = context.get("players", null)
	if not (players_raw is Array) or (players_raw as Array).is_empty() or (players_raw as Array).size() > MAX_PLAYERS:
		return null
	if hero < 0 or hero >= (players_raw as Array).size():
		return null
	var stage := str(context.get("stage", ""))
	if not _STAGES.has(stage):
		return null
	var community: Variant = _parse_cards(context.get("community_cards", []))
	if community == null:
		return null
	var players_out := []
	for i in range((players_raw as Array).size()):
		var raw: Variant = players_raw[i]
		if not (raw is Dictionary):
			return null
		var source: Dictionary = raw
		var status := str(source.get("status", TableState.STATUS_ACTIVE))
		if not _STATUSES.has(status):
			return null
		for numeric_key in ["stack", "current_bet", "total_bet", "last_action_bet"]:
			if not _is_int_like(source.get(numeric_key, 0)):
				return null
		var cards: Variant = _parse_cards(source.get("hole_cards", []))
		if cards == null:
			return null
		if i != hero and not (cards as Array).is_empty():
			# Other seats must never carry hidden hole cards through a context.
			cards = []
		players_out.append({
			"id": _int(source.get("id", i), i),
			"name": str(source.get("name", "")),
			"is_human": bool(source.get("is_human", false)),
			"stack": _int(source.get("stack", 0), 0),
			"current_bet": _int(source.get("current_bet", 0), 0),
			"total_bet": _int(source.get("total_bet", 0), 0),
			"status": status,
			"has_acted": bool(source.get("has_acted", false)),
			"last_action_bet": _int(source.get("last_action_bet", 0), 0),
			"difficulty": "medium",
			"personality": {},
			"last_action": str(source.get("last_action", "")),
			"last_action_note": "",
			"hand_result": {},
			"hole_cards": cards
		})
	var script: GDScript = load("res://scripts/game/poker_round.gd")
	if script == null:
		return null
	var restored = script.new()
	restored.players = players_out
	restored.community_cards = community
	restored.stage = stage
	restored.button_index = _int(context.get("button_index", 0), 0)
	restored.small_blind_player_index = _int(context.get("small_blind_player_index", -1), -1)
	restored.big_blind_player_index = _int(context.get("big_blind_player_index", -1), -1)
	restored.current_bet = _int(context.get("current_bet", 0), 0)
	restored.min_raise = _int(context.get("min_raise", 0), 0)
	restored.small_blind = _int(context.get("small_blind", TableState.SMALL_BLIND), TableState.SMALL_BLIND)
	restored.big_blind = _int(context.get("big_blind", TableState.BIG_BLIND), TableState.BIG_BLIND)
	restored.hand_number = _int(context.get("hand_number", 0), 0)
	restored.current_player_index = _int(context.get("current_player_index", -1), -1)
	restored.public_action_history = _clone_history(context.get("public_action_history", []))
	# No future deck is restored; only the public board exists.
	restored.deck = Deck.new()
	restored.deck.cards = []
	restored.capture_decision_context = false
	var legal: Dictionary = restored.get_legal_actions(hero)
	if legal.actions != context.legal_actions or int(legal.min_raise_to) != int(context.min_raise_to) or int(legal.max_raise_to) != int(context.max_raise_to):
		return null
	if int(restored.total_pot()) != int(context.pot) or int(restored.get_to_call(hero)) != int(context.to_call):
		return null
	return restored

static func _valid_schema(context: Dictionary) -> bool:
	if context.get("kind") != KIND or not _is_number(context.get("version")) or int(context.version) != VERSION:
		return false
	for key in _REQUIRED_INTS + ["hero", "pot", "to_call", "min_raise_to", "max_raise_to"]:
		if not _is_number(context.get(key)) or abs(float(context[key])) > 100000000:
			return false
	var seats: Variant = context.get("players")
	if not seats is Array or seats.size() < 2 or seats.size() > MAX_PLAYERS:
		return false
	var hero := int(context.hero)
	if hero < 0 or hero >= seats.size() or int(context.current_player_index) != hero:
		return false
	for key in ["button_index", "small_blind_player_index", "big_blind_player_index"]:
		if int(context[key]) < -1 or int(context[key]) >= seats.size(): return false
	if int(context.button_index) < 0 or int(context.big_blind) <= 0 or int(context.small_blind) < 0 or int(context.min_raise) <= 0:
		return false
	for key in ["hand_number", "pot", "to_call", "current_bet", "min_raise_to", "max_raise_to"]:
		if int(context[key]) < 0: return false
	var lengths := {TableState.STAGE_PREFLOP: 0, TableState.STAGE_FLOP: 3, TableState.STAGE_TURN: 4, TableState.STAGE_RIVER: 5}
	if not lengths.has(context.get("stage")): return false
	var board: Variant = _parse_cards(context.get("community_cards"))
	if board == null or board.size() != int(lengths[context.stage]): return false
	var known := {}
	for card in board:
		var key := CardUtil.card_key(card)
		if known.has(key): return false
		known[key] = true
	for i in range(seats.size()):
		var seat: Variant = seats[i]
		if not seat is Dictionary: return false
		for key in ["stack", "current_bet", "total_bet", "last_action_bet"]:
			if not _is_number(seat.get(key)) or float(seat[key]) < 0 or float(seat[key]) > 100000000: return false
		if float(seat.total_bet) < float(seat.current_bet) or not seat.get("has_acted") is bool or not seat.get("last_action") is String:
			return false
		if not _STATUSES.has(seat.get("status")): return false
		if i == hero:
			var cards: Variant = _parse_cards(seat.get("hole_cards"))
			if cards == null or cards.size() != 2: return false
			for card in cards:
				var key := CardUtil.card_key(card)
				if known.has(key): return false
				known[key] = true
	var legal: Variant = context.get("legal_actions")
	if not legal is Array or legal.is_empty(): return false
	for action in legal:
		if not action is String or not [TableState.ACTION_FOLD, TableState.ACTION_CHECK, TableState.ACTION_CALL, TableState.ACTION_RAISE, TableState.ACTION_ALL_IN].has(action): return false
	var history: Variant = context.get("public_action_history")
	if not history is Array: return false
	for observation in history:
		if not observation is Dictionary: return false
		for key in ["actor", "pot_before", "to_call_before", "stack_before", "bet_before", "actor_bet_before", "actor_total_before", "big_blind", "button", "active_count", "paid", "raise_to", "pot_after"]:
			if not _is_number(observation.get(key)) or float(observation[key]) < 0 or float(observation[key]) > 100000000: return false
		if int(observation.actor) >= seats.size() or int(observation.big_blind) <= 0: return false
		if not [TableState.ACTION_FOLD, TableState.ACTION_CHECK, TableState.ACTION_CALL, TableState.ACTION_RAISE, TableState.ACTION_ALL_IN].has(observation.get("action")): return false
		for key in ["increased_current_bet", "all_in", "is_all_in_call"]:
			if not observation.get(key) is bool: return false
		var previous: Variant = _parse_cards(observation.get("board_before"))
		if previous == null or not lengths.has(observation.get("street")) or previous.size() != int(lengths[observation.street]): return false
		if previous.size() > board.size() or previous != board.slice(0, previous.size()): return false
	return true

static func _is_number(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))

static func _clone_history(value: Variant) -> Array:
	var out := []
	if not (value is Array):
		return out
	for item in (value as Array):
		if not (item is Dictionary):
			continue
		var copy: Dictionary = (item as Dictionary).duplicate(true)
		if copy.has("board_before"):
			var parsed: Variant = _parse_cards(copy.get("board_before", []))
			if parsed != null:
				copy["board_before"] = parsed
		out.append(copy)
	return out

static func _parse_cards(value: Variant) -> Variant:
	if not (value is Array):
		return null
	var out := []
	for card in (value as Array):
		if not (card is Dictionary):
			return null
		var rank_value: Variant = (card as Dictionary).get("rank", null)
		var suit_value: Variant = (card as Dictionary).get("suit", null)
		if not _is_int_like(rank_value):
			return null
		var rank := _int(rank_value, 0)
		if rank < 2 or rank > 14:
			return null
		if not (suit_value is String) or not CardUtil.SUITS.has(str(suit_value)):
			return null
		out.append({"rank": rank, "suit": str(suit_value)})
	return out

static func _is_int_like(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(value) and value == floor(value)
	if value is String:
		return value.is_valid_int()
	return false

static func _int(value: Variant, fallback: int) -> int:
	if value is int:
		return value
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	if value is String and value.is_valid_int():
		return value.to_int()
	return fallback
