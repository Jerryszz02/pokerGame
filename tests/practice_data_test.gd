extends SceneTree

var failures := 0
var scratch := OS.get_cache_dir().path_join("poker-practice-data-" + str(Time.get_ticks_usec()))

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_configs()
	_test_frames()
	_test_store()
	_test_achievements()
	_test_peak_ownership()
	_test_failures()
	if failures == 0:
		print("Practice data tests passed.")
	quit(failures)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _passive(game: PokerRound) -> void:
	var guard := 0
	while game.stage != TableState.STAGE_HAND_OVER and guard < 300:
		var legal := game.get_legal_actions(game.current_player_index)
		check(game.apply_action("check" if legal.actions.has("check") else "call"), "passive action legal")
		guard += 1
	check(game.stage == TableState.STAGE_HAND_OVER, "hand completes")

func _game(options: Dictionary = {}) -> PokerRound:
	var game := PokerRound.new()
	game.shuffle_rng.seed = 19347
	game.start_new_match(1, "simple", options)
	return game

func _test_configs() -> void:
	for chips in MatchConfig.STACKS:
		for blinds in MatchConfig.BLINDS:
			for opponents in range(1, 6):
				var game := PokerRound.new()
				var options := {"initial_stack": chips, "small_blind": blinds[0], "big_blind": blinds[1]}
				game.start_new_match(opponents, "simple", options)
				check(game.initial_stack == chips and game.players.size() == opponents + 1, "actual stack/count matches config")
				check(game.total_pot() == blinds[0] + blinds[1], "actual blinds paid")
				check(game.get_legal_actions(game.current_player_index).min_raise_to == 2 * blinds[1], "actual min raise uses blind")
				options.initial_stack = 99
				check(game.match_config.initial_stack == chips, "config snapshot independent")
				_passive(game)
				var total := 0
				for p in game.players:
					total += p.stack
				check(total == chips * (opponents + 1), "all stake combinations conserve chips")
	var bad := MatchConfig.DEFAULTS.duplicate(true)
	for value in [null, [], {}, true, 1000.5, "1000"]:
		bad.initial_stack = value
		check(not MatchConfig.validate(bad), "invalid typed stack rejected")
		check(MatchConfig.STACKS.has(MatchConfig.normalize(bad).initial_stack), "invalid input normalizes safely")
	var win := _game({"initial_stack": 5000})
	win.players[0].stack = 10000
	win.players[1].stack = 0
	win.start_next_hand()
	check(win.match_summary.net_profit == 5000, "match net profit uses actual initial stack")

func _test_frames() -> void:
	var game := _game()
	check(game.completed_hand_record().is_empty(), "unfinished hand cannot expose replay")
	game.apply_action("all_in")
	game.apply_action("call")
	var record := game.completed_hand_record()
	check(not record.is_empty(), "complete hand has record")
	var streets := []
	for frame in record.frames:
		if frame.type == "street":
			streets.append(frame.stage)
		var cards: Array = frame.community_cards.duplicate()
		for player in frame.players:
			cards.append_array(player.hole_cards)
		var unique := {}
		for card in cards:
			unique[CardUtil.card_key(card)] = true
		check(unique.size() == cards.size(), "frames have no duplicated dealt cards")
	check(streets == ["flop", "turn", "river"], "all-in replay has actual street names")
	check(record.frames.back().stage == "hand_over" and record.frames.back().pot == 0, "final frame reflects distributed pot")
	check(record.frames[0].players[0].stack == 1000 and record.frames[1].current_player_index == 0, "preblind and action-ready checkpoints")
	var original := game.completed_hand_record()
	record.frames[0].players[0].stack = -3
	check(game.completed_hand_record() == original, "replay deep copy cannot mutate game or source record")
	check(game.completed_hand_record().created_at == original.created_at, "stable timestamp on repeated reads")
	var folded := _game()
	folded.apply_action("fold")
	var fold_record := folded.completed_hand_record()
	check(fold_record.frames.back().community_cards.is_empty(), "folded hand does not fabricate runout")
	check(fold_record.refunds[0].amount == 10, "uncalled blind overage recorded")
	check(not fold_record.uncontested_win and not fold_record.exclusive_win, "opponent win is not human win")
	check(fold_record.net_change == -10, "net uses stack delta, not pot refund")
	# Three contributors, same player wins two distinct pots: not a split.
	var side := PokerRound.new()
	side.start_new_match(2, "simple")
	side.community_cards = [c(2,"C"), c(4,"D"), c(6,"H"), c(8,"S"), c(10,"C")]
	var holes := [[c(14,"S"),c(14,"H")],[c(13,"S"),c(13,"H")],[c(12,"S"),c(12,"H")]]
	for i in range(3):
		side.players[i].hole_cards = holes[i]
		side.players[i].total_bet = [200,200,100][i]
		side.players[i].current_bet = [200,200,100][i]
		side.players[i].stack = 1000 - side.players[i].total_bet
		side.players[i].status = "all_in"
	side._showdown()
	var side_record := side.completed_hand_record()
	check(side_record.pots.size() == 2 and side_record.winners.size() == 2, "two distinct payouts recorded")
	check(side_record.exclusive_win and not side_record.split, "winning multiple pots is not a split")
	check(side_record.net_change == 300, "sidepot net correct")
	var assisted := _game()
	var independent := _game()
	assisted.mark_assistance_viewed()
	_passive(assisted)
	_passive(independent)
	check(assisted.community_cards == independent.community_cards, "assistance flag doesn't consume poker RNG")

func _test_store() -> void:
	var store := PracticeStore.new(scratch.path_join("good"))
	var old := LocalProfile.default_profile()
	old.stats.total_hands = 40
	store.migrate_legacy(old)
	var game := _game()
	_passive(game)
	var record := game.completed_hand_record()
	check(store.commit_hand(record), "record written")
	check(store.commit_hand(record), "duplicate commit success")
	check(store.statistics().hands == 1, "duplicate commits count once")
	var reopened := PracticeStore.new(store.base_path)
	check(reopened.records().size() == 1 and reopened.statistics().hands == 1, "restart restores records and stats")
	check(reopened.records()[0].frames == record.frames, "persisted frames equal original")
	check(reopened.statistics({"mode":"practice"}).hands == 0, "mode filter")
	check(reopened.statistics({"since":"9999-01-01T00:00:00"}).hands == 0, "future time filter excludes old hands")
	check(reopened.statistics({"since":"2000-01-01T00:00:00"}).hands == 1, "time filter keeps known recent sample")
	check(reopened.statistics({"depth":50}).hands == 1, "depth in BB filter")
	check(reopened.statistics({"depth":100}).hands == 0, "different depth excluded")
	old.stats.total_hands = 99
	reopened.migrate_legacy(old)
	check(reopened.state.legacy_stats.total_hands == 40, "legacy migrated once without fake history")
	check(reopened.complete_tutorial("T1") and reopened.complete_tutorial("T1"), "tutorial progress idempotent")
	check(reopened.state.tutorial_completed.size() == 1 and reopened.state.achievements.has("first_lesson"), "tutorial achievement real completion")
	check(not reopened.complete_tutorial("bad"), "unknown lesson rejected")
	check(reopened.mark_replay_complete(record.id), "valid completed traversal unlocks replay")
	check(not reopened.mark_replay_complete("missing"), "empty replay cannot unlock")
	check(reopened.finish_match(record.match_id,"left"), "early leave stored")
	check(reopened.statistics().completed_matches == 0 and reopened.statistics().left_matches == 1, "early leave not a completed loss")
	check(reopened.delete_record(record.id), "delete full replay")
	check(reopened.records().is_empty() and reopened.statistics().hands == 1, "deletion retains cumulative ledger")
	check(reopened.commit_hand(record) and reopened.records().is_empty(), "deleted record doesn't reappear on duplicate retry")
	var again := PracticeStore.new(store.base_path)
	check(again.statistics().hands == 1 and again.state.achievements.has("replay_first"), "deletion retains stats and achievements across restart")
	var lesson := _game({"mode":"tutorial"})
	_passive(lesson)
	check(not again.commit_hand(lesson.completed_hand_record()), "tutorial excluded from ordinary results")

func _test_failures() -> void:
	var game := _game()
	_passive(game)
	var record := game.completed_hand_record()
	var future_dir := scratch.path_join("future")
	DirAccess.make_dir_recursive_absolute(future_dir)
	_write(future_dir.path_join("profile.json"), '{"version":999}')
	var future := PracticeStore.new(future_dir)
	check(not future.commit_hand(record) and not future.complete_tutorial("T1") and not future.delete_record(record.id), "future metadata locks every write")
	check(FileAccess.get_file_as_string(future_dir.path_join("profile.json")) == '{"version":999}', "future bytes preserved")
	var good := PracticeStore.new(scratch.path_join("corrupt"))
	check(good.commit_hand(record), "setup valid sibling")
	_write(good.base_path.path_join("hand_bad.json"), '{"schema_version":1,"frames":[]}')
	var corrupt := PracticeStore.new(good.base_path)
	check(corrupt.records().size() == 1 and not corrupt.notice.is_empty(), "corrupt sibling skipped with notice")
	var blocked_path := scratch.path_join("blocked")
	_write(blocked_path, "not a directory")
	var blocked := PracticeStore.new(blocked_path)
	check(not blocked.commit_hand(record) and blocked.statistics().hands == 0, "unwritable destination not counted")
	DirAccess.remove_absolute(blocked_path)
	check(blocked.commit_hand(record) and blocked.statistics().hands == 1, "retry after directory repair succeeds once")
	# The hand file can be written but the metadata destination cannot be replaced.
	var partial := PracticeStore.new(scratch.path_join("partial"))
	DirAccess.make_dir_recursive_absolute(partial.base_path.path_join("profile.json"))
	check(not partial.commit_hand(record), "metadata replacement failure reported")
	check(partial.records().size() == 1 and partial.statistics().hands == 0, "durable pending record kept without claiming committed stats")
	DirAccess.remove_absolute(partial.base_path.path_join("profile.json"))
	check(partial.commit_hand(record) and partial.statistics().hands == 1, "partial save retries ledger only")
	var cfg_path := scratch.path_join("future.cfg")
	_write(cfg_path, '[meta]\nversion=99\n')
	var profile := LocalProfile.load_profile(cfg_path)
	check(profile.get("read_only",false) and not LocalProfile.save_profile(profile,cfg_path), "future preference profile protected")
	var full := PracticeStore.new(scratch.path_join("full"))
	full._disk_hand_count = 1000
	check(not full.commit_hand(record) and full.statistics().hands == 0, "capacity gate doesn't evict or claim success")

func _test_peak_ownership() -> void:
	var store := PracticeStore.new(scratch.path_join("peak-ownership"))
	var game := _game({"mode":"practice"})
	# Controlled settlements keep both hands in one match while making the
	# second hand start below the first hand's peak.
	game._hand_starting_stacks = [1000, 1000]
	game.players[0].stack = 2500
	game.players[1].stack = 500
	game.mark_assistance_viewed()
	game.stage = TableState.STAGE_HAND_OVER
	game._finish_hand()
	var assisted_high := game.completed_hand_record()
	check(assisted_high.peak_stack == 2500, "first hand records its own high peak")
	check(store.commit_hand(assisted_high), "assisted high hand commits")

	game.players[0].stack = 1500
	game.players[1].stack = 1500
	game.start_next_hand()
	game._hand_starting_stacks = [1500, 1500]
	game.players[0].stack = 1400
	game.players[1].stack = 1600
	game.stage = TableState.STAGE_HAND_OVER
	game._finish_hand()
	var independent_low := game.completed_hand_record()
	check(independent_low.peak_stack == 1500, "second hand does not inherit earlier peak")
	check(store.commit_hand(independent_low), "independent low hand commits")
	check(store.statistics({"assistance":true}).peak_stack == 2500, "assisted peak filter is per hand")
	check(store.statistics({"assistance":false}).peak_stack == 1500, "independent peak filter is per hand")
	check(store.state.achievements.has("stack_double_assisted") and not store.state.achievements.has("stack_double_independent"), "assisted to independent achievement source stays isolated")

	var reverse_store := PracticeStore.new(scratch.path_join("peak-ownership-reverse"))
	var reverse := _game({"mode":"practice"})
	reverse._hand_starting_stacks = [1000, 1000]
	reverse.players[0].stack = 2500
	reverse.players[1].stack = 500
	reverse.stage = TableState.STAGE_HAND_OVER
	reverse._finish_hand()
	var independent_high := reverse.completed_hand_record()
	check(reverse_store.commit_hand(independent_high), "independent high hand commits")
	reverse.players[0].stack = 1500
	reverse.players[1].stack = 1500
	reverse.start_next_hand()
	reverse._hand_starting_stacks = [1500, 1500]
	reverse.players[0].stack = 1400
	reverse.players[1].stack = 1600
	reverse.mark_assistance_viewed()
	reverse.stage = TableState.STAGE_HAND_OVER
	reverse._finish_hand()
	var assisted_low := reverse.completed_hand_record()
	check(assisted_low.peak_stack == 1500, "reverse second hand keeps its own peak")
	check(reverse_store.commit_hand(assisted_low), "reverse assisted low hand commits")
	check(reverse_store.statistics({"assistance":true}).peak_stack == 1500, "reverse assisted peak filter stays per hand")
	check(reverse_store.statistics({"assistance":false}).peak_stack == 2500, "reverse independent peak filter stays per hand")
	check(reverse_store.state.achievements.has("stack_double_independent") and not reverse_store.state.achievements.has("stack_double_assisted"), "independent to assisted achievement source stays isolated")

func _write(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func c(rank: int, suit: String) -> Dictionary:
	return CardUtil.make_card(rank,suit)

func _test_achievements() -> void:
	var store := PracticeStore.new(scratch.path_join("achievements"))
	var game := _game({"mode":"practice"})
	game.players[0].hole_cards = [c(14,"S"),c(14,"H")]
	game.players[1].hole_cards = [c(12,"S"),c(12,"H")]
	game.community_cards = [c(14,"D"),c(13,"H"),c(13,"D"),c(2,"S"),c(3,"H")]
	for p in game.players:
		p.stack = 0
		p.total_bet = 1000
		p.current_bet = 1000
		p.status = "all_in"
	game.mark_assistance_viewed()
	game._showdown()
	var record := game.completed_hand_record()
	check(record.rank_value == HandEvaluator.FULL_HOUSE and record.net_change == 1000, "milestone uses real showdown evaluation")
	check(store.commit_hand(record), "assisted showdown commits")
	check(store.statistics({"assistance":false}).hands == 0 and store.statistics({"assistance":true}).hands == 1, "assisted results separated")
	check(store.statistics().rank_counts.get("葫芦",0) == 1 and store.statistics().rank_win_counts.get("葫芦",0) == 1,"formed and winning rank counters")
	check(store.state.achievements.has("full_house_assisted") and store.state.achievements.has("stack_double_assisted"), "actual rank and 2x milestone unlock with source")
	check(not store.state.achievements.has("full_house_independent"),"assisted milestone not labeled independent")
	store.commit_hand(record)
	check(store.statistics().rank_counts.get("葫芦",0) == 1,"duplicate doesn't repeat rare hand count")
	# A later independent hand may inherit a stack already above 2x entry. Its
	# own peak must not reassign the earlier assisted milestone.
	var inherited := record.duplicate(true)
	inherited.id = "hand-inherited-independent"
	inherited.match_id = "match-inherited-independent"
	inherited.assistance_viewed = false
	inherited.starting_stacks[0] = 2000
	inherited.peak_stack = 2200
	check(store.commit_hand(inherited), "inherited-stack hand commits")
	check(not store.state.achievements.has("stack_double_independent"), "inherited stack does not unlock independent double milestone")
	# A hand that crosses the threshold itself still receives the source label.
	var crossed := record.duplicate(true)
	crossed.id = "hand-crossed-independent"
	crossed.match_id = "match-crossed-independent"
	crossed.assistance_viewed = false
	crossed.starting_stacks[0] = 1000
	crossed.peak_stack = 2000
	check(store.commit_hand(crossed), "threshold-crossing hand commits")
	check(store.state.achievements.has("stack_double_independent"), "threshold crossing unlocks independent double milestone")
	check(store.finish_match(record.match_id,"won",record.config),"completed match records outcome")
	check(store.statistics().completed_matches == 1 and store.statistics({"mode":"free"}).completed_matches == 0,"match counters share filters")
	for id in PracticeStore.LESSONS: store.complete_tutorial(id)
	check(store.state.achievements.has("all_lessons") and store.state.tutorial_completed.size() == 7,"all seven lesson milestone")
	var bad_dir := scratch.path_join("bad-version-type")
	_write(bad_dir.path_join("profile.json"), '{"version":[]}')
	var malformed := PracticeStore.new(bad_dir)
	check(not malformed.commit_hand(record),"malformed version doesn't crash or overwrite")
