extends SceneTree
const Profile := preload("res://scripts/game/local_profile.gd")
const Localization := preload("res://scripts/game/localization.gd")
var failures := 0
var main: Control
var seen := {}
var cjk := RegEx.new()
func _init() -> void: call_deferred("_run")
func _run() -> void:
	root.gui_embed_subwindows = true
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	cjk.compile("[一-龥]")
	var profile := Profile.default_profile()
	profile.settings.language = "en"
	profile.settings.music_volume = 0.0
	profile.settings.sound_enabled = false
	var path := OS.get_cache_dir().path_join("poker_language_%d.cfg" % Time.get_ticks_usec())
	Profile.save_profile(profile,path)
	main = load("res://scenes/main.tscn").instantiate()
	main.profile_path = path
	root.add_child(main)
	await frames()
	await inspect_page("menu")
	# Test the real settings selection callback inside an embedded panel. Native
	# popup focus is OS-managed, so keep its lifetime under the probe's control.
	var popup := PopupPanel.new()
	main.add_child(popup)
	popup.add_child(main._settings_panel(popup,false))
	check_text(popup,"settings")
	var options := popup.find_child("LanguageOptions",true,false) as OptionButton
	_assert(options != null,"language selection exists")
	options.item_selected.emit(1)
	await frames()
	_assert(TranslationServer.get_locale() == "zh_CN","settings selects Chinese")
	_assert(Profile.load_profile(path).settings.language == "zh_CN","language persists")
	if is_instance_valid(popup): popup.queue_free()
	Localization.apply_choice("en")
	main._show_menu(false)
	for id in PracticeStore.LESSONS:
		main.practice_views.open_lesson(id)
		var lesson: TutorialController = main.practice_views.tutorial
		var answers := {"T1":["hole_cards","community_cards","chips","pot","AS","KS","QS","JS","TS"],"T2":["straight_flush","a","tie"],"T3":[TableState.ACTION_CHECK,TableState.ACTION_CALL,TableState.ACTION_FOLD,TableState.ACTION_RAISE,TableState.ACTION_ALL_IN],"T4":[TableState.ACTION_CALL,TableState.ACTION_CHECK,TableState.ACTION_CHECK,TableState.ACTION_CHECK,"showdown"],"T5":["seat_3","button_small_blind","rotate"],"T6":["200","150","980","split"],"T7":[TableState.ACTION_FOLD,"refund"]}
		for answer in answers[id]:
			await inspect_page(id+"-"+str(lesson.step_index))
			main.practice_views.submit_lesson(answer)
		await inspect_page(id+"-complete")
		_assert(lesson.completed,id+" should complete")
	main.practice_views.tutorial_home()
	await inspect_page("tutorial-list")
	main._show_mode_config("practice")
	await inspect_page("config")
	main._show_menu(false)
	main._match_open = true
	main.game.start_new_match(5,"simple")
	main.paused = true
	main._render_table()
	await inspect_page("table")
	main.log_open = true
	main._render_table()
	await inspect_page("log")
	var before: PokerRound = main.game
	var state := var_to_str(main.game.players)
	popup = PopupPanel.new()
	main.add_child(popup)
	popup.add_child(main._settings_panel(popup,true))
	options = popup.find_child("LanguageOptions",true,false)
	options.item_selected.emit(1)
	await frames()
	_assert(main.game == before and var_to_str(main.game.players) == state and main.paused,"in-match language switch preserves round, stacks and pause")
	Localization.apply_choice("en")
	main.log_open = false
	var guard := 0
	while main.game.stage != "hand_over" and guard < 100:
		var legal: Dictionary = main.game.get_legal_actions(main.game.current_player_index)
		var action := TableState.ACTION_CHECK if legal.actions.has(TableState.ACTION_CHECK) else TableState.ACTION_CALL
		_assert(main.game.apply_action(action),"legal playthrough action")
		guard += 1
	main._render_table()
	await inspect_page("showdown")
	var record: Dictionary = main.game.completed_hand_record()
	main.practice_views.open_replay(record,true)
	for i in range(record.frames.size()):
		main.practice_views._seek(i)
		await inspect_page("replay-"+str(i))
	main._match_open = false
	main.practice_views.history()
	await inspect_page("history")
	main.practice_views.stats()
	await inspect_page("stats")
	check_string(Localization.present(PokerReference.rules_text()),"rules")
	check_string(PokerReference.hands_text(),"hand-reference")
	main.queue_free()
	await frames()
	DirAccess.remove_absolute(path)
	if failures == 0: print("Localization UI probes passed.")
	quit(failures)
func frames() -> void:
	await process_frame
	await process_frame
func inspect_page(label: String) -> void:
	await frames()
	check_text(main,label)
	if DisplayServer.get_name() != "headless" and label in ["menu","T1-0","T3-0","T6-0","table","showdown","stats"]:
		DirAccess.make_dir_recursive_absolute("/tmp/poker-language-screens")
		root.get_texture().get_image().save_png("/tmp/poker-language-screens/"+label+".png")
func check_text(node: Node,label: String) -> void:
	if node is Label or node is BaseButton:
		check_string(str(node.text),label)
	if node is OptionButton:
		for i in range(node.item_count): check_string(node.get_item_text(i),label)
	for child in node.get_children(): check_text(child,label)
func check_string(text: String,label: String) -> void:
	if text in ["Language / 语言","语言 / Language","System / 跟随系统","简体中文"]: return
	if cjk.search(text) != null and not seen.has(text):
		seen[text] = true
		_assert(false,label+" untranslated: "+text)
func _assert(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
