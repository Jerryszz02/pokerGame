extends SceneTree
## Simulates a player clicking through the whole game (menu, settings, hands,
## result, restart) while capturing screenshots to /tmp/poker_audit/ and
## asserting the machine-checkable UI acceptance metrics from
## docs/planning/ui-acceptance.md (M1-M8). Run windowed, not headless:
##   Godot --path . -s tests/ui_playthrough_probe.gd

var failures := 0
var shot_dir := "/tmp/poker_audit"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	DirAccess.make_dir_recursive_absolute(shot_dir)
	for viewport_size in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		await _playthrough(viewport_size)
	if failures == 0:
		print("UI playthrough probe passed.")
	else:
		push_error("%d UI playthrough probe assertions failed." % failures)
	quit(failures)

func _playthrough(viewport_size: Vector2i) -> void:
	DisplayServer.window_set_size(viewport_size)
	root.size = viewport_size
	await process_frame
	# The OS window needs focus for popups to stay open; wait for it.
	for i in range(600):
		if root.get_window().has_focus():
			break
		await process_frame
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = "user://poker_ui_playthrough_probe.cfg"
	# Pin legacy Chinese-copy fixtures; localization_ui_probe covers English.
	var language_fixture := LocalProfile.load_profile(scene.profile_path)
	language_fixture.settings.language = "zh_CN"
	LocalProfile.save_profile(language_fixture, scene.profile_path)
	root.add_child(scene)
	scene.set_process(false)
	scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene.ai_pending = true # the probe drives AI turns itself, without UI delays
	await process_frame
	await process_frame
	var tag := "%dx%d" % [viewport_size.x, viewport_size.y]

	await _state(scene, tag + "_01_menu")
	scene._show_help()
	await process_frame
	await process_frame
	await _state(scene, tag + "_01b_help")
	var help_popup: PopupPanel = scene.find_child("HelpPopup", true, false)
	_assert(help_popup != null, "menu exposes rules and exit semantics")
	if help_popup != null:
		help_popup.hide()
	await process_frame

	var settings_button := _find_button_with_text(scene, "设置")
	_assert(settings_button != null, "%s menu should expose a settings button" % tag)
	if settings_button != null:
		var popup: PopupPanel = null
		for attempt in range(3):
			settings_button.emit_signal("pressed")
			popup = await _wait_for_popup(scene)
			if popup != null:
				break
		_assert(popup != null, "%s settings popup should open from menu" % tag)
		await process_frame
		# Exercise the visible settings through their actual signals and save path.
		scene.sound_toggle.button_pressed = false
		scene.sound_player.stop()
		scene._play_sound(300.0, 0.02)
		_assert(not scene.sound_player.playing, "disabled sound does not start the generator")
		scene.sound_toggle.button_pressed = true
		scene._play_sound(300.0, 0.02)
		_assert(scene.sound_player.playing, "enabled sound starts the generator")
		scene.pace_toggle.button_pressed = true
		_assert(scene._ai_action_delay({"difficulty": "simple"}) < 1.0, "fast setting changes actual scheduled delay")
		var saved: Dictionary = scene.LocalProfileScript.load_profile(scene.profile_path)
		_assert(saved.settings.sound_enabled and saved.settings.fast_mode, "visible settings persist together")
		scene.pace_toggle.button_pressed = false
		_assert(scene._ai_action_delay({"difficulty": "simple"}) >= 3.0, "normal setting restores normal delay")
		await _state(scene, tag + "_02_settings")
		var reset_button := _find_button_with_text(popup, "重置历史汇总") if popup != null else null
		_assert(reset_button != null, "%s settings popup should expose reset stats button" % tag)
		_assert(_find_button_with_text(popup, "暂停游戏") == null, "%s menu settings popup should not expose a pause button" % tag)
		if reset_button != null:
			reset_button.emit_signal("pressed")
			await process_frame
			await process_frame
			await _state(scene, tag + "_03_settings_reset_confirm")
			var confirm_button := _find_button_with_text(popup, "再次点击确认")
			if confirm_button != null:
				confirm_button.emit_signal("pressed")
				await process_frame
		var close_button := _find_button_with_text(popup, "关闭") if popup != null else null
		if close_button != null:
			close_button.emit_signal("pressed")
			await process_frame
			await process_frame

	scene._show_mode_config("free")
	await process_frame
	await process_frame
	await _state(scene, tag + "_03a_config")
	scene.ai_count_spin.value = 5
	scene.difficulty_options.select(2)
	var start_button := scene.find_child("ConfigStartButton", true, false) as Button
	_assert(start_button != null, "%s menu should expose a start button" % tag)
	if start_button == null:
		scene.queue_free()
		await process_frame
		return
	start_button.emit_signal("pressed")
	await process_frame
	await process_frame
	var log_button := scene.find_child("LogButton", true, false) as Button
	_assert(log_button != null, "%s table should expose the log drawer button" % tag)
	if log_button != null:
		log_button.emit_signal("pressed")
		await process_frame
		await process_frame
		_assert(scene.find_child("LogDrawer", true, false) != null, "%s log drawer should open over the table" % tag)
		_assert(not scene._ai_can_advance(), "%s open log drawer should pause AI" % tag)
		await _state(scene, tag + "_03b_log_drawer")
		var close_log := scene.find_child("LogCloseButton", true, false) as Button
		if close_log != null:
			close_log.emit_signal("pressed")
			await process_frame
			await process_frame

	var table_settings := scene.find_child("SettingsButton", true, false) as Button
	_assert(table_settings != null, "%s table should expose a settings button" % tag)
	if table_settings != null:
		table_settings.emit_signal("pressed")
		var table_popup := await _wait_for_popup(scene)
		_assert(table_popup != null, "%s settings popup should open from the table" % tag)
		var pause_button := _find_button_with_text(table_popup, "暂停游戏") if table_popup != null else null
		_assert(pause_button != null, "%s in-match settings popup should expose a pause button" % tag)
		if pause_button != null:
			pause_button.emit_signal("pressed")
			await process_frame
			await process_frame
			_assert(scene.paused, "%s pause button should pause the match" % tag)
			_assert(not scene._ai_can_advance(), "%s paused match should block AI advancement" % tag)
			_assert(scene.find_child("PauseOverlay", true, false) != null, "%s paused match should show the pause overlay" % tag)
			await _state(scene, tag + "_03c_paused")
			var resume_button := scene.find_child("PauseResumeButton", true, false) as Button
			_assert(resume_button != null, "%s pause overlay should expose a resume button" % tag)
			if resume_button != null:
				resume_button.emit_signal("pressed")
				await process_frame
				await process_frame
				_assert(not scene.paused, "%s resume button should unpause the match" % tag)
				_assert(scene._ai_can_advance(), "%s resumed match should allow AI advancement" % tag)

	await _drive_hand(scene, tag, 60, "safe")
	await _state(scene, tag + "_09_result")

	var next_button := _find_button_with_text(scene, "下一手")
	if next_button != null:
		next_button.emit_signal("pressed")
		await process_frame
		await process_frame
		await _drive_hand(scene, tag + "_hand2", 60, "yolo")
		await _state(scene, tag + "_hand2_result")

	var restart_button := _find_button_with_text(scene, "重新开始")
	if restart_button != null:
		restart_button.emit_signal("pressed")
		await process_frame
		var leave_confirm: Button = scene.find_child("ConfirmLeaveButton",true,false)
		if leave_confirm != null:
			leave_confirm.emit_signal("pressed")
		await process_frame
		await process_frame
		await _state(scene, tag + "_10_menu_again")

	# Regression: quitting to the menu mid-AI-turn must stop the abandoned
	# match from scheduling or completing AI turns (PR #3 review).
	var menu_start := scene.find_child("HomeFreePlayButton", true, false) as Button
	if menu_start != null:
		menu_start.emit_signal("pressed")
		await process_frame
		var config_start := scene.find_child("ConfigStartButton", true, false) as Button
		_assert(config_start != null, "free mode opens configuration before starting")
		if config_start != null:
			config_start.emit_signal("pressed")
		await process_frame
		await process_frame
		scene.game.current_player_index = 1 # force an AI turn before quitting
		scene._render_table()
		await process_frame
		var quit_settings := scene.find_child("SettingsButton", true, false) as Button
		if quit_settings != null:
			quit_settings.emit_signal("pressed")
			var quit_popup := await _wait_for_popup(scene)
			var quit_pause := _find_button_with_text(quit_popup, "暂停游戏") if quit_popup != null else null
			if quit_pause != null:
				quit_pause.emit_signal("pressed")
				await process_frame
				await process_frame
				var quit_button := scene.find_child("PauseQuitButton", true, false) as Button
				_assert(quit_button != null, "%s pause overlay should expose a quit-to-menu button" % tag)
				if quit_button != null:
					quit_button.emit_signal("pressed")
					await process_frame
					await process_frame
					await _state(scene, tag + "_10b_leave_confirm")
					var confirm_leave: Button = scene.find_child("ConfirmLeaveButton", true, false)
					_assert(confirm_leave != null, "leaving an unfinished match needs clear confirmation")
					if confirm_leave != null:
						confirm_leave.emit_signal("pressed")
					await process_frame
					await process_frame
					_assert(scene.find_child("HomeFreePlayButton", true, false) != null, "%s quit-to-menu should return to the menu" % tag)
					_assert(not scene.paused, "%s quit-to-menu should clear the paused state" % tag)
					_assert(not scene._ai_can_advance(), "%s menu after quitting mid-AI-turn should block AI advancement" % tag)
					_assert(not scene._execute_ai_turn_if_allowed(), "%s a pending AI callback should stop after quitting to the menu" % tag)
					await _state(scene, tag + "_11_menu_after_quit")

	# Deterministic multiway human bust: the result must remain readable.
	scene.game.start_new_match(5, "simple")
	scene.game.players[0].stack = 0
	scene.game._finish_hand()
	scene.game.stage = TableState.STAGE_HAND_OVER
	scene._render_table()
	await process_frame
	await process_frame
	_assert(scene.game.match_over, "multiway bust must show a match result")
	_assert(_find_button_with_text(scene, "下一手") == null, "busted human cannot start another hand")
	await _state(scene, tag + "_12_bust_summary")
	scene.game.start_new_match(5, "simple")
	for player in scene.game.players:
		player.stack = 0
		player.current_bet = 0
		player.total_bet = 0
	scene.game.players[0].stack = TableState.INITIAL_STACK * 6
	scene.game.start_next_hand()
	scene._render_table()
	await process_frame
	await process_frame
	_assert(scene.game.match_result == "你赢得牌局", "human owning all chips reaches the victory summary")
	_assert(_find_button_with_text(scene, "下一手") == null, "completed match does not offer another hand")
	var restart := _find_button_with_text(scene, "重新开始")
	_assert(restart != null, "victory summary offers a restart")
	await _state(scene, tag + "_13_win_summary")
	if restart != null:
		restart.emit_signal("pressed")
		await process_frame
		_assert(scene.find_child("HomeFreePlayButton", true, false) != null, "victory restart returns to the menu")
	var original_profile_path: String = scene.profile_path
	scene.profile_path = "user://missing-ui-save-probe-parent/profile.cfg"
	scene._save_profile()
	await process_frame
	await process_frame
	_assert(scene.find_child("SaveErrorPopup", true, false) != null, "save failure is visible to the player")
	await _state(scene, tag + "_14_save_error")
	scene.profile_path = original_profile_path

	if scene.sound_player:
		scene.sound_player.stop()
	scene.queue_free()
	await process_frame
	await process_frame

func _drive_hand(scene: Node, tag: String, max_actions: int = 60, style: String = "safe") -> void:
	var human_turns := 0
	var iterations := 0
	var last_stage := ""
	await _state(scene, "%s_04_%s" % [tag, scene.game.stage])
	while str(scene.game.stage) != TableState.STAGE_HAND_OVER and iterations < max_actions:
		iterations += 1
		if scene.game.is_ai_turn():
			var idx: int = scene.game.current_player_index
			var decision: Dictionary = AiDecision.decide(scene.game, idx)
			scene.game.apply_action(decision.action_type, int(decision.get("amount", 0)), str(decision.get("decision_label", "")))
			scene._render_table()
			await process_frame
			if str(scene.game.stage) != last_stage:
				last_stage = str(scene.game.stage)
				await _state(scene, "%s_06_%s" % [tag, last_stage])
			else:
				_audit(scene, "%s_ai%d" % [tag, iterations])
			continue
		human_turns += 1
		await _state(scene, "%s_05_human%d_%s" % [tag, human_turns, scene.game.stage])
		if human_turns == 1 and scene.game.get_legal_actions(0).actions.has(TableState.ACTION_RAISE):
			scene.raise_expanded = true
			scene._render_table()
			await process_frame
			await process_frame
			await _state(scene, "%s_05b_raise_expanded" % tag)
		_act_human(scene, human_turns, style)
		await process_frame
		await process_frame
	scene._render_table()
	await process_frame
	await process_frame

func _act_human(scene: Node, human_turns: int, style: String) -> void:
	var legal: Dictionary = scene.game.get_legal_actions(0)
	var actions: Array = legal.actions
	# First turn exercises the raise slider row; "yolo" hands go all-in right
	# after to reach showdown, "safe" hands stay alive for next-hand coverage.
	if human_turns == 1 and style == "yolo" and actions.has(TableState.ACTION_ALL_IN):
		var all_in_button := _find_button_with_text(scene, "全下")
		if all_in_button != null:
			all_in_button.emit_signal("pressed")
			return
	if human_turns == 1 and actions.has(TableState.ACTION_RAISE):
		if scene.raise_slider:
			scene.raise_slider.value = scene.raise_slider.min_value
		var raise_button := _find_button_with_prefix(scene, "加注到")
		if raise_button != null:
			raise_button.emit_signal("pressed")
			return
	var to_call := int(scene.game.get_to_call(0))
	for candidate in [[TableState.ACTION_CHECK, "让牌"], [TableState.ACTION_CALL, "跟注"]]:
		if actions.has(candidate[0]) and (style != "safe" or to_call <= 150):
			var button := _find_button_with_prefix(scene, candidate[1])
			if button != null:
				button.emit_signal("pressed")
				return
			scene._on_action(candidate[0], 0)
			return
	if actions.has(TableState.ACTION_FOLD):
		var fold_button := _find_button_with_text(scene, "弃牌")
		if fold_button != null:
			fold_button.emit_signal("pressed")
		else:
			scene._on_action(TableState.ACTION_FOLD, 0)

# --- Machine checks (M1-M8) -------------------------------------------------

func _state(scene: Node, label: String) -> void:
	_audit(scene, label)
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png("%s/%s.png" % [shot_dir, label])
	_assert(error == OK, "%s screenshot should save" % label)

func _audit(scene: Node, label: String) -> void:
	var scope: Node = scene
	var popup := _find_visible_popup(scene)
	if popup != null:
		scope = popup
	var frame := Rect2(Vector2.ZERO, scene.size)
	_assert(_controls_fit(scene, frame), "%s visible controls should stay inside viewport" % label)
	if popup != null:
		_assert(_controls_fit(popup, frame), "%s settings popup should stay inside viewport" % label)
	_text_fits(scope, label)
	_panel_content_inside_frame(scope, label)
	_interactive_no_overlap(scope, label)
	_layering_whitelist(scope, label)
	_texture_filter_nearest(scope, label)

func _controls_fit(node: Node, frame: Rect2) -> bool:
	if node is Control and node.visible:
		var rect: Rect2 = node.get_global_rect()
		if rect.size.x > 1.0 and rect.size.y > 1.0:
			var min_ok := rect.position.x >= -1.0 and rect.position.y >= -1.0
			var max_ok := rect.end.x <= frame.size.x + 1.0 and rect.end.y <= frame.size.y + 1.0
			if not min_ok or not max_ok:
				push_error("%s out of bounds: %s in %s" % [node.name, rect, frame])
				return false
	for child in node.get_children():
		if not _controls_fit(child, frame):
			return false
	return true

func _text_fits(node: Node, context: String) -> void:
	if node is Label and node.visible:
		var label := node as Label
		if label.clip_text and label.autowrap_mode == TextServer.AUTOWRAP_OFF and not label.text.is_empty():
			var font := label.get_theme_font("font")
			var font_size := label.get_theme_font_size("font_size")
			var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			_assert(width <= label.size.x + 1.0, "%s label '%s' gets clipped (text %.1fpx > box %.1fpx)" % [context, label.text, width, label.size.x])
	if node is Button and node.visible:
		var button := node as Button
		if not button.text.is_empty():
			var font := button.get_theme_font("font")
			var font_size := button.get_theme_font_size("font_size")
			var width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var available := button.size.x
			var style := button.get_theme_stylebox("normal")
			if style != null:
				available -= style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)
			_assert(width <= available + 1.0, "%s button text '%s' overflows (text %.1fpx > content %.1fpx)" % [context, button.text, width, available])
	for child in node.get_children():
		_text_fits(child, context)

func _panel_content_inside_frame(node: Node, context: String) -> void:
	if node is PanelContainer and node.visible:
		var style := (node as PanelContainer).get_theme_stylebox("panel") as StyleBoxTexture
		if style != null:
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				var content := style.get_content_margin(side)
				var border := style.get_texture_margin(side)
				_assert(content >= border - 0.5, "%s panel %s content margin %.1f should clear the %d-texture border %.1f" % [context, node.name, content, side, border])
	for child in node.get_children():
		_panel_content_inside_frame(child, context)

func _interactive_no_overlap(node: Node, context: String) -> void:
	var controls: Array = []
	_collect_interactive(node, controls)
	for i in range(controls.size()):
		for j in range(i + 1, controls.size()):
			var overlap: Rect2 = (controls[i] as Control).get_global_rect().intersection((controls[j] as Control).get_global_rect())
			_assert(overlap.size.x <= 1.0 or overlap.size.y <= 1.0, "%s interactive controls %s and %s overlap" % [context, (controls[i] as Control).name, (controls[j] as Control).name])

func _collect_interactive(node: Node, out: Array) -> void:
	if node is Control and node.visible and (node is Button or node is Slider):
		# SpinBox/OptionButton internals are not separate player controls.
		if not (node.get_parent() is SpinBox):
			out.append(node)
	for child in node.get_children():
		_collect_interactive(child, out)

func _layering_whitelist(node: Node, context: String) -> void:
	var bets: Array = []
	var hole_cards: Array = []
	for seat in range(8):
		var bet := node.find_child("Seat%dBet" % seat, true, false) as Control
		if bet != null and bet.visible:
			bets.append(bet)
		var cards := node.find_child("Seat%dHoleCards" % seat, true, false) as Control
		if cards != null and cards.visible:
			hole_cards.append(cards)
	if bets.is_empty() and hole_cards.is_empty():
		return
	var community := node.find_child("CommunityCards", true, false) as Control
	var pot := node.find_child("PotDisplay", true, false) as Control
	if community != null and community.visible and pot != null and pot.visible:
		_assert_rects_apart(community, pot, context)
	for bet in bets:
		for cards in hole_cards:
			_assert_rects_apart(bet, cards, context)
		if community != null and community.visible:
			_assert_rects_apart(bet, community, context)
		if pot != null and pot.visible:
			_assert_rects_apart(bet, pot, context)
	for i in range(hole_cards.size()):
		for j in range(i + 1, hole_cards.size()):
			_assert_rects_apart(hole_cards[i], hole_cards[j], context)
		if community != null and community.visible:
			_assert_rects_apart(hole_cards[i], community, context)
		if pot != null and pot.visible:
			_assert_rects_apart(hole_cards[i], pot, context)

func _assert_rects_apart(a: Control, b: Control, context: String) -> void:
	var overlap: Rect2 = a.get_global_rect().intersection(b.get_global_rect())
	# Holders are anchor boxes slightly larger than their content; only flag
	# overlaps big enough to be visible collisions.
	_assert(overlap.size.x <= 8.0 or overlap.size.y <= 8.0, "%s %s and %s overlap by %s" % [context, a.name, b.name, overlap])

func _wait_for_popup(scene: Node, max_frames: int = 12) -> PopupPanel:
	for i in range(max_frames):
		await process_frame
		var popup := _find_visible_popup(scene)
		if popup != null:
			return popup
	return null

func _texture_filter_nearest(node: Node, context: String) -> void:
	if node is TextureRect and node.visible:
		_assert((node as TextureRect).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s TextureRect %s should use nearest filtering" % [context, node.name])
	if node is Button and node.visible and (node as Button).get_theme_stylebox("normal") is StyleBoxTexture:
		_assert((node as Button).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s textured Button %s should use nearest filtering" % [context, node.name])
	for child in node.get_children():
		_texture_filter_nearest(child, context)

# --- Helpers -----------------------------------------------------------------

func _find_visible_popup(node: Node) -> PopupPanel:
	for child in node.get_children():
		if child is PopupPanel and child.visible:
			return child
		var nested := _find_visible_popup(child)
		if nested != null:
			return nested
	return null

func _find_button_with_text(node: Node, text: String) -> Button:
	if node == null:
		return null
	for child in node.get_children():
		if child is Button and child.text == text:
			return child
		var nested := _find_button_with_text(child, text)
		if nested != null:
			return nested
	return null

func _find_button_with_prefix(node: Node, prefix: String) -> Button:
	if node == null:
		return null
	for child in node.get_children():
		if child is Button and child.text.begins_with(prefix):
			return child
		var nested := _find_button_with_prefix(child, prefix)
		if nested != null:
			return nested
	return null

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
