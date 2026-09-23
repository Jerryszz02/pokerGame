extends SceneTree

const Profile := preload("res://scripts/game/local_profile.gd")
const Localization := preload("res://scripts/game/localization.gd")
const SHOT_DIR := "/tmp/poker_guided_tutorial_audit"
var failures := 0
var run_id := str(Time.get_ticks_usec())
var cjk := RegEx.new()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.gui_embed_subwindows = true
	root.mode = Window.MODE_WINDOWED
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	cjk.compile("[一-龥]")
	for size in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		for language in ["zh_CN", "en"]:
			await _probe(size, language)
	if failures == 0: print("Guided tutorial UI probes passed.")
	quit(failures)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _probe(size: Vector2i, language: String) -> void:
	root.size = size
	DisplayServer.window_set_size(size)
	var path := OS.get_cache_dir().path_join("guided-ui-%s-%d-%s/profile.cfg" % [run_id, size.x, language])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var profile := Profile.default_profile()
	profile.settings.language = language
	profile.settings.music_volume = 0.0
	profile.settings.sound_enabled = false
	check(Profile.save_profile(profile, path), "isolated tutorial profile saves")
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = path
	scene.deepseek_review.service_url = ""
	root.add_child(scene)
	scene.set_process(false)
	await _frames()
	var home: Button = scene.find_child("HomeTutorialButton", true, false)
	check(home != null, "home has tutorial entry")
	if home == null: return
	home.emit_signal("pressed")
	await _frames()
	check(scene.tutorial_controller.lesson_id == "G1" and scene.game == scene.tutorial_controller.game, "home enters first real table")
	await _drive_guided(scene, "G1", size, language)
	check(scene.tutorial_controller.completed and scene.practice_store.state.guided_tutorial.completed.has("G1"), "G1 completes and saves")
	_check_isolation(scene, "G1")
	var next: Button = scene.find_child("TutorialNextHandButton", true, false)
	check(next != null, "G1 offers next hand")
	if next == null: return
	next.emit_signal("pressed")
	await _frames()
	check(scene.tutorial_controller.lesson_id == "G2" and scene.game.players[0].stack == 990, "G2 refills teaching stack and posts blind")
	await _drive_guided(scene, "G2", size, language)
	check(scene.tutorial_controller.completed and scene.game.players[0].status == TableState.STATUS_FOLDED, "G2 finishes by folding")
	check(scene.practice_store.state.guided_tutorial.completed.has("G2"), "G2 progress saved")
	_check_isolation(scene, "G2")
	var reopened := PracticeStore.new(scene.practice_store.base_path)
	check(reopened.guided_resume_lesson() == "G3", "restart resumes at unfinished G3")
	next = scene.find_child("TutorialNextHandButton", true, false)
	check(next != null, "G2 offers next hand")
	var leave: Button = scene.find_child("TutorialExitButton", true, false)
	check(leave != null, "completed hand can exit tutorial")
	if leave != null: leave.emit_signal("pressed")
	await _frames()
	var resume: Button = scene.find_child("HomeTutorialButton", true, false)
	check(resume != null, "menu restores tutorial entry")
	if resume != null: resume.emit_signal("pressed")
	await _frames()
	check(scene.tutorial_controller.lesson_id == "G3", "re-entering resumes unfinished G3")
	_check_layout(scene, size, language, "G3.initial")
	if size == Vector2i(1280, 720) and language == "zh_CN":
		await _test_free_hand(scene, size)
	else:
		_test_raise_help(scene)
	scene.queue_free()
	await _frames()

func _drive_guided(scene: Control, id: String, size: Vector2i, language: String) -> void:
	for turn in range(70):
		await _frames()
		_check_layout(scene, size, language, id + "." + str(turn))
		if scene.tutorial_controller.completed: return
		var step: Dictionary = scene.tutorial_controller.current_step()
		if bool(step.can_continue):
			var before := _round_snapshot(scene)
			scene._process(100.0)
			check(_round_snapshot(scene) == before, id + " observation freezes progression")
			var advance: Button = scene.find_child("TutorialContinueButton", true, false)
			check(advance != null and not advance.disabled, id + " observation has continue")
			if advance == null: return
			var old_id: String = step.id
			advance.emit_signal("pressed")
			var changed_id: String = scene.tutorial_controller.current_step().id
			check(changed_id != old_id, id + " continue advances once")
			advance.emit_signal("pressed")
			check(scene.tutorial_controller.current_step().id == changed_id, id + " stale continue cannot skip")
		elif scene.game.is_ai_turn():
			if step.id == "G1.preflop_opponent" and size == Vector2i(1280, 720) and language == "zh_CN":
				await _test_freeze_overlays(scene, language)
			scene._advance_tutorial_opponent(1.0)
		else:
			var action_name := "Action_call" if step.id.ends_with(".call") else ("Action_fold" if step.id.ends_with(".fold") else "Action_check")
			var action: Button = scene.find_child(action_name, true, false)
			check(action != null and not action.disabled, id + " expected action enabled: " + action_name)
			for other in ["Action_call", "Action_check", "Action_fold", "Action_all_in", "RaiseExpandButton"]:
				if other == action_name: continue
				var blocked: Button = scene.find_child(other, true, false)
				if blocked != null: check(blocked.disabled, id + " other action blocked: " + other)
			if action == null: return
			var save_path: String = scene.practice_store.base_path
			var test_save_failure: bool = step.id == "G2.fold" and size == Vector2i(1280, 720) and language == "zh_CN"
			if test_save_failure:
				var blocked_path: String = save_path + "-blocked"
				var file := FileAccess.open(blocked_path, FileAccess.WRITE)
				file.store_string("not a directory")
				file.close()
				scene.practice_store.base_path = blocked_path
			action.emit_signal("pressed")
			if test_save_failure:
				check(scene._pending_guided_lessons.has("G2") and not scene.practice_store.state.guided_tutorial.completed.has("G2"), "failed terminal save stays pending")
				scene.practice_store.base_path = save_path
				var retry: Button = scene.find_child("TutorialSaveRetry", true, false)
				check(retry != null, "failed guided save offers retry")
				if retry != null: retry.emit_signal("pressed")
				check(scene._pending_guided_lessons.is_empty() and scene.practice_store.state.guided_tutorial.completed.has("G2"), "retry commits terminal progress")
	check(false, id + " finishes within guided steps")

func _test_freeze_overlays(scene: Control, language: String) -> void:
	var game_before: PokerRound = scene.game
	var coach_before: TutorialController = scene.tutorial_controller
	var round_before := _round_snapshot(scene)
	var settings: Button = scene.find_child("SettingsButton", true, false)
	check(settings != null, "tutorial settings available")
	if settings == null: return
	settings.emit_signal("pressed")
	scene._process(100.0)
	check(_round_snapshot(scene) == round_before, "settings freeze opponent")
	var popup: PopupPanel = scene.find_child("HelpPopup", true, false)
	var rules: Button = scene.find_child("RulesReferenceButton", true, false)
	check(rules != null, "tutorial rules available on demand")
	if rules != null: rules.emit_signal("pressed")
	popup = scene.find_child("HelpPopup", true, false)
	check(popup != null and popup.visible, "rules popup opens")
	scene._process(100.0)
	check(_round_snapshot(scene) == round_before, "rules popup freezes opponent")
	if popup != null: popup.hide()
	await _frames()
	settings = scene.find_child("SettingsButton", true, false)
	settings.emit_signal("pressed")
	var pause: Button = scene.find_child("PauseToggleButton", true, false)
	check(pause != null, "tutorial pause available")
	if pause != null: pause.emit_signal("pressed")
	check(scene.paused, "tutorial paused")
	scene._process(100.0)
	check(_round_snapshot(scene) == round_before, "pause freezes opponent")
	var resume: Button = scene.find_child("PauseResumeButton", true, false)
	check(resume != null, "tutorial pause can resume")
	if resume != null: resume.emit_signal("pressed")
	await _frames()
	settings = scene.find_child("SettingsButton", true, false)
	settings.emit_signal("pressed")
	var options: OptionButton = scene.find_child("LanguageOptions", true, false)
	check(options != null, "tutorial language picker available")
	if options != null: options.item_selected.emit(2 if language == "zh_CN" else 1)
	check(scene.game == game_before and scene.tutorial_controller == coach_before and _round_snapshot(scene) == round_before, "language switch preserves teaching hand")
	await _frames()
	settings = scene.find_child("SettingsButton", true, false)
	settings.emit_signal("pressed")
	options = scene.find_child("LanguageOptions", true, false)
	if options != null: options.item_selected.emit(1 if language == "zh_CN" else 2)
	check(scene.game == game_before and scene.tutorial_controller == coach_before and _round_snapshot(scene) == round_before, "returning language preserves teaching hand")
	await _frames()

func _test_raise_help(scene: Control) -> void:
	var expand: Button = scene.find_child("RaiseExpandButton", true, false)
	check(expand != null and not expand.disabled, "G3 raise is available")
	if expand == null: return
	expand.emit_signal("pressed")
	var slider: HSlider = scene.find_child("RaiseAmountSlider", true, false)
	var confirm: Button = scene.find_child("RaiseConfirmButton", true, false)
	check(slider != null and confirm != null, "G3 uses real raise slider and confirm")
	if slider == null: return
	var next_amount := mini(int(slider.max_value), int(slider.min_value) + int(scene.game.big_blind))
	slider.value = next_amount
	var coach: Label = scene.find_child("TutorialCoachText", true, false)
	check(coach != null and coach.text.contains(str(next_amount)) and coach.text.contains(str(next_amount - int(scene.game.players[0].current_bet))), "raise help shows total and extra payment")

func _test_free_hand(scene: Control, size: Vector2i) -> void:
	_test_raise_help(scene)
	await _frames()
	_check_layout(scene, size, "zh_CN", "G3.raise")
	var confirm: Button = scene.find_child("RaiseConfirmButton", true, false)
	check(confirm != null and not confirm.disabled, "G3 raise confirms")
	if confirm == null: return
	confirm.emit_signal("pressed")
	check(scene.game.is_ai_turn(), "G3 raise passes turn to AI")
	_apply_ai(scene, TableState.ACTION_FOLD)
	check(scene.tutorial_controller.completed and scene.game.last_hand_human_won, "AI fold gives real G3 win")
	_check_isolation(scene, "G3.raise")
	var restart: Button = scene.find_child("TutorialRestartButton", true, false)
	check(restart != null, "G3 can restart")
	if restart == null: return
	var old_epoch: int = scene._ai_epoch
	restart.emit_signal("pressed")
	check(scene._ai_epoch > old_epoch and not scene.tutorial_controller.completed, "restart invalidates AI and resets hand")
	var stale_players := var_to_str(scene.game.players)
	scene._ai_request = {"epoch": old_epoch, "hand": scene.game.hand_number, "actor": scene.game.current_player_index, "stage": scene.game.stage}
	scene._ai_result = {"action_type": TableState.ACTION_FOLD, "amount": 0}
	check(not scene._execute_ai_turn_if_allowed() and var_to_str(scene.game.players) == stale_players, "stale AI result cannot bet after restart")
	var call: Button = scene.find_child("Action_call", true, false)
	check(call != null and not call.disabled, "G3 permits call")
	if call == null: return
	call.emit_signal("pressed")
	check(scene.game.is_ai_turn(), "call passes action to opponent")
	_apply_ai(scene, TableState.ACTION_CHECK)
	check(scene.game.community_cards.size() == 3, "AI check reveals real flop")
	_apply_ai(scene, TableState.ACTION_RAISE, 40)
	var fold: Button = scene.find_child("Action_fold", true, false)
	check(fold != null and not fold.disabled, "G3 permits fold against bet")
	if fold == null: return
	fold.emit_signal("pressed")
	check(scene.tutorial_controller.completed and not scene.game.last_hand_human_won, "G3 fold gives real loss")
	_check_isolation(scene, "G3.fold")
	restart = scene.find_child("TutorialRestartButton", true, false)
	if restart == null: return
	restart.emit_signal("pressed")
	var before := _round_snapshot(scene)
	var all_in: Button = scene.find_child("Action_all_in", true, false)
	check(all_in != null and not all_in.disabled, "G3 permits all-in")
	if all_in == null: return
	all_in.emit_signal("pressed")
	var popup: PopupPanel = scene.find_child("TutorialAllInPopup", true, false)
	check(popup != null and popup.visible, "first all-in shows confirmation")
	check(_round_snapshot(scene) == before, "all-in note has not bet")
	if popup == null: return
	popup.hide()
	await _frames()
	check(_round_snapshot(scene) == before, "canceling all-in preserves state")
	all_in = scene.find_child("Action_all_in", true, false)
	if all_in == null: return
	all_in.emit_signal("pressed")
	popup = scene.find_child("TutorialAllInPopup", true, false)
	var yes: Button = popup.find_child("TutorialConfirmAllInButton", true, false) if popup != null else null
	check(yes != null, "all-in offers explicit confirm")
	if yes == null: return
	yes.emit_signal("pressed")
	check(_round_snapshot(scene) != before, "confirmed all-in uses real action")
	if scene.game.is_ai_turn(): _apply_ai(scene, TableState.ACTION_CALL)
	check(scene.tutorial_controller.completed, "all-in hand reaches terminal result")
	_check_isolation(scene, "G3.all_in")
	check(scene.practice_store.state.guided_tutorial.completed.has("G3"), "G3 progress saved")
	var reopened := PracticeStore.new(scene.practice_store.base_path)
	check(reopened.guided_resume_lesson() == "G1", "all three completed can restart course")
	check(scene.find_child("TutorialStartFreeButton", true, false) != null and scene.find_child("TutorialReplayThirdButton", true, false) != null, "G3 shows free play and replay options")

func _apply_ai(scene: Control, action: String, amount: int = 0) -> void:
	check(scene.game.is_ai_turn(), "fixture AI action begins on opponent turn")
	if not scene.game.is_ai_turn(): return
	var legal: Dictionary = scene.game.get_legal_actions(scene.game.current_player_index)
	check(legal.actions.has(action), "fixture AI action legal: " + action)
	if not legal.actions.has(action): return
	scene._ai_request = {"epoch": scene._ai_epoch, "hand": scene.game.hand_number, "actor": scene.game.current_player_index, "stage": scene.game.stage}
	scene._ai_result = {"action_type": action, "amount": amount, "decision_label": "test"}
	check(scene._execute_ai_turn_if_allowed(), "fixture AI uses normal action path")
	scene._ai_result = {}
	scene._render_table()

func _check_isolation(scene: Control, label: String) -> void:
	check(scene.practice_store.statistics().hands == 0 and scene.practice_store.records().is_empty(), label + " excludes normal records")
	check(scene._pending_records.is_empty() and scene._pending_matches.is_empty() and scene._style_queue.is_empty(), label + " excludes ordinary save and analysis queues")

func _round_snapshot(scene: Control) -> String:
	return var_to_str([scene.game.players, scene.game.stage, scene.game.community_cards, scene.game.current_player_index, scene.game.total_pot()])

func _check_layout(scene: Control, size: Vector2i, language: String, label: String) -> void:
	var coach: Control = scene.find_child("TutorialCoachCard", true, false)
	var copy: Label = scene.find_child("TutorialCoachText", true, false)
	check(coach != null and copy != null, label + " coach visible")
	if coach == null or copy == null: return
	var bounds := Rect2(Vector2.ZERO, Vector2(size))
	var card_rect := coach.get_global_rect()
	check(bounds.encloses(card_rect), label + " coach within viewport")
	check(copy.size.y + 1.0 >= copy.get_combined_minimum_size().y, label + " coach text not clipped")
	for name in ["Seat0HoleCards", "CommunityCards", "PotDisplay", "ActionDock"]:
		var node: Control = scene.find_child(name, true, false)
		if node != null and node.is_visible_in_tree():
			check(not card_rect.intersects(node.get_global_rect()), label + " coach clears " + name)
	var overlay: Control = scene.find_child("TutorialOverlay", true, false)
	if overlay != null:
		var targets: Array[Control] = overlay._focus_targets()
		if scene.tutorial_controller.current_step().focus.has("best_five"):
			check(targets.size() >= 5, label + " five best cards highlighted")
		for target in targets:
			check(bounds.intersects(target.get_global_rect()), label + " focus target inside viewport")
	if language == "en":
		check(cjk.search(copy.text) == null, label + " English coach translated")
	if DisplayServer.get_name() != "headless" and (label.ends_with(".0") or label == "G3.initial" or label.ends_with(".raise") or scene.tutorial_controller.completed):
		root.get_texture().get_image().save_png(SHOT_DIR.path_join("%s_%d_%s.png" % [label, size.x, language]))

func _frames() -> void:
	await process_frame
	await process_frame
