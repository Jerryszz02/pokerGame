class_name AiTurnWorker
extends RefCounted
## One isolated decision at a time. Only the owner on the main thread joins
## the worker or applies its result; the worker never accesses the scene tree.

var _thread: Thread

func start(game: PokerRound, player_index: int) -> Error:
	if _thread != null:
		return ERR_BUSY
	var snapshot := PokerRound.new()
	snapshot.players = game.players.duplicate(true)
	for i in range(snapshot.players.size()):
		if i != player_index:
			snapshot.players[i].hole_cards = []
	snapshot.community_cards = game.community_cards.duplicate(true)
	snapshot.stage = game.stage
	snapshot.button_index = game.button_index
	snapshot.current_player_index = player_index
	snapshot.current_bet = game.current_bet
	snapshot.min_raise = game.min_raise
	snapshot.big_blind = game.big_blind
	snapshot.small_blind = game.small_blind
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
