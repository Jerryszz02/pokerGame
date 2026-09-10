extends SceneTree

var failures := 0
var shot_dir := "/tmp/poker_practice_audit"
var run_id := str(Time.get_ticks_usec())

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	DirAccess.make_dir_recursive_absolute(shot_dir)
	for size in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
		await _probe(size)
	if failures == 0: print("Practice UI probes passed.")
	quit(failures)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _probe(viewport: Vector2i) -> void:
	root.size = viewport
	DisplayServer.window_set_size(viewport)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = OS.get_cache_dir().path_join("poker-practice-ui-%s-%d/profile.cfg" % [run_id,viewport.x])
	DirAccess.make_dir_recursive_absolute(scene.profile_path.get_base_dir())
	root.add_child(scene)
	scene.set_process(false)
	await _state(scene,viewport,"01_home")
	for name in ["HomeTutorialButton","HomeFreePlayButton","HomePracticeButton"]:
		check(scene.find_child(name,true,false) != null,"three primary mode entries")
	check(scene.practice_store.base_path == scene.profile_path + ".practice","all views share isolated profile namespace")
	scene.find_child("HomeFreePlayButton",true,false).emit_signal("pressed")
	await process_frame
	var stack: OptionButton = scene.find_child("InitialStackOptions",true,false)
	stack.select(2)
	stack.item_selected.emit(2)
	scene.ai_count_spin.value = 4
	scene.difficulty_options.select(1)
	scene.difficulty_options.item_selected.emit(1)
	var blinds: OptionButton = scene.find_child("BlindOptions",true,false)
	blinds.select(2)
	blinds.item_selected.emit(2)
	scene.find_child("ConfigCancelButton",true,false).emit_signal("pressed")
	check(scene.game.players.is_empty(),"cancel never opens a game")
	scene._show_mode_config("free")
	check(scene.ai_count_spin.value == 4 and scene.pending_match_config.initial_stack == 5000 and scene.pending_match_config.big_blind == 50,"cancel preserves all draft config")
	await _state(scene,viewport,"02_config")
	scene.find_child("ConfigStartButton",true,false).emit_signal("pressed")
	check(scene.game.initial_stack == 5000 and scene.game.total_pot() == 75 and scene.game.players.size() == 5,"visible config actually drives rules")
	check(scene.LocalProfileScript.load_profile(scene.profile_path).settings.initial_stack == 5000,"all options persist")
	await _state(scene,viewport,"03_table")
	var state_before: Array = scene.game.players.duplicate(true)
	scene._show_hand_reference()
	check(not scene._ai_can_advance(),"hand reference freezes AI")
	scene._process(100)
	check(scene.game.players == state_before,"visible reference doesn't advance")
	await _state(scene,viewport,"04_hand_reference")
	var popup: PopupPanel = scene.find_child("HandReferencePopup",true,false)
	popup.hide()
	await process_frame
	check(scene._ai_can_advance(),"closing reference restores live table")
	# Complete the actual hand, then re-render twice to test one-time storage.
	_passive(scene.game)
	scene._render_table()
	var record: Dictionary = scene.game.completed_hand_record()
	var count: int = scene.practice_store.statistics().hands
	scene._render_table()
	check(count == 1 and scene.practice_store.statistics().hands == count,"render doesn't double count")
	var original: Array = scene.game.players.duplicate(true)
	scene.find_child("ReplayCurrentHandButton",true,false).emit_signal("pressed")
	await _state(scene,viewport,"05_replay")
	check(not scene._ai_can_advance(),"replay blocks live progression")
	var views: PracticeViews = scene.practice_views
	check(views.replay.frames[views.replay_index].community_cards.is_empty(),"initial replay doesn't reveal future board")
	check(not scene.practice_store.state.achievements.has("replay_first"),"opening replay alone is not full traversal")
	views._seek(record.frames.size()-1)
	check(not scene.practice_store.state.achievements.has("replay_first"),"jumping directly to end isn't full traversal")
	for i in range(record.frames.size()): views._seek(i)
	check(scene.practice_store.state.achievements.has("replay_first"),"actual complete traversal saves achievement")
	check(scene.game.players == original and scene.practice_store.statistics().hands == count,"replay doesn't mutate game or stats")
	views._seek(0)
	var toggle: CheckBox = scene.find_child("ReplayOmniscientToggle",true,false)
	toggle.button_pressed = true
	check(views.replay_all,"omniscient toggle works on ended record")
	views.replay_playing = true
	views.tick(1.0)
	check(views.replay_index == 1,"autoplay advances actual frame")
	scene.find_child("ReplayCloseButton",true,false).emit_signal("pressed")
	check(scene._in_match() and scene.game.players == original,"replay closes back to the actual hand")
	scene._show_menu()
	scene._show_history_view()
	await _state(scene,viewport,"06_history")
	check(scene.find_child("ReplayRecord_"+record.id,true,false) != null,"record list includes real hand")
	scene._show_stats_view()
	await _state(scene,viewport,"07_stats")
	var filter: OptionButton = scene.find_child("StatsFilter_mode",true,false)
	filter.select(2)
	filter.item_selected.emit(2)
	check(scene.practice_store.statistics(views.filters).hands == 0,"stats filters use source metadata")
	# Complete a lesson by operating every visible choice, not controller-only calls.
	scene._show_tutorial_home()
	scene.find_child("Lesson_T1",true,false).emit_signal("pressed")
	await _state(scene,viewport,"08_tutorial")
	for choice in ["hole_cards","community_cards","chips","pot","AS","KS","QS","JS","TS"]:
		var button: Button = scene.find_child("TutorialChoice_"+choice,true,false)
		check(button != null,"tutorial exposes expected actual option")
		if button != null: button.emit_signal("pressed")
	check(scene.tutorial_controller.completed and scene.practice_store.state.tutorial_completed.has("T1"),"UI lesson completion persists")
	check(scene.practice_store.statistics().hands == count,"tutorial doesn't change normal stats")
	await _state(scene,viewport,"09_tutorial_complete")
	scene.find_child("TutorialRestartButton",true,false).emit_signal("pressed")
	check(not scene.tutorial_controller.completed,"completed lesson can restart")
	var reopened := PracticeStore.new(scene.practice_store.base_path)
	check(reopened.state.tutorial_completed.has("T1") and reopened.records().size() == 1,"progress and hand survive reload in same namespace")
	scene._show_menu()
	scene._show_mode_config("practice")
	scene.pending_match_config.pause_each_hand = false
	scene.pending_match_config.show_hints = true
	scene.ai_count_spin.value = 1
	scene._on_start_pressed()
	_passive(scene.game)
	scene._render_table()
	var hand: int = scene.game.hand_number
	scene._show_analysis_unavailable()
	check(not scene._ai_can_advance(),"unavailable coach panel freezes progression")
	scene._process(100)
	check(scene.game.hand_number == hand,"auto-next waits for coach panel")
	await _state(scene,viewport,"10_coach_unavailable")
	scene.find_child("AnalysisUnavailablePanel",true,false).hide()
	await process_frame
	scene._process(3.1)
	check(scene.game.hand_number == hand+1,"practice auto-next works after overlay closes")
	check(not scene.game._assistance_viewed,"unavailable coach isn't recorded as actual assistance")
	scene.queue_free()
	await process_frame
	await process_frame

func _passive(game: PokerRound) -> void:
	for i in range(300):
		if game.stage == TableState.STAGE_HAND_OVER: return
		var legal := game.get_legal_actions(game.current_player_index)
		check(game.apply_action("check" if legal.actions.has("check") else "call"),"legal passive action")
	check(false,"hand reaches settlement")

func _state(scene: Control, viewport: Vector2i, tag: String) -> void:
	await process_frame
	await process_frame
	_bounds(scene,Rect2(Vector2.ZERO,scene.size))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		shot.save_png(shot_dir.path_join("%d_%s.png" % [viewport.x,tag]))

func _bounds(node: Node, frame: Rect2) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		check(frame.grow(2).encloses(rect),"visible control fits viewport: "+str(node.name))
		if node is Button:
			var style: StyleBox = node.get_theme_stylebox("normal")
			var font: Font = node.get_theme_font("font")
			var width: float = font.get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size")).x
			check(width <= node.size.x-style.get_content_margin(SIDE_LEFT)-style.get_content_margin(SIDE_RIGHT)+2,"button text fits: "+node.text)
		if node is ScrollContainer: return # Clipped scroll content may extend offscreen.
	if node is Window and not node.visible: return
	for child in node.get_children(): _bounds(child,frame)
