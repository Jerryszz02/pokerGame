extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _probe_menu_and_styles(Vector2i(1280, 720))
	for viewport_size in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		await _probe_table_layout(viewport_size)
	if failures == 0:
		print("All UI layout probes passed.")
	else:
		push_error("%d UI layout probes failed." % failures)
	quit(failures)

func _probe_table_layout(viewport_size: Vector2i) -> void:
	DisplayServer.window_set_size(viewport_size)
	root.size = viewport_size
	await process_frame
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = "user://poker_ui_layout_probe.cfg"
	root.add_child(scene)
	var main_control := scene as Control
	main_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene.ai_pending = true
	scene.game.start_new_match(5, "hard")
	scene._render_table()
	await process_frame
	await process_frame

	var frame := Rect2(Vector2.ZERO, main_control.size)
	var table_root := scene.find_child("TableStageRoot", true, false) as Control
	var table_stage := scene.find_child("TableStage", true, false) as Control
	_assert(table_root != null, "%s should have a full-screen table stage" % viewport_size)
	_assert(table_stage != null, "%s should preserve the table aspect container" % viewport_size)
	if table_root != null:
		var root_ratio := table_root.size.x / float(main_control.size.x)
		_assert(root_ratio >= 0.77 and root_ratio <= 0.80, "%s table width ratio %.3f should stay near 78%%" % [viewport_size, root_ratio])
		_assert(absf(table_root.size.x / table_root.size.y - scene.TABLE_ASPECT) <= 0.01, "%s table should preserve its 1619:971 ratio" % viewport_size)
	var floating_status := scene.find_child("FloatingStatus", true, false) as Control
	var utility_buttons := scene.find_child("UtilityButtons", true, false) as Control
	var action_dock := scene.find_child("ActionDock", true, false) as Control
	_assert(floating_status != null and floating_status.size.x <= 300.0, "%s should use a compact top-left status capsule" % viewport_size)
	_assert(utility_buttons != null and utility_buttons.size.x <= 220.0, "%s should use compact top-right utility buttons" % viewport_size)
	_assert(action_dock != null and action_dock.size.x <= 600.0, "%s should use a compact bottom-right action dock" % viewport_size)
	_assert(scene.find_child("HeaderPanel", true, false) == null, "%s should not keep a persistent top bar" % viewport_size)
	_assert(scene.find_child("ActionPanel", true, false) == null, "%s should not keep a full-width bottom bar" % viewport_size)
	_assert(scene.find_child("EventLogPanel", true, false) == null, "%s should not keep a persistent log column" % viewport_size)
	_assert(scene.find_child("LogDrawer", true, false) == null, "%s should keep the log drawer closed by default" % viewport_size)

	var felt := scene.find_child("TableFeltSafeZone", true, false) as Control
	_assert(felt != null, "%s should expose the felt safety zone" % viewport_size)
	for player_index in range(scene.game.players.size()):
		var portrait := scene.find_child("Seat%dPortrait" % player_index, true, false) as Control
		var info := scene.find_child("Seat%dInfo" % player_index, true, false) as Control
		var cards := scene.find_child("Seat%dHoleCards" % player_index, true, false) as Control
		var stack := scene.find_child("Seat%dStackChips" % player_index, true, false) as Control
		_assert(portrait != null and info != null, "%s seat %d should split portrait and table information" % [viewport_size, player_index])
		_assert(cards != null and stack != null, "%s seat %d should bind cards and chips to SeatInfo" % [viewport_size, player_index])
		if portrait != null and felt != null:
			var portrait_rect := portrait.get_global_rect()
			var overlap := portrait_rect.intersection(felt.get_global_rect())
			var overlap_ratio := overlap.get_area() / maxf(1.0, portrait_rect.get_area())
			_assert(overlap_ratio <= 0.10, "%s seat %d portrait should overlap felt by at most 10%%, got %.3f" % [viewport_size, player_index, overlap_ratio])
		_assert(scene.find_child("Seat%dCharacter" % player_index, true, false) == null, "%s seat %d should not use the old character frame" % [viewport_size, player_index])
	var current_marker := scene.find_child("Seat%dCurrentMarker" % scene.game.current_player_index, true, false)
	_assert(current_marker != null and (current_marker as Control).get_global_rect().get_area() > 0.0, "%s current actor should use a visible portrait marker" % viewport_size)
	var current_portrait := scene.find_child("Seat%dPortrait" % scene.game.current_player_index, true, false) as Control
	var current_sprite := current_portrait.get_child(0) as TextureRect if current_portrait != null and current_portrait.get_child_count() > 0 else null
	_assert(current_sprite != null and current_sprite.material is ShaderMaterial, "%s current actor should use the alpha-outline shader instead of a rectangular panel" % viewport_size)
	_assert(scene.find_child("Seat%dDealer" % scene.game.button_index, true, false) != null, "%s dealer marker should be attached to its seat" % viewport_size)
	_assert(scene.find_child("Seat%dSmallBlind" % scene.game.small_blind_player_index, true, false) != null, "%s small blind marker should be attached to its seat" % viewport_size)
	_assert(scene.find_child("Seat%dBigBlind" % scene.game.big_blind_player_index, true, false) != null, "%s big blind marker should be attached to its seat" % viewport_size)
	_assert(scene.find_child("PotDisplay", true, false) != null and scene.find_child("PotAmount", true, false) != null, "%s pot should use chips plus an exact number plaque" % viewport_size)
	_assert(_controls_fit(scene, frame), "%s visible controls should stay inside viewport" % viewport_size)

	var before_log: int = scene.game.current_player_index
	scene._toggle_log()
	await process_frame
	var drawer := scene.find_child("LogDrawer", true, false) as Control
	_assert(drawer != null and drawer.size.x >= 390.0 and drawer.size.x <= 410.0, "%s log should open as a 400px overlay drawer" % viewport_size)
	_assert(not scene._ai_can_advance(), "%s open log drawer should pause AI advancement" % viewport_size)
	_assert(not scene._execute_ai_turn_if_allowed(), "%s an already scheduled AI callback should recheck and stop while log is open" % viewport_size)
	_assert(scene.game.current_player_index == before_log, "%s opening log should not mutate the game turn" % viewport_size)
	_assert(_controls_fit(scene, frame), "%s open log drawer should stay in the viewport" % viewport_size)
	scene._toggle_log()
	await process_frame
	_assert(scene._ai_can_advance(), "%s closing log should resume AI advancement" % viewport_size)
	_assert(scene.find_child("LogUnreadDot", true, false) == null, "%s viewed log should clear the unread dot" % viewport_size)
	if scene.sound_player:
		scene.sound_player.stop()
	scene.queue_free()
	await process_frame
	await process_frame

func _probe_menu_and_styles(viewport_size: Vector2i) -> void:
	DisplayServer.window_set_size(viewport_size)
	root.size = viewport_size
	await process_frame
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.profile_path = "user://poker_ui_layout_probe.cfg"
	root.add_child(scene)
	var main_control := scene as Control
	main_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var expected_seat_orders := {
		2: [0, 2], 3: [0, 3, 1], 4: [0, 5, 2, 4],
		5: [0, 5, 3, 1, 4], 6: [0, 5, 3, 2, 1, 4]
	}
	for player_count in expected_seat_orders:
		_assert(scene._seat_order_for_player_count(player_count) == expected_seat_orders[player_count], "%d-player seats should follow the table order" % player_count)
	scene._show_settings_popup()
	await process_frame
	await process_frame
	var frame := Rect2(Vector2.ZERO, main_control.size)
	var popup := _find_settings_popup(scene)
	_assert(popup != null and _controls_fit(popup, frame), "settings popup should open inside the viewport")
	_assert(_find_label_with_text(scene, "本地单机牌局") == null, "menu should not show the local-game kicker")
	_assert(_find_label_with_text(scene, "规则清晰、信息优先的战术牌桌") == null, "menu should not show the tactical-table subtitle")
	_assert(_find_label_with_text(scene, "离线运行，不接 API，不使用 LLM。") == null, "menu should not show the offline note")
	_assert(scene.ai_count_spin.size.x >= 176.0 and scene.difficulty_options.size.x >= 176.0, "menu selection controls should have a comfortable width")
	var notice_board := scene.find_child("MenuNoticeBoard", true, false) as PanelContainer
	var notice_texture := scene.find_child("MenuNoticeBoardTexture", true, false) as TextureRect
	var title_logo := scene.find_child("MenuTitleLogo", true, false) as TextureRect
	var table_preview := scene.find_child("MenuTablePreview", true, false) as PanelContainer
	var preview_texture := scene.find_child("MenuTablePreviewTexture", true, false) as TextureRect
	var controls_panel := scene.find_child("MenuControlsPanel", true, false) as PanelContainer
	var start_button := scene.find_child("MenuStartButton", true, false) as Button
	var settings_button := _find_button_with_text(scene, "设置")
	_assert(notice_board != null and notice_board.custom_minimum_size.x > notice_board.custom_minimum_size.y, "menu notice board should use the adjusted landscape proportion")
	_assert(notice_texture != null and notice_texture.texture.resource_path.ends_with("menu-notice-board.png"), "menu should use the generated wooden notice-board asset")
	_assert(title_logo != null and title_logo.get_global_rect().end.y <= notice_board.get_global_rect().position.y + 4.0, "menu title logo should sit centered above the notice board")
	_assert(title_logo != null and absf(title_logo.get_global_rect().get_center().x - notice_board.get_global_rect().get_center().x) <= 0.5, "menu title and notice board should share the same center line")
	var title_atlas := title_logo.texture as AtlasTexture if title_logo != null else null
	_assert(title_atlas != null and absf(title_atlas.region.get_center().x - scene.MENU_TITLE_ANCHOR_X) <= 0.5, "menu title crop should preserve its brass-diamond anchor")
	_assert(table_preview != null and table_preview.get_theme_stylebox("panel") is StyleBoxEmpty, "menu table preview should render without a green frame")
	_assert(preview_texture != null and preview_texture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "menu table preview should keep the complete artwork visible")
	_assert(controls_panel != null and controls_panel.get_theme_stylebox("panel") is StyleBoxEmpty, "menu controls should sit directly on the notice board")
	_assert(start_button != null and start_button.custom_minimum_size == scene.MENU_START_BUTTON_SIZE, "menu start button should keep its compact width")
	_assert(start_button != null and start_button.size_flags_horizontal == Control.SIZE_SHRINK_CENTER, "menu start button should stay centered")
	_assert(start_button != null and start_button.get_theme_stylebox("normal") is StyleBoxFlat, "menu start button should use a crisp code-drawn style")
	_assert(settings_button != null and settings_button.get_theme_stylebox("normal") is StyleBoxFlat, "menu settings button should use a crisp code-drawn style")
	_assert(scene.difficulty_options.get_theme_stylebox("normal") is StyleBoxFlat, "difficulty selector should use a code-drawn field")
	_assert(scene.ai_count_spin.get_line_edit().get_theme_stylebox("normal") is StyleBoxFlat, "opponent selector should use a code-drawn field")
	for color in [scene.COLOR_BRASS, scene.COLOR_ACTION, scene.COLOR_DANGER]:
		var button: Button = scene._command_button("状态", color, scene._white_color())
		button.visible = false
		scene.add_child(button)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := button.get_theme_stylebox(state) as StyleBoxFlat
			_assert(style != null, "command button %s should use StyleBoxFlat" % state)
			if style != null:
				_assert(not style.anti_aliasing, "command button %s should disable anti-aliasing" % state)
		var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
		var hover := button.get_theme_stylebox("hover") as StyleBoxFlat
		_assert(normal != null and hover != null and normal.border_width_left == hover.border_width_left, "hover should keep the normal silhouette")
	_assert(scene.FONT_CAPTION >= 13 and scene.FONT_BUTTON >= 16, "Chinese captions and buttons should meet the minimum font sizes")
	_assert(scene._event_log_text("AI 1 弃牌（谨慎弃牌） (tight fold)") == "AI 1 弃牌", "event log should omit parenthesized details")
	_assert(scene._chip_breakdown(0) == [], "zero chips should have no modules")
	_assert(_breakdown_pairs(scene._chip_breakdown(1)) == [[1, 1]], "1 should use one cream chip")
	_assert(_breakdown_pairs(scene._chip_breakdown(5)) == [[5, 1]], "5 should use one blue-gray chip")
	_assert(_breakdown_pairs(scene._chip_breakdown(20)) == [[5, 4]], "20 should use four 5 chips")
	_assert(_breakdown_pairs(scene._chip_breakdown(945)) == [[500, 1], [100, 4], [25, 1], [5, 4]], "945 should use greedy denominations")
	_assert(_breakdown_pairs(scene._chip_breakdown(1000)) == [[500, 2]], "1000 should use two 500 chips")
	_assert(_breakdown_pairs(scene._chip_breakdown(6000)) == [[500, 12]], "6000 should preserve the exact 500-chip count")
	var seat_stack: Control = scene._chip_stack_view(999999, 2, 5, 1)
	var pot_stack: Control = scene._chip_stack_view(999999, 3, 8, 1)
	_assert(seat_stack.chip_indices.size() <= 10, "seat chip stacks should cap at 2x5 visible modules")
	_assert(pot_stack.chip_indices.size() <= 24, "pot chip stacks should cap at 3x8 visible modules")
	seat_stack.free()
	pot_stack.free()
	if popup != null:
		var reset_button := _find_button_with_text(popup, "重置统计")
		_assert(reset_button != null, "settings popup should expose reset statistics")
		if reset_button != null:
			reset_button.emit_signal("pressed")
			await process_frame
			_assert(_find_button_with_text(popup, "再次点击确认") != null, "statistics reset should require an in-place second confirmation")
		popup.hide()
		await process_frame
	if scene.sound_player:
		scene.sound_player.stop()
	scene.queue_free()
	await process_frame
	await process_frame

func _breakdown_pairs(breakdown: Array) -> Array:
	var pairs: Array = []
	for entry in breakdown:
		pairs.append([int(entry.denomination), int(entry.count)])
	return pairs

func _find_settings_popup(node: Node) -> PopupPanel:
	for child in node.get_children():
		if child is PopupPanel:
			return child
		var nested := _find_settings_popup(child)
		if nested != null:
			return nested
	return null

func _find_button_with_text(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == text:
			return child
		var nested := _find_button_with_text(child, text)
		if nested != null:
			return nested
	return null

func _find_label_with_text(node: Node, text: String) -> Label:
	for child in node.get_children():
		if child is Label and child.text == text:
			return child
		var nested := _find_label_with_text(child, text)
		if nested != null:
			return nested
	return null

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

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
