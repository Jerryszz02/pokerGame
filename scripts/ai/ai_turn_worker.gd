class_name AiTurnWorker
extends RefCounted
## One isolated decision at a time. Only the owner on the main thread joins
## the worker or applies its result; the worker never accesses the scene tree.

var _thread: Thread

## Build a decision snapshot that exposes public state plus the acting player's
## own hole cards/profile/difficulty only. Opponents' hole cards, hand results,
## personalities, notes and the real remaining deck never enter the snapshot.
static func make_snapshot(game, player_index: int) -> PokerRound:
	var snapshot := PokerRound.new()
	snapshot.players = []
	for i in range(game.players.size()):
		var source: Dictionary = game.players[i]
		var own := i == player_index
		snapshot.players.append({
			"id": int(source.get("id", i)),
			"name": str(source.get("name", "")),
			"is_human": bool(source.get("is_human", false)),
			"stack": int(source.get("stack", 0)),
			"current_bet": int(source.get("current_bet", 0)),
			"total_bet": int(source.get("total_bet", 0)),
			"status": str(source.get("status", TableState.STATUS_ACTIVE)),
			"has_acted": bool(source.get("has_acted", false)),
			"last_action_bet": int(source.get("last_action_bet", 0)),
			# Opponent difficulty is private configuration; the decision snapshot
			# exposes a neutral value for non-acting seats.
			"difficulty": str(source.get("difficulty", "medium")) if own else "medium",
			"hole_cards": CardUtil.clone_cards(source.hole_cards) if own else [],
			"personality": source.personality.duplicate(true) if own and source.personality is Dictionary else {},
			"last_action": str(source.get("last_action", "")),
			"last_action_note": "",
			"hand_result": {}
		})
	snapshot.community_cards = CardUtil.clone_cards(game.community_cards)
	snapshot.public_action_history = clone_history(game.public_action_history)
	snapshot.stage = game.stage
	snapshot.button_index = int(game.button_index)
	snapshot.small_blind_player_index = int(game.small_blind_player_index)
	snapshot.big_blind_player_index = int(game.big_blind_player_index)
	snapshot.current_player_index = player_index
	snapshot.current_bet = int(game.current_bet)
	snapshot.min_raise = int(game.min_raise)
	snapshot.big_blind = int(game.big_blind)
	snapshot.small_blind = int(game.small_blind)
	snapshot.hand_number = int(game.hand_number)
	snapshot.last_message = ""
	# No access to the real future deck: the snapshot carries an empty deck.
	snapshot.deck = Deck.new()
	snapshot.deck.cards = []
	return snapshot

static func clone_history(history: Array) -> Array:
	var copy := []
	for observation in history:
		if observation is Dictionary:
			copy.append((observation as Dictionary).duplicate(true))
	return copy

func start(game: PokerRound, player_index: int) -> Error:
	if _thread != null:
		return ERR_BUSY
	var snapshot := make_snapshot(game, player_index)
	_thread = Thread.new()
	var error := _thread.start(AiDecision.decide.bind(snapshot, player_index))
	if error != OK:
		_thread = null
	return error

func is_started() -> bool:
	return _thread != null

func is_ready() -> bool:
	return _thread != null and not _thread.is_alive()

func take_result() -> Dictionary:
	if not is_ready():
		return {}
	var result: Dictionary = _thread.wait_to_finish()
	_thread = null
	return result

func finish() -> void:
	# Used only when the scene exits, never during menu/pause interaction.
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
