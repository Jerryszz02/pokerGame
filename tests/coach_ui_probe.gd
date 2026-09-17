extends SceneTree
var failures := 0
var evidence := ""
func _init() -> void: call_deferred("_run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func frames() -> void:
	await process_frame
	await process_frame
func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://export/ui/coach")
	DirAccess.make_dir_recursive_absolute(evidence)
	root.mode = Window.MODE_WINDOWED
	root.gui_embed_subwindows = true
	for viewport in [Vector2i(1280,720),Vector2i(1600,1000)]:
		for locale in ["zh_CN","en"]: await probe(viewport,locale)
	if failures == 0: print("Coach UI probes passed.")
	quit(failures)
func probe(viewport: Vector2i, locale: String) -> void:
	root.size = viewport
	var scene: Control = load("res://scenes/main.tscn").instantiate()
	var profile := LocalProfile.default_profile()
	profile.settings.language = locale
	profile.settings.sound_enabled = false
	profile.settings.music_volume = 0.0
	scene.profile_path = OS.get_cache_dir().path_join("coach-ui-%d.cfg" % Time.get_ticks_usec())
	LocalProfile.save_profile(profile,scene.profile_path)
	root.add_child(scene)
	await frames()
	scene._show_mode_config("practice")
	scene.ai_count_spin.value = 1
	scene.difficulty_options.select(3)
	scene.personality_options.select(MatchConfig.OPPONENT_PERSONALITIES.find("Rock"))
	scene._on_start_pressed()
	check(scene.game.difficulty == "hell" and scene.profile.settings.difficulty == "hell","Hell selector starts and persists Hell difficulty")
	check(scene.game.players[1].personality.name == "Rock","Hell respects the merged opponent style selector")
	scene.paused = true
	scene.practice_views.stats()
	await frames()
	var chart: RadarChart = scene.find_child("StyleRadarChart",true,false)
	check(chart != null and chart.style.dimensions.size() == 6,"actual stats page has six axes")
	check(chart.get_global_rect().end.y <= viewport.y,"radar is visible inside the small window")
	await capture("empty-%s-%dx%d" % [locale,viewport.x,viewport.y])
	scene._match_open = true
	scene.game.start_new_match(1,"simple",{"mode":"practice","show_hints":true})
	scene.paused = true
	scene._render_table()
	var context := CoachContext.capture(scene.game,0)
	var cancelled := CoachPanel.new()
	cancelled.open_live(scene,context)
	check(not scene.game._assistance_viewed,"loading does not mark assistance")
	cancelled.close()
	await frames()
	check(not scene.game._assistance_viewed,"closing loading advice never marks assistance")
	while is_instance_valid(cancelled): await process_frame
	var panel := CoachPanel.new()
	panel.open_live(scene,context)
	var deadline := Time.get_ticks_msec()+10000
	while panel.service.is_busy() and Time.get_ticks_msec()<deadline: await process_frame
	await frames()
	check(scene.game._assistance_viewed and panel.result_body.get_child_count() >= 3,"successful visible live numbers mark assistance")
	check(panel.get_theme_font("font","Label") == scene.UI_FONT,"coach popup uses bundled font")
	check(panel.size.x <= viewport.x and panel.size.y <= viewport.y,"live popup fits supported viewport")
	if locale == "en": check_english(panel)
	await capture("live-%s-%dx%d" % [locale,viewport.x,viewport.y])
	panel.close()
	while is_instance_valid(panel): await process_frame
	while scene.game.stage != TableState.STAGE_HAND_OVER:
		var legal: Dictionary = scene.game.get_legal_actions(scene.game.current_player_index)
		scene.game.apply_action(TableState.ACTION_CHECK if legal.actions.has(TableState.ACTION_CHECK) else TableState.ACTION_CALL)
	scene._render_table()
	var record: Dictionary = scene.game.completed_hand_record()
	scene.practice_views.open_replay(record,true)
	scene.practice_views._start_replay_analysis()
	deadline = Time.get_ticks_msec()+15000
	while not scene.practice_views._review_scope.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(scene.practice_views._review_scope.is_empty() and scene.practice_views._review_results.size() > 0,"actual replay completes asynchronous decision sequence")
	var saved: Array = scene.practice_views._review_results.duplicate(true)
	var stats_before: int = scene.practice_store.statistics().hands
	var analysis: Control = scene.find_child("ReplayAnalysisBody",true,false)
	check(analysis.get_child_count()>0,"replay shows actual versus alternative EV detail")
	scene.practice_views._seek(0)
	scene.practice_views.replay_all = true
	scene.practice_views._render_replay_frame()
	check(scene.practice_views._review_results == saved and analysis.get_child_count()>0,"seeking and omniscient view preserve isolated advice")
	scene.practice_views._start_replay_analysis()
	check(scene.practice_views._review_scope.is_empty(),"repeated analysis reuses bounded cached numerical results")
	check(scene.practice_store.statistics().hands == stats_before,"replay analysis never counts a hand twice")
	await frames()
	var scroll: ScrollContainer = scene.find_child("ReplayPanelScroll",true,false)
	scroll.ensure_control_visible(analysis)
	await frames()
	if locale == "en": check_english(scene)
	await capture("review-%s-%dx%d" % [locale,viewport.x,viewport.y])
	scene.practice_views._close_replay()
	deadline = Time.get_ticks_msec()+15000
	while (scene.coach_service.is_busy() or not scene._style_queue.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	check(scene.practice_store.statistics().style.raw.decisions > 0,"normal completed hand persists asynchronous radar counters")
	scene.practice_views.stats()
	await frames()
	await capture("stats-%s-%dx%d" % [locale,viewport.x,viewport.y])
	scene.queue_free()
	await frames()
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(name+".png")) == OK,"save actual rendered coach screenshot")

func check_english(node: Node) -> void:
	if node is Label or node is BaseButton:
		var regex := RegEx.new()
		regex.compile("[一-龥]")
		check(regex.search(node.text) == null,"English coach/replay has no untranslated Chinese: " + node.text)
	for child in node.get_children(): check_english(child)
