extends SceneTree
## Fixed postflop fixtures. Worker wall time includes polling/snapshot overhead;
## this is not a substitute for the rendered-window latency probe.

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scenarios: Array = []
	for opponents in [1, 5]:
		for street in [[TableState.STAGE_FLOP, 3], [TableState.STAGE_TURN, 4], [TableState.STAGE_RIVER, 5]]:
			var game := PokerRound.new()
			game.shuffle_rng.seed = 20260907
			game.start_new_match(opponents, "hard")
			game.community_cards = game.deck.draw(int(street[1]))
			game.stage = street[0]
			game.current_player_index = 1
			game.current_bet = 0
			for player in game.players:
				player.current_bet = 0
			var samples: Array[float] = []
			for sample in range(5):
				var worker := AiTurnWorker.new()
				var started := Time.get_ticks_usec()
				if worker.start(game, 1) != OK:
					failures += 1
					break
				while not worker.is_ready():
					await process_frame
				var decision := worker.take_result()
				samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
				if not game.get_legal_actions(1).actions.has(decision.get("action_type", "")):
					failures += 1
			samples.sort()
			scenarios.append({"opponents": opponents, "street": street[0], "samples_ms": samples})
	var report := {"engine": Engine.get_version_info().string, "processor": OS.get_processor_name(), "os": OS.get_name(), "seed": 20260907, "scenarios": scenarios, "failures": failures}
	DirAccess.make_dir_recursive_absolute("res://export/evidence")
	var file := FileAccess.open("res://export/evidence/ai-benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	if failures == 0:
		print("AI benchmark passed.")
	else:
		push_error("AI benchmark returned an invalid decision")
	quit(failures)
