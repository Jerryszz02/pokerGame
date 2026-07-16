extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _probe_menu_settings_popup(Vector2i(1280, 720))
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
	root.add_child(scene)
	var main_control: Control = scene
	main_control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main_control.size = Vector2(viewport_size)
	scene.game.start_new_match(5, "hard")
	scene._render_table()
	await process_frame
	await process_frame

	var frame := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var table_root := _find_table_root(scene)
	_assert(table_root != null, "%s should have a table root container" % viewport_size)
	if table_root == null:
		scene.queue_free()
		await process_frame
		return
	var root_ratio := table_root.size.x / float(viewport_size.x)
	_assert(root_ratio >= 0.70 and root_ratio <= 0.94, "%s root width ratio %.3f should be within 70%%-94%%" % [viewport_size, root_ratio])
	var pot_instrument := scene.find_child("PotInstrument", true, false) as PanelContainer
	_assert(pot_instrument != null, "%s should show the pot and community-card instrument" % viewport_size)
	if pot_instrument != null:
		_assert(pot_instrument.get_theme_stylebox("panel") is StyleBoxEmpty, "%s pot instrument should render directly on the table art" % viewport_size)
	_assert(_controls_fit(scene, frame), "%s visible controls should stay inside viewport" % viewport_size)
	if scene.sound_player:
		scene.sound_player.stop()
	scene.queue_free()
	await process_frame
	await process_frame

func _probe_menu_settings_popup(viewport_size: Vector2i) -> void:
	DisplayServer.window_set_size(viewport_size)
	root.size = viewport_size
	await process_frame
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var main_control: Control = scene
	main_control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main_control.size = Vector2(viewport_size)
	await process_frame
	scene._show_settings_popup()
	await process_frame
	await process_frame

	var frame := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var popup := _find_settings_popup(scene)
	_assert(popup != null, "%s settings popup should open from menu" % viewport_size)
	if popup != null:
		_assert(_controls_fit(popup, frame), "%s settings popup should stay inside viewport" % viewport_size)
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
	_assert(title_logo != null and absf(title_logo.get_global_rect().get_center().x - notice_board.get_global_rect().get_center().x) <= 0.5, "menu title and notice board controls should share the same center line")
	var title_atlas := title_logo.texture as AtlasTexture if title_logo != null else null
	_assert(title_atlas != null and absf(title_atlas.region.get_center().x - scene.MENU_TITLE_ANCHOR_X) <= 0.5, "menu title crop should center its brass diamond anchor")
	_assert(table_preview != null and table_preview.get_theme_stylebox("panel") is StyleBoxEmpty, "menu table preview should render without a green frame")
	_assert(preview_texture != null and preview_texture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "menu table preview should keep the complete artwork visible")
	_assert(controls_panel != null and controls_panel.get_theme_stylebox("panel") is StyleBoxEmpty, "menu controls should sit directly on the notice board without a dark backing panel")
	_assert(start_button != null and start_button.custom_minimum_size == scene.MENU_START_BUTTON_SIZE, "menu start button should be shorter than the notice-board content width")
	_assert(start_button != null and start_button.size_flags_horizontal == Control.SIZE_SHRINK_CENTER, "menu start button should stay centered inside the notice board")
	_assert(start_button != null and start_button.get_theme_stylebox("normal") is StyleBoxTexture, "menu start button should use the generated pixel-art atlas")
	_assert(settings_button != null and settings_button.get_theme_stylebox("normal") is StyleBoxTexture, "menu settings button should use the resizable pixel-art atlas")
	_assert(scene.difficulty_options.get_theme_stylebox("normal") is StyleBoxTexture, "menu difficulty selector should use the generated integrated field texture")
	var select_style := scene.difficulty_options.get_theme_stylebox("normal") as StyleBoxTexture
	var select_texture := select_style.texture as AtlasTexture if select_style != null else null
	_assert(select_texture != null and select_texture.region == scene.FIELD_SELECT_CLOSED_REGION, "menu difficulty selector should include its small arrow inside the field artwork")
	var select_arrow := scene.difficulty_options.get_theme_icon("arrow") as AtlasTexture
	_assert(select_arrow != null and select_arrow.region.size == Vector2(1, 1), "menu difficulty selector should hide the oversized separate arrow")
	_assert(scene.ai_count_spin.get_line_edit().get_theme_stylebox("normal") is StyleBoxTexture, "menu opponent selector should use the generated pixel-art atlas")
	var gold_button: Button = scene._command_button("主要操作", scene.COLOR_BRASS, scene._ink_color())
	var blue_button: Button = scene._command_button("次要操作", scene.COLOR_ACTION, scene._white_color())
	var red_button: Button = scene._command_button("危险操作", scene.COLOR_DANGER, scene._white_color())
	for button in [gold_button, blue_button, red_button]:
		button.visible = false
		scene.add_child(button)
		var button_style := button.get_theme_stylebox("normal") as StyleBoxTexture
		var button_texture := button_style.texture as AtlasTexture if button_style != null else null
		_assert(button_texture != null and button_texture.atlas.resource_path.ends_with("button-atlas-native.png"), "command buttons should use the native-resolution GPT Image 2 atlas")
		_assert(button_texture != null and button_texture.region.size == Vector2(118, 42), "command button skins should match the standard runtime button size")
		_assert(button_style != null and button_style.texture_margin_left == 8.0, "command buttons should preserve the native atlas end caps")
		_assert(button_style != null and button_style.texture_margin_top == 6.0, "command buttons should keep a straight side between their clipped corners")
		_assert(button.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "command buttons should render without linear-filter blur")
	_assert(scene._event_log_text("AI 1 弃牌（谨慎弃牌） (tight fold)") == "AI 1 弃牌", "event log should omit parenthesized details")
	if popup != null:
		var reset_button := _find_button_with_text(popup, "重置统计")
		_assert(reset_button != null, "%s settings popup should expose reset stats button" % viewport_size)
		if reset_button != null:
			reset_button.emit_signal("pressed")
			await process_frame
			var confirm_popup := _find_settings_popup(scene)
			_assert(confirm_popup != null and confirm_popup.visible, "%s settings popup should stay open while confirming reset" % viewport_size)
			var confirm_button := _find_button_with_text(confirm_popup, "再次点击确认") if confirm_popup != null else null
			_assert(confirm_button != null, "%s reset button should switch to confirm text in place" % viewport_size)
	if scene.sound_player:
		scene.sound_player.stop()
	scene.queue_free()
	await process_frame
	await process_frame

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

func _find_table_root(node: Node) -> Control:
	for child in node.get_children():
		if child is VBoxContainer and child is Control:
			var rect: Rect2 = child.get_global_rect()
			if rect.size.x > 1000.0 and rect.size.y > 400.0:
				return child
		var nested := _find_table_root(child)
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
