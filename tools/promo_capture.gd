extends SceneTree
## Genuine rendered footage. Only visible UI signals drive play; AI remains live.
var output_dir := OS.get_cache_dir().path_join("poker-promo-capture")
var scene: Node
var lang := "en"
var mode := "practice"
var frame := 0
var log_file: FileAccess
var last_event_count := 0
var tag := ""
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="): lang = arg.trim_prefix("--lang=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--output="): output_dir = arg.trim_prefix("--output=")
	call_deferred("_run")
func _process(_delta: float) -> bool:
	frame += 1
	if scene != null and scene.game != null:
		var events: Array = scene.game.event_log
		while last_event_count < events.size():
			_log("game_event", {"event": events[last_event_count], "stage": scene.game.stage})
			last_event_count += 1
	return false
func _run() -> void:
	tag = ("config-pickup-" + lang) if mode == "config" else (("hard-ai-" + lang) if mode == "hard" else ("zh-replay-pickup" if mode == "replay" else lang + "-" + mode + "-take02"))
	DirAccess.make_dir_recursive_absolute(output_dir)
	log_file = FileAccess.open(output_dir.path_join(tag + "-timeline.jsonl"), FileAccess.WRITE)
	root.mode = Window.MODE_WINDOWED
	root.gui_embed_subwindows = true
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1920,1080)
	DisplayServer.window_set_size(Vector2i(1920,1080))
	scene = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = OS.get_cache_dir().path_join("poker-promo-v140-" + tag + "-" + str(OS.get_process_id()) + ".cfg")
	scene.deepseek_review.service_url = ""
	var profile: Dictionary = LocalProfile.load_profile(scene.profile_path)
	profile.settings.language = "zh_CN" if lang == "zh" else "en"
	profile.settings.sound_enabled = true
	profile.settings.music_volume = 0.0
	profile.settings.fast_mode = false
	LocalProfile.save_profile(profile, scene.profile_path)
	root.add_child(scene)
	scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	_log("isolation", {"profile": scene.profile_path, "practice": scene.profile_path + ".practice", "service_url": scene.deepseek_review.service_url, "viewport": str(root.size), "language": profile.settings.language})
	await hold(3)
	await screenshot("home")
	if mode == "test":
		await hold(2)
	elif mode == "config":
		await config_pickup()
	elif mode == "replay":
		await replay_pickup()
	elif mode == "hard":
		await hard_ai()
	elif mode == "tutorial":
		await press("HomeTutorialButton")
		await tutorial()
	else:
		await practice()
	_log("capture_complete")
	log_file.close()
	quit()
func hold(seconds: float) -> void:
	for i in range(roundi(seconds * 30)):
		await process_frame
func _log(event: String, data: Dictionary = {}) -> void:
	data = data.duplicate(true)
	data.merge({"event_type": event, "frame": frame, "seconds": frame / 30.0, "language": lang, "mode": mode})
	if log_file != null:
		log_file.store_line(JSON.stringify(data))
		log_file.flush()
	print("PROMO ", JSON.stringify(data))
func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(tag + "-" + name + ".png"))
func press(name: String) -> void:
	var button := scene.find_child(name, true, false) as BaseButton
	if button == null or button.disabled:
		_log("missing_button", {"name":name})
		return
	_log("ui_press", {"name":name, "text": button.text, "button_rect": [button.global_position.x,button.global_position.y,button.size.x,button.size.y], "design_size":[1280,720]})
	button.pressed.emit()
	await hold(0.25)
func practice() -> void:
	await press("HomePracticeButton")
	await hold(2)
	scene.ai_count_spin.value = 2
	_log("ui_config_ai_count", {"value":2})
	await hold(2)
	scene.difficulty_options.select(1)
	scene.difficulty_options.item_selected.emit(1)
	_log("ui_config_difficulty", {"value":"medium"})
	await hold(4)
	await screenshot("config")
	await press("ConfigStartButton")
	var budget := 30 * 200
	var human_since := -1
	while scene.game.stage != TableState.STAGE_HAND_OVER and budget > 0:
		await process_frame
		budget -= 1
		if scene.game.is_human_turn():
			if human_since < 0:
				human_since = frame
				_log("human_turn_available", {"stage":scene.game.stage,"legal":scene.game.get_legal_actions(0)})
			if frame - human_since < 90: continue
			var legal: Dictionary = scene.game.get_legal_actions(0)
			var action := "check" if legal.actions.has("check") else "call"
			await screenshot("before-action-" + str(frame))
			await press("Action_" + action)
			human_since = -1
		else:
			human_since = -1
	await screenshot("result")
	_log("hand_result", {"record":scene.game.completed_hand_record()})
	var record: Dictionary = scene.game.completed_hand_record()
	var record_file := FileAccess.open(output_dir.path_join(tag + "-hand-record.json"), FileAccess.WRITE)
	record_file.store_string(JSON.stringify(record, "\t"))
	record_file.close()
	await hold(4)
	await press("ReplayCurrentHandButton")
	await hold(3)
	await screenshot("replay-start")
	if lang == "zh":
		var toggle := scene.find_child("ReplayOmniscientToggle",true,false) as CheckBox
		toggle.button_pressed = true
		_log("ui_omniscient", {"ended_hand_id": record.get("id", "")})
		await hold(3)
	for i in range(1, record.get("frames", []).size()):
		await press("ReplayNext")
		_log("replay_seek", {"source_index":i,"hand_id":record.get("id", ""),"source_frame":record.frames[i]})
		await hold(1.5)
	await screenshot("replay-end")
	await hold(3)
	await press("ReplayCloseButton")
	await hold(2)
	var next_button := find_text(scene, "下一手" if lang == "zh" else "Next hand")
	if next_button != null:
		_log("ui_next_hand", {"previous_hand_id":record.get("id", "")})
		next_button.pressed.emit()
		await hold(4)
		await screenshot("next-hand")
	else:
		var restart := find_text(scene, "重新开始" if lang == "zh" else "Restart")
		if restart != null:
			_log("ui_new_table_after_match", {"previous_hand_id":record.get("id", "")})
			restart.pressed.emit()
			await hold(2)
			if scene.find_child("ConfirmLeaveButton",true,false) != null: await press("ConfirmLeaveButton")
			await press("HomePracticeButton")
			await hold(2)
			await press("ConfigStartButton")
			last_event_count = 0
			await hold(4)
			await screenshot("new-table")
func tutorial() -> void:
	var budget := 30 * 130
	var previous_step := ""
	while not scene.tutorial_controller.completed and budget > 0:
		var step: Dictionary = scene.tutorial_controller.current_step()
		if str(step.id) != previous_step:
			_log("tutorial_step", {"step":step})
			previous_step = str(step.id)
			await hold(4)
			await screenshot("tutorial-" + previous_step)
		var cont := scene.find_child("TutorialContinueButton",true,false)
		if cont != null:
			await press("TutorialContinueButton")
		else:
			for action in ["call", "check"]:
				var button := scene.find_child("Action_"+action,true,false) as Button
				if button != null and not button.disabled:
					await press("Action_"+action)
					break
		await hold(0.2)
		budget -= 6
	await hold(5)
	_log("tutorial_result", {"completed":scene.tutorial_controller.completed,"record":scene.game.completed_hand_record()})
	var record_file := FileAccess.open(output_dir.path_join(tag + "-hand-record.json"), FileAccess.WRITE)
	record_file.store_string(JSON.stringify(scene.game.completed_hand_record(), "\t"))
	record_file.close()
	await screenshot("tutorial-result")
func find_text(node: Node, value: String) -> Button:
	if node is Button and value.to_lower() in node.text.to_lower(): return node
	for child in node.get_children():
		var found := find_text(child,value)
		if found != null: return found
	return null

func replay_pickup() -> void:
	var record: Dictionary = scene.practice_store._read_json(output_dir.path_join("zh-practice-take02-hand-record.json"))
	_log("pickup_same_record", {"hand_id":record.id,"record_source":"zh-practice-take02-hand-record.json"})
	scene._show_replay_view(record)
	await hold(1)
	await press("ReplayStage_flop")
	_log("player_view_start", {"hand_id":record.id,"index":scene.practice_views.replay_index})
	await hold(7)
	await press("ReplayNext")
	await hold(7)
	await screenshot("player-view")
	var toggle := scene.find_child("ReplayOmniscientToggle",true,false) as CheckBox
	_log("ui_omniscient", {"hand_id":record.id,"button_rect":[toggle.global_position.x,toggle.global_position.y,toggle.size.x,toggle.size.y]})
	toggle.button_pressed = true
	await hold(8)
	await screenshot("omniscient-view")
func hard_ai() -> void:
	await press("HomePracticeButton")
	scene.ai_count_spin.value = 3
	scene.difficulty_options.select(2)
	scene.difficulty_options.item_selected.emit(2)
	_log("hard_config", {"difficulty":"hard","ai_count":3})
	await hold(3)
	await screenshot("hard-config")
	await press("ConfigStartButton")
	var end_frame := frame + 30 * 20
	var human_since := -1
	while frame < end_frame and scene.game.stage != TableState.STAGE_HAND_OVER:
		await process_frame
		if scene.game.is_human_turn():
			if human_since < 0:
				human_since = frame
				_log("human_turn_available", {"stage":scene.game.stage})
			if frame-human_since >= 90:
				var legal: Dictionary = scene.game.get_legal_actions(0)
				await screenshot("before-action-"+str(frame))
				await press("Action_" + ("check" if legal.actions.has("check") else "call"))
				human_since = -1
		else: human_since = -1
	await hold(3)
	await screenshot("hard-table")

func config_pickup() -> void:
	await press("HomePracticeButton")
	scene.ai_count_spin.value = 2
	scene.difficulty_options.select(1)
	scene.difficulty_options.item_selected.emit(1)
	_log("config_upper_visible", {"ai_count":2,"difficulty":"medium"})
	await hold(3)
	await screenshot("upper")
	var start := scene.find_child("ConfigStartButton",true,false) as Button
	var ancestor: Node = start.get_parent()
	while not ancestor is ScrollContainer: ancestor = ancestor.get_parent()
	var scroll := ancestor as ScrollContainer
	var bar := scroll.get_v_scroll_bar()
	var maximum := bar.max_value - bar.page
	_log("ui_scroll_start", {"from":bar.value,"to":maximum,"method":"real ScrollContainer vertical scrollbar value; automated UI scroll"})
	var initial := bar.value
	for i in range(30):
		bar.value = lerpf(initial,maximum,(i+1)/30.0)
		await process_frame
	await hold(0.5)
	var pause := scene.find_child("PauseEachHandToggle",true,false) as CheckBox
	var viewport_rect := scroll.get_global_rect()
	var start_rect := start.get_global_rect()
	var pause_rect := pause.get_global_rect()
	var all_visible := viewport_rect.encloses(start_rect) and viewport_rect.encloses(pause_rect)
	_log("config_lower_visible", {"start_rect":[start_rect.position.x,start_rect.position.y,start_rect.size.x,start_rect.size.y],"pause_rect":[pause_rect.position.x,pause_rect.position.y,pause_rect.size.x,pause_rect.size.y],"scroll_rect":[viewport_rect.position.x,viewport_rect.position.y,viewport_rect.size.x,viewport_rect.size.y],"fully_visible":all_visible,"pause_enabled":pause.button_pressed})
	assert(all_visible,"Config Start and Pause must be entirely inside real scroll viewport")
	await screenshot("lower")
	await hold(3)
	await press("ConfigStartButton")
	_log("config_table_entered", {"config":scene.game.match_config,"hand_number":scene.game.hand_number})
	await hold(3)
	await screenshot("table")
