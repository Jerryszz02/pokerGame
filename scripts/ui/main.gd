extends Control

const COLOR_DEEP = Color(0.018, 0.043, 0.039)
const COLOR_PANEL = Color(0.055, 0.067, 0.058)
const COLOR_PANEL_DARK = Color(0.030, 0.037, 0.033)
const COLOR_CARD = Color(0.930, 0.875, 0.720)
const COLOR_SLOT = Color(0.026, 0.067, 0.056)
const COLOR_BRASS = Color(0.795, 0.630, 0.300)
const COLOR_ACTION = Color(0.195, 0.310, 0.365)
const COLOR_DANGER = Color(0.620, 0.180, 0.165)

const FONT_CAPTION := 11
const FONT_SMALL := 12
const FONT_BODY := 13
const FONT_LABEL := 14
const FONT_BUTTON := 15
const FONT_CARD_COMPACT := 16
const FONT_TITLE := 18
const FONT_VALUE := 20
const FONT_CARD := 21
const FONT_DISPLAY := 24

const BUTTON_SIZE := Vector2(118, 42)
const BUTTON_STEP_SIZE := Vector2(36, 36)
const CARD_SIZE := Vector2(52, 68)
const CARD_SIZE_COMPACT := Vector2(40, 52)
const TABLE_ASPECT := 1619.0 / 971.0

const STAGE_LABELS = {
	TableState.STAGE_PREFLOP: "翻前",
	TableState.STAGE_FLOP: "翻牌",
	TableState.STAGE_TURN: "转牌",
	TableState.STAGE_RIVER: "河牌",
	TableState.STAGE_SHOWDOWN: "摊牌",
	TableState.STAGE_HAND_OVER: "结算"
}
const AUDIO_SAMPLE_RATE := 22050
const MENU_SELECTION_SIZE := Vector2(180, 38)
const MENU_BOARD_SIZE := Vector2(600, 540)
const MENU_START_BUTTON_SIZE := Vector2(360, 48)
const MENU_TITLE_ANCHOR_X := 676.5
const MENU_TITLE_REGION := Rect2(14, 260, 1325, 350)
const LocalProfileScript := preload("res://scripts/game/local_profile.gd")
const MENU_BACKGROUND_TEXTURE := preload("res://assets/art/generated/misc/menu-background.png")
const MENU_NOTICE_BOARD_TEXTURE := preload("res://assets/art/generated/ui/menu-notice-board.png")
const MENU_PREVIEW_TEXTURE := preload("res://assets/art/generated/misc/menu-table-preview.png")
const TITLE_LOGO_TEXTURE := preload("res://assets/art/generated/misc/title-logo.png")
const TABLE_TEXTURE := preload("res://assets/art/generated/table/poker-table.png")
const CARD_COMPONENTS_TEXTURE := preload("res://assets/art/generated/cards/card-components.png")
const BLIND_TOKENS_TEXTURE := preload("res://assets/art/generated/ui/blind-tokens.png")
const CHIP_ATLAS_TEXTURE := preload("res://assets/art/generated/ui/chip-atlas.png")
const BUTTON_ATLAS_TEXTURE := preload("res://assets/art/generated/ui/button-atlas-native.png")
const FORM_CONTROLS_ATLAS_TEXTURE := preload("res://assets/art/generated/ui/form-controls-atlas.png")
const BUTTON_GOLD_REGIONS := {
	"normal": Rect2(8, 8, 118, 42),
	"hover": Rect2(134, 8, 118, 42),
	"pressed": Rect2(260, 8, 118, 42),
	"disabled": Rect2(386, 8, 118, 42),
	"focus": Rect2(512, 8, 118, 42)
}
const BUTTON_BLUE_REGIONS := {
	"normal": Rect2(8, 58, 118, 42),
	"hover": Rect2(134, 58, 118, 42),
	"pressed": Rect2(260, 58, 118, 42),
	"disabled": Rect2(386, 58, 118, 42),
	"focus": Rect2(512, 58, 118, 42)
}
const BUTTON_RED_REGIONS := {
	"normal": Rect2(8, 108, 118, 42),
	"hover": Rect2(134, 108, 118, 42),
	"pressed": Rect2(260, 108, 118, 42),
	"disabled": Rect2(386, 108, 118, 42),
	"focus": Rect2(512, 108, 118, 42)
}
const FIELD_SELECT_CLOSED_REGION := Rect2(151, 100, 264, 122)
const FIELD_SELECT_OPEN_REGION := Rect2(466, 100, 255, 123)
const TRANSPARENT_PIXEL_REGION := Rect2(0, 0, 1, 1)
const CHARACTER_TEXTURES := [
	preload("res://assets/art/generated/characters/player.png"),
	preload("res://assets/art/generated/characters/ai-fox.png"),
	preload("res://assets/art/generated/characters/ai-croupier.png"),
	preload("res://assets/art/generated/characters/ai-bear.png"),
	preload("res://assets/art/generated/characters/ai-veteran.png"),
	preload("res://assets/art/generated/characters/ai-crow.png")
]
const PANEL_ATLAS_TEXTURE := preload("res://assets/art/generated/ui/panel-atlas.png")
const HUD_ICONS_TEXTURE := preload("res://assets/art/generated/ui/hud-icons.png")
const RESULT_BANNERS_TEXTURE := preload("res://assets/art/generated/ui/result-banners.png")
const ACTION_TAGS_TEXTURE := preload("res://assets/art/generated/ui/action-tags.png")
const SEAT_NAMEPLATES_TEXTURE := preload("res://assets/art/generated/ui/seat-nameplates.png")
const TABLE_LIGHT_OVERLAY_TEXTURE := preload("res://assets/art/generated/table/table-light-overlay.png")
const PANEL_FRAME_REGION := Rect2(40, 100, 520, 335)
const RESULT_BANNER_REGION := Rect2(210, 35, 1250, 190)
const HUD_ICON_REGIONS := {
	"hand": Rect2(150, 75, 260, 235),
	"street": Rect2(495, 135, 150, 135),
	"pot": Rect2(1085, 80, 365, 230),
	"bet": Rect2(1145, 350, 190, 245),
	"log": Rect2(650, 810, 245, 200)
}
const CHIP_STACK_REGIONS := [
	Rect2(0, 40, 325, 180),
	Rect2(0, 250, 325, 200),
	Rect2(0, 470, 325, 215),
	Rect2(0, 715, 325, 220)
]
const SEAT_ORDERS_BY_PLAYER_COUNT := {
	2: [0, 2],
	3: [0, 3, 1],
	4: [0, 5, 2, 4],
	5: [0, 5, 3, 1, 4],
	6: [0, 5, 3, 2, 1, 4]
}
const SEAT_LAYOUTS := {
	0: {"char": Vector2(0.500, 0.815), "char_h": 0.370, "cards": Vector2(0.300, 0.780), "bet": Vector2(0.685, 0.780), "plate": Vector2(0.500, 0.945), "token": Vector2(0.210, 0.780)},
	1: {"char": Vector2(0.280, 0.170), "char_h": 0.340, "cards": Vector2(0.220, 0.370), "bet": Vector2(0.362, 0.405), "plate": Vector2(0.280, 0.300), "token": Vector2(0.380, 0.330)},
	2: {"char": Vector2(0.500, 0.170), "char_h": 0.340, "cards": Vector2(0.490, 0.340), "bet": Vector2(0.627, 0.405), "plate": Vector2(0.500, 0.300), "token": Vector2(0.370, 0.330)},
	3: {"char": Vector2(0.730, 0.170), "char_h": 0.340, "cards": Vector2(0.760, 0.370), "bet": Vector2(0.630, 0.330), "plate": Vector2(0.730, 0.300), "token": Vector2(0.615, 0.270)},
	4: {"char": Vector2(0.115, 0.470), "char_h": 0.340, "cards": Vector2(0.200, 0.500), "bet": Vector2(0.300, 0.655), "plate": Vector2(0.115, 0.665), "token": Vector2(0.215, 0.385)},
	5: {"char": Vector2(0.885, 0.470), "char_h": 0.340, "cards": Vector2(0.800, 0.500), "bet": Vector2(0.700, 0.655), "plate": Vector2(0.885, 0.665), "token": Vector2(0.785, 0.385)}
}

var game := PokerRound.new()
var profile := LocalProfileScript.default_profile()
var ai_count_spin: SpinBox
var difficulty_options: OptionButton
var sound_toggle: CheckBox
var music_toggle: CheckBox
var raise_slider: HSlider
var raise_button: Button
var sound_player: AudioStreamPlayer
var stats_label: Label
var stats_reset_button: Button
var stats_reset_pending := false
var last_recorded_hand_number := 0
var ai_pending := false

func _ready() -> void:
	randomize()
	profile = LocalProfileScript.load_profile()
	_setup_audio()
	_show_menu()

func _process(_delta: float) -> void:
	if game.is_ai_turn() and not ai_pending:
		ai_pending = true
		_run_ai_turn()

func _clear() -> void:
	for child in get_children():
		if child == sound_player:
			continue
		remove_child(child)
		child.queue_free()

func _show_menu(reset_pending: bool = true) -> void:
	if reset_pending:
		stats_reset_pending = false
	_clear()
	add_child(_background(MENU_BACKGROUND_TEXTURE, Color(0.008, 0.018, 0.016, 0.24)))

	var shell := CenterContainer.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shell)
	var menu_stack := VBoxContainer.new()
	menu_stack.add_theme_constant_override("separation", 2)
	menu_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_child(menu_stack)

	var logo_texture := _atlas_texture(TITLE_LOGO_TEXTURE, MENU_TITLE_REGION)
	var logo := _texture_rect(logo_texture, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	logo.name = "MenuTitleLogo"
	logo.custom_minimum_size = Vector2(520, 96)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_stack.add_child(logo)

	var panel := PanelContainer.new()
	panel.name = "MenuNoticeBoard"
	panel.custom_minimum_size = MENU_BOARD_SIZE
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	menu_stack.add_child(panel)

	var board := _texture_rect(MENU_NOTICE_BOARD_TEXTURE, TextureRect.STRETCH_SCALE)
	board.name = "MenuNoticeBoardTexture"
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(board)

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 58)
	content.add_theme_constant_override("margin_top", 50)
	content.add_theme_constant_override("margin_right", 58)
	content.add_theme_constant_override("margin_bottom", 48)
	panel.add_child(content)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	content.add_child(box)

	box.add_child(_menu_table_preview())
	box.add_child(_menu_controls_panel())

	add_child(_settings_button())

func _menu_table_preview() -> Control:
	var panel := PanelContainer.new()
	panel.name = "MenuTablePreview"
	panel.custom_minimum_size = Vector2(0, 214)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var preview := _texture_rect(MENU_PREVIEW_TEXTURE, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	preview.name = "MenuTablePreviewTexture"
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(preview)
	return panel

func _menu_controls_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "MenuControlsPanel"
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_menu_row("AI 对手", _build_ai_spin(), true))
	box.add_child(_menu_row("难度", _build_difficulty_options(), true))

	var start_button := _command_button("开始牌局", COLOR_BRASS, _ink_color())
	start_button.name = "MenuStartButton"
	start_button.custom_minimum_size = MENU_START_BUTTON_SIZE
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(_on_start_pressed)
	box.add_child(start_button)
	return panel

func _build_ai_spin() -> SpinBox:
	ai_count_spin = SpinBox.new()
	ai_count_spin.min_value = 1
	ai_count_spin.max_value = 5
	ai_count_spin.step = 1
	ai_count_spin.value = int(profile.settings.ai_count)
	ai_count_spin.custom_minimum_size = MENU_SELECTION_SIZE
	_apply_field_style(ai_count_spin)
	return ai_count_spin

func _build_difficulty_options() -> OptionButton:
	difficulty_options = OptionButton.new()
	difficulty_options.add_item("简单", 0)
	difficulty_options.add_item("中等", 1)
	difficulty_options.add_item("困难", 2)
	match str(profile.settings.difficulty):
		"simple":
			difficulty_options.select(0)
		"medium":
			difficulty_options.select(1)
		"hard":
			difficulty_options.select(2)
		_:
			difficulty_options.select(1)
	difficulty_options.custom_minimum_size = MENU_SELECTION_SIZE
	_apply_field_style(difficulty_options)
	return difficulty_options

func _build_sound_toggle() -> Control:
	sound_toggle = CheckBox.new()
	sound_toggle.text = "开启本地音效"
	sound_toggle.button_pressed = bool(profile.settings.sound_enabled)
	sound_toggle.add_theme_color_override("font_color", _white_color())
	sound_toggle.add_theme_font_size_override("font_size", FONT_BODY)
	sound_toggle.toggled.connect(_on_sound_toggled)
	return sound_toggle

func _build_music_toggle() -> Control:
	music_toggle = CheckBox.new()
	music_toggle.text = "开启本地音乐"
	music_toggle.button_pressed = bool(profile.settings.music_enabled)
	music_toggle.add_theme_color_override("font_color", _white_color())
	music_toggle.add_theme_font_size_override("font_size", FONT_BODY)
	music_toggle.toggled.connect(_on_music_toggled)
	return music_toggle

func _settings_button() -> Button:
	var button := _command_button("设置", COLOR_ACTION, _white_color())
	button.custom_minimum_size = Vector2(96, 42)
	button.anchor_left = 1.0
	button.anchor_top = 1.0
	button.anchor_right = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = -120
	button.offset_top = -66
	button.offset_right = -24
	button.offset_bottom = -24
	button.pressed.connect(_show_settings_popup)
	return button

func _show_settings_popup() -> void:
	var popup := PopupPanel.new()
	popup.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, _edge_color(), 2, 2, Vector2(14, 12)))
	add_child(popup)
	popup.popup_hide.connect(func(): popup.queue_free())
	popup.add_child(_settings_panel(popup))
	popup.popup_centered(Vector2i(390, 330))

func _settings_panel(popup: PopupPanel) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, _edge_color(), 1, 1, Vector2(10, 6)))
	panel.custom_minimum_size = Vector2(350, 270)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = "设置"
	title.add_theme_color_override("font_color", COLOR_BRASS)
	title.add_theme_font_size_override("font_size", FONT_LABEL)
	box.add_child(title)
	box.add_child(_menu_row("音效", _build_sound_toggle()))
	box.add_child(_menu_row("音乐", _build_music_toggle()))
	box.add_child(_stats_panel())
	var close_button := _command_button("关闭", COLOR_ACTION, _white_color())
	close_button.custom_minimum_size = Vector2(0, 36)
	close_button.pressed.connect(func(): popup.hide())
	box.add_child(close_button)
	return panel

func _stats_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = "本地记录"
	title.add_theme_color_override("font_color", COLOR_BRASS)
	title.add_theme_font_size_override("font_size", FONT_LABEL)
	box.add_child(title)
	stats_label = Label.new()
	stats_label.add_theme_color_override("font_color", _muted_color())
	stats_label.add_theme_font_size_override("font_size", FONT_SMALL)
	box.add_child(stats_label)
	stats_reset_button = _command_button("", COLOR_ACTION, _white_color())
	stats_reset_button.custom_minimum_size = Vector2(0, 36)
	stats_reset_button.pressed.connect(_on_reset_stats_pressed)
	box.add_child(stats_reset_button)
	_refresh_stats_panel()
	return box

func _refresh_stats_panel() -> void:
	if stats_label:
		stats_label.text = "总手数 %d · 胜手 %d\n净盈利 %d · 最大单手 +%d" % [
			int(profile.stats.total_hands),
			int(profile.stats.total_win_hands),
			int(profile.stats.total_net_profit),
			int(profile.stats.max_single_hand_win)
		]
	if stats_reset_button:
		var color := COLOR_DANGER if stats_reset_pending else COLOR_ACTION
		stats_reset_button.text = "再次点击确认" if stats_reset_pending else "重置统计"
		_apply_command_button_style(stats_reset_button, color)

func _menu_row(label_text: String, field: Control, centered: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	if centered:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(104 if centered else 150, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_BRASS)
	label.add_theme_font_size_override("font_size", FONT_LABEL)
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if centered else Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return row

func _apply_field_style(field: Control) -> void:
	field.add_theme_color_override("font_color", _white_color())
	field.add_theme_color_override("font_hover_color", COLOR_CARD)
	field.add_theme_color_override("font_focus_color", COLOR_CARD)
	field.add_theme_color_override("font_pressed_color", COLOR_CARD)
	field.add_theme_font_size_override("font_size", FONT_LABEL)
	if field is SpinBox:
		_apply_texture_button_style(field, BUTTON_BLUE_REGIONS)
		var line_edit := (field as SpinBox).get_line_edit()
		line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_edit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		line_edit.add_theme_color_override("font_color", _white_color())
		line_edit.add_theme_color_override("caret_color", COLOR_BRASS)
		line_edit.add_theme_font_size_override("font_size", FONT_LABEL)
		line_edit.add_theme_stylebox_override("normal", _texture_style(BUTTON_ATLAS_TEXTURE, BUTTON_BLUE_REGIONS.normal, Vector2(16, 7)))
		line_edit.add_theme_stylebox_override("focus", _texture_style(BUTTON_ATLAS_TEXTURE, BUTTON_BLUE_REGIONS.focus, Vector2(16, 7)))
	else:
		_apply_select_field_style(field)

func _on_start_pressed() -> void:
	var difficulty := "medium"
	match difficulty_options.get_selected_id():
		0:
			difficulty = "simple"
		1:
			difficulty = "medium"
		2:
			difficulty = "hard"
	profile.settings.ai_count = int(ai_count_spin.value)
	profile.settings.difficulty = difficulty
	LocalProfileScript.save_profile(profile)
	last_recorded_hand_number = 0
	game.start_new_match(int(ai_count_spin.value), difficulty)
	_play_sound(420.0, 0.08)
	_render_table()

func _render_table() -> void:
	_record_completed_hand_if_needed()
	_clear()
	add_child(_background(MENU_BACKGROUND_TEXTURE, Color(0.005, 0.014, 0.012, 0.76)))

	var root := VBoxContainer.new()
	root.anchor_left = 0.035
	root.anchor_top = 0.0
	root.anchor_right = 0.965
	root.anchor_bottom = 1.0
	root.offset_top = 12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	root.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)

	var play_area := VBoxContainer.new()
	play_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_area.add_theme_constant_override("separation", 8)
	body.add_child(play_area)
	play_area.add_child(_build_table_shell())
	play_area.add_child(_build_actions())
	body.add_child(_build_event_log())

func _build_header() -> Control:
	var header := PanelContainer.new()
	header.name = "HeaderPanel"
	header.custom_minimum_size = Vector2(0, 70)
	header.add_theme_stylebox_override("panel", _themed_panel_style(16.0, Vector2(20, 16)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	header.add_child(row)

	row.add_child(_metric_label("hand", "手牌", str(game.hand_number), _white_color()))
	row.add_child(_metric_label("street", "街道", _stage_label(game.stage), _white_color()))
	row.add_child(_metric_label("pot", "底池", str(game.total_pot()), COLOR_BRASS))
	row.add_child(_metric_label("bet", "当前下注", str(game.current_bet), _white_color()))

	var message := Label.new()
	message.text = _status_message()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.add_theme_color_override("font_color", COLOR_BRASS if game.is_human_turn() else _white_color())
	message.add_theme_font_size_override("font_size", FONT_BUTTON)
	row.add_child(message)
	return header

func _metric_label(icon_key: String, label_text: String, value_text: String, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(124, 0)
	row.add_theme_constant_override("separation", 6)
	var icon := _hud_icon(icon_key)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", _muted_color())
	label.add_theme_font_size_override("font_size", FONT_CAPTION)
	box.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", accent)
	value.add_theme_font_size_override("font_size", FONT_VALUE)
	box.add_child(value)
	row.add_child(box)
	return row

func _hud_icon(key: String) -> TextureRect:
	var icon := _texture_rect(_atlas_texture(HUD_ICONS_TEXTURE, HUD_ICON_REGIONS[key]), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _themed_panel_style(slice_margin: float, content_margins: Vector2) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _atlas_texture(PANEL_ATLAS_TEXTURE, PANEL_FRAME_REGION)
	style.texture_margin_left = slice_margin
	style.texture_margin_top = slice_margin
	style.texture_margin_right = slice_margin
	style.texture_margin_bottom = slice_margin
	style.content_margin_left = content_margins.x
	style.content_margin_top = content_margins.y
	style.content_margin_right = content_margins.x
	style.content_margin_bottom = content_margins.y
	return style

func _build_table_shell() -> Control:
	var shell := PanelContainer.new()
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var stage := AspectRatioContainer.new()
	stage.name = "TableStage"
	stage.ratio = TABLE_ASPECT
	shell.add_child(stage)

	var table_root := Control.new()
	table_root.name = "TableStageRoot"
	table_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(table_root)

	var table_art := _texture_rect(TABLE_TEXTURE, TextureRect.STRETCH_SCALE)
	table_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	table_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table_root.add_child(table_art)

	var light := _texture_rect(TABLE_LIGHT_OVERLAY_TEXTURE, TextureRect.STRETCH_SCALE)
	light.set_anchors_preset(Control.PRESET_FULL_RECT)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.modulate = Color(1.0, 1.0, 1.0, 0.45)
	table_root.add_child(light)

	table_root.add_child(_build_pot_instrument())
	var seat_order: Array = _seat_order_for_player_count(game.players.size())
	for player_index in range(game.players.size()):
		if player_index >= seat_order.size():
			break
		var seat_index := int(seat_order[player_index])
		var layout: Dictionary = SEAT_LAYOUTS[seat_index]
		var glow := _seat_glow(player_index, layout)
		if glow != null:
			table_root.add_child(glow)
		table_root.add_child(_seat_character(player_index, layout))
		table_root.add_child(_seat_hole_cards(player_index, layout))
		var bet_widget := _seat_bet_widget(player_index, layout)
		if bet_widget != null:
			table_root.add_child(bet_widget)
		var blind_token := _seat_blind_token(player_index, layout)
		if blind_token != null:
			table_root.add_child(blind_token)
		table_root.add_child(_seat_nameplate(player_index, layout))
	if _last_event_type() == "street":
		_pulse_control(shell, COLOR_BRASS)
	return shell

func _seat_order_for_player_count(player_count: int) -> Array:
	var order: Variant = SEAT_ORDERS_BY_PLAYER_COUNT.get(player_count)
	if order is Array:
		return (order as Array).duplicate()
	return []

func _stage_place(node: Control, center: Vector2, size_frac: Vector2) -> Control:
	node.anchor_left = center.x - size_frac.x / 2.0
	node.anchor_top = center.y - size_frac.y / 2.0
	node.anchor_right = center.x + size_frac.x / 2.0
	node.anchor_bottom = center.y + size_frac.y / 2.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _stage_place_centered(node: Control, center: Vector2) -> Control:
	node.anchor_left = center.x
	node.anchor_top = center.y
	node.anchor_right = center.x
	node.anchor_bottom = center.y
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0
	node.grow_horizontal = Control.GROW_DIRECTION_BOTH
	node.grow_vertical = Control.GROW_DIRECTION_BOTH
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _character_cell_aspect(player_index: int) -> float:
	var texture: Texture2D = CHARACTER_TEXTURES[clampi(player_index, 0, CHARACTER_TEXTURES.size() - 1)]
	return float(texture.get_width()) / 4.0 / float(texture.get_height())

func _seat_character(player_index: int, layout: Dictionary) -> Control:
	var player: Dictionary = game.players[player_index]
	var height_frac: float = layout.char_h
	var width_frac := height_frac * _character_cell_aspect(player_index) / TABLE_ASPECT
	var frame := Control.new()
	frame.name = "Seat%dCharacter" % player_index
	_stage_place(frame, layout.char, Vector2(width_frac, height_frac))
	var texture_index := clampi(player_index, 0, CHARACTER_TEXTURES.size() - 1)
	var texture: Texture2D = CHARACTER_TEXTURES[texture_index]
	var cell_width := float(texture.get_width()) / 4.0
	var region := Rect2(cell_width * clampi(_avatar_state(player_index), 0, 3), 0, cell_width, texture.get_height())
	var sprite := _texture_rect(_atlas_texture(texture, region), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(sprite)
	match str(player.status):
		TableState.STATUS_FOLDED:
			sprite.modulate = Color(0.45, 0.47, 0.44)
		TableState.STATUS_OUT:
			sprite.modulate = Color(0.30, 0.32, 0.30)
	return frame

func _seat_glow(player_index: int, layout: Dictionary) -> Control:
	var player: Dictionary = game.players[player_index]
	var is_current := player_index == game.current_player_index and game.stage != TableState.STAGE_HAND_OVER
	var is_winner := false
	if game.stage == TableState.STAGE_HAND_OVER:
		for win in game.winners:
			if int(win.player_index) == player_index:
				is_winner = true
	if not is_current and not is_winner and player.status != TableState.STATUS_ALL_IN:
		return null
	var ring_color := COLOR_BRASS
	if player.status == TableState.STATUS_ALL_IN and not is_current and not is_winner:
		ring_color = COLOR_DANGER
	var width_frac: float = layout.char_h * _character_cell_aspect(player_index) / TABLE_ASPECT + 0.016
	var height_frac: float = layout.char_h + 0.028
	var ring := PanelContainer.new()
	_stage_place(ring, layout.char, Vector2(width_frac, height_frac))
	ring.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0), ring_color, 3, 2, Vector2(0, 0)))
	if is_current:
		_pulse_control(ring, COLOR_BRASS)
	return ring

func _seat_hole_cards(player_index: int, layout: Dictionary) -> Control:
	var player: Dictionary = game.players[player_index]
	var holder := CenterContainer.new()
	holder.name = "Seat%dHoleCards" % player_index
	_stage_place_centered(holder, layout.cards)
	if player.status == TableState.STATUS_FOLDED or player.status == TableState.STATUS_OUT:
		return holder
	var is_human := bool(player.is_human)
	var reveal := is_human or game.stage == TableState.STAGE_HAND_OVER
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 4)
	for card in player.hole_cards:
		cards.add_child(_card_view(card, reveal, not is_human))
	holder.add_child(cards)
	return holder

func _seat_bet_widget(player_index: int, layout: Dictionary) -> Control:
	var player: Dictionary = game.players[player_index]
	var bet := int(player.current_bet)
	var last_action := str(player.last_action)
	if bet <= 0 and last_action.is_empty():
		return null
	var holder := CenterContainer.new()
	holder.name = "Seat%dBet" % player_index
	_stage_place_centered(holder, layout.bet)
	if not last_action.is_empty():
		holder.add_child(_action_tag(player_index, last_action, bet, layout.char.y > layout.bet.y))
	else:
		var chips := _chip_stack_view(bet)
		chips.custom_minimum_size = Vector2(56, 34)
		holder.add_child(chips)
	return holder

func _action_tag(player_index: int, last_action: String, bet: int, tail_down: bool) -> Control:
	var player: Dictionary = game.players[player_index]
	var text := _action_label(last_action)
	if bet > 0 and (last_action == "Call" or last_action == "Check"):
		text = "%s %d" % [text, bet]
	var dimmed: bool = player.status == TableState.STATUS_FOLDED or player.status == TableState.STATUS_OUT
	var row := 1
	var text_color := _white_color()
	if dimmed:
		row = 2
		text_color = _muted_color()
	elif last_action == "Raise" or last_action == "All-in" or last_action.begins_with("Blind"):
		row = 0
		text_color = _ink_color()
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", _tag_style(row, tail_down))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", FONT_CAPTION)
	tag.add_child(label)
	return tag

func _tag_style(row: int, tail_down: bool) -> StyleBoxTexture:
	var col := 0 if tail_down else 1
	var style := StyleBoxTexture.new()
	style.texture = _atlas_texture(ACTION_TAGS_TEXTURE, Rect2(col * 104 + 4, row * 32 + 4, 96, 24))
	style.texture_margin_left = 12.0
	style.texture_margin_top = 9.0
	style.texture_margin_right = 12.0
	style.texture_margin_bottom = 9.0
	style.content_margin_left = 12.0
	style.content_margin_top = 9.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 9.0
	return style

func _seat_blind_token(player_index: int, layout: Dictionary) -> Control:
	var token_index := -1
	if player_index == game.button_index:
		token_index = 0
	elif player_index == game.small_blind_player_index:
		token_index = 1
	elif player_index == game.big_blind_player_index:
		token_index = 2
	else:
		return null
	var regions := [Rect2(205, 42, 345, 370), Rect2(645, 42, 350, 370), Rect2(1090, 42, 390, 370)]
	var token := _texture_rect(_atlas_texture(BLIND_TOKENS_TEXTURE, regions[token_index]), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	token.name = "Seat%dToken" % player_index
	_stage_place(token, layout.token, Vector2(0.045, 0.045 * TABLE_ASPECT))
	return token

func _seat_nameplate(player_index: int, layout: Dictionary) -> Control:
	var player: Dictionary = game.players[player_index]
	var is_human := bool(player.is_human)
	var is_current := player_index == game.current_player_index and game.stage != TableState.STAGE_HAND_OVER
	var is_winner := false
	if game.stage == TableState.STAGE_HAND_OVER:
		for win in game.winners:
			if int(win.player_index) == player_index:
				is_winner = true
	var plate := PanelContainer.new()
	plate.name = "Seat%dPlate" % player_index
	_stage_place(plate, layout.plate, Vector2(0.170, 0.054) if is_human else Vector2(0.140, 0.050))
	var state := 0
	if player.status == TableState.STATUS_ALL_IN:
		state = 2
	elif is_current or is_winner:
		state = 1
	plate.add_theme_stylebox_override("panel", _nameplate_style(state))
	var label := Label.new()
	label.text = _nameplate_text(player_index)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	var font_color := _white_color()
	if player.status == TableState.STATUS_FOLDED or player.status == TableState.STATUS_OUT:
		font_color = _muted_color()
	elif is_current:
		font_color = COLOR_BRASS
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_font_size_override("font_size", FONT_CAPTION)
	plate.add_child(label)
	return plate

func _nameplate_style(state: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _atlas_texture(SEAT_NAMEPLATES_TEXTURE, Rect2(state * 118 + 4, 4, 110, 26))
	style.texture_margin_left = 10.0
	style.texture_margin_top = 8.0
	style.texture_margin_right = 10.0
	style.texture_margin_bottom = 8.0
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style

func _nameplate_text(player_index: int) -> String:
	var player: Dictionary = game.players[player_index]
	var display_name := _seat_name(player_index)
	match str(player.status):
		TableState.STATUS_FOLDED:
			return "%s · 已弃牌" % display_name
		TableState.STATUS_ALL_IN:
			return "%s · 全下" % display_name
		TableState.STATUS_OUT:
			return "%s · 出局" % display_name
	return "%s · %d" % [display_name, int(player.stack)]

func _build_event_log() -> Control:
	var panel := PanelContainer.new()
	panel.name = "EventLogPanel"
	panel.custom_minimum_size = Vector2(260, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _themed_panel_style(16.0, Vector2(20, 16)))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	var title_icon := _hud_icon("log")
	title_icon.custom_minimum_size = Vector2(18, 18)
	title_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(title_icon)
	var title := Label.new()
	title.text = "牌局记录"
	title.add_theme_color_override("font_color", COLOR_BRASS)
	title.add_theme_font_size_override("font_size", FONT_SMALL)
	title_row.add_child(title)
	box.add_child(title_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)

	var events := game.recent_events(14)
	for event in events:
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "> %s" % _event_log_text(str(event.text))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", _muted_color())
		label.add_theme_font_size_override("font_size", FONT_SMALL)
		list.add_child(label)
	return panel

func _event_log_text(event_text: String) -> String:
	var compact_text := event_text
	var chinese_parentheses := RegEx.new()
	chinese_parentheses.compile("（[^）]*）")
	compact_text = chinese_parentheses.sub(compact_text, "", true)
	var parentheses := RegEx.new()
	parentheses.compile("\\([^)]*\\)")
	return parentheses.sub(compact_text, "", true).strip_edges()

func _build_pot_instrument() -> Control:
	var panel := PanelContainer.new()
	panel.name = "PotInstrument"
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(overlay)

	var cards_holder := CenterContainer.new()
	cards_holder.name = "CommunityCards"
	_stage_place_centered(cards_holder, Vector2(0.5, 0.510))
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 6)
	for card in game.community_cards:
		cards.add_child(_card_view(card, true, true))
	cards_holder.add_child(cards)
	overlay.add_child(cards_holder)

	var pot_holder := CenterContainer.new()
	pot_holder.name = "PotLabel"
	_stage_place_centered(pot_holder, Vector2(0.5, 0.625))
	var pot_row := HBoxContainer.new()
	pot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pot_row.add_theme_constant_override("separation", 10)
	var chips := _chip_stack_view(game.total_pot())
	chips.custom_minimum_size = Vector2(72, 40)
	pot_row.add_child(chips)
	var pot := Label.new()
	pot.text = "底池 %d" % game.total_pot()
	pot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pot.add_theme_color_override("font_color", COLOR_BRASS)
	pot.add_theme_font_size_override("font_size", FONT_DISPLAY)
	pot_row.add_child(pot)
	pot_holder.add_child(pot_row)
	overlay.add_child(pot_holder)
	return panel

func _chip_stack_view(amount: int) -> TextureRect:
	if amount <= 0:
		return _texture_rect(null, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	var ratio := float(amount) / maxf(1.0, float(game.big_blind))
	var tier := 0
	if ratio > 12.0:
		tier = 3
	elif ratio > 4.0:
		tier = 2
	elif ratio > 1.5:
		tier = 1
	var region: Rect2 = CHIP_STACK_REGIONS[tier]
	region.position.x = mini(tier + 1, 4) * 325.0
	var chips := _texture_rect(_atlas_texture(CHIP_ATLAS_TEXTURE, region), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chips

func _build_actions() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ActionPanel"
	panel.custom_minimum_size = Vector2(0, 116)
	panel.add_theme_stylebox_override("panel", _themed_panel_style(16.0, Vector2(20, 16)))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	if game.stage == TableState.STAGE_HAND_OVER:
		box.add_child(_result_panel())
		return panel
	if not game.is_human_turn():
		var waiting := Label.new()
		waiting.text = "等待 %s 行动..." % game.players[game.current_player_index].name
		waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		waiting.size_flags_vertical = Control.SIZE_EXPAND_FILL
		waiting.add_theme_color_override("font_color", _muted_color())
		waiting.add_theme_font_size_override("font_size", FONT_BODY)
		box.add_child(waiting)
		return panel

	var legal := game.get_legal_actions(0)
	var actions_row := HBoxContainer.new()
	actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_row.add_theme_constant_override("separation", 10)
	box.add_child(actions_row)

	_add_action_button(actions_row, "弃牌", TableState.ACTION_FOLD, legal, COLOR_DANGER)
	_add_action_button(actions_row, "让牌", TableState.ACTION_CHECK, legal, COLOR_ACTION)
	_add_action_button(actions_row, "跟注 %d" % game.get_to_call(0), TableState.ACTION_CALL, legal, COLOR_ACTION)
	_add_action_button(actions_row, "全下", TableState.ACTION_ALL_IN, legal, COLOR_DANGER)

	if legal.actions.has(TableState.ACTION_RAISE):
		var raise_row := HBoxContainer.new()
		raise_row.alignment = BoxContainer.ALIGNMENT_CENTER
		raise_row.add_theme_constant_override("separation", 12)
		box.add_child(raise_row)
		var decrease_button := _raise_step_button("-")
		decrease_button.pressed.connect(func(): _change_raise_by_step(-1))
		raise_row.add_child(decrease_button)
		raise_slider = HSlider.new()
		raise_slider.min_value = legal.min_raise_to
		raise_slider.max_value = legal.max_raise_to
		raise_slider.step = game.big_blind
		raise_slider.value = legal.min_raise_to
		raise_slider.custom_minimum_size = Vector2(320, 32)
		raise_slider.add_theme_stylebox_override("slider", _panel_style(COLOR_SLOT, _edge_color().darkened(0.30), 1, 2, Vector2(0, 0)))
		raise_slider.add_theme_stylebox_override("grabber_area", _panel_style(COLOR_BRASS, COLOR_BRASS.darkened(0.30), 1, 2, Vector2(0, 0)))
		raise_slider.value_changed.connect(_on_raise_slider_changed)
		raise_row.add_child(raise_slider)
		var increase_button := _raise_step_button("+")
		increase_button.pressed.connect(func(): _change_raise_by_step(1))
		raise_row.add_child(increase_button)
		raise_button = _command_button("加注到", COLOR_BRASS, _ink_color())
		raise_button.pressed.connect(func(): _on_action(TableState.ACTION_RAISE, int(raise_slider.value)))
		raise_row.add_child(raise_button)
		_on_raise_slider_changed(raise_slider.value)
	return panel

func _result_panel() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var banner_stack := Control.new()
	banner_stack.custom_minimum_size = Vector2(260, 40)
	var banner_art := _texture_rect(_atlas_texture(RESULT_BANNERS_TEXTURE, RESULT_BANNER_REGION), TextureRect.STRETCH_SCALE)
	banner_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_stack.add_child(banner_art)
	var title := Label.new()
	title.text = _status_message()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_theme_color_override("font_color", COLOR_BRASS)
	title.add_theme_font_size_override("font_size", FONT_LABEL)
	banner_stack.add_child(title)
	row.add_child(banner_stack)
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if game.match_over and not game.match_summary.is_empty():
		var summary := Label.new()
		summary.text = "总手数 %d · 最终筹码 %d · 净盈利 %d · 最大单手 +%d" % [
			int(game.match_summary.hands),
			int(game.match_summary.final_stack),
			int(game.match_summary.net_profit),
			int(game.match_summary.max_single_hand_win)
		]
		summary.add_theme_color_override("font_color", _white_color())
		summary.add_theme_font_size_override("font_size", FONT_SMALL)
		info.add_child(summary)
	for win in game.winners:
		var win_label := Label.new()
		win_label.text = "%s +%d (%s)" % [game.players[win.player_index].name, win.amount, win.rank_name]
		win_label.add_theme_color_override("font_color", _white_color())
		win_label.add_theme_font_size_override("font_size", FONT_SMALL)
		info.add_child(win_label)
	row.add_child(info)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_theme_constant_override("separation", 10)
	if game.players[0].stack > 0 and not game.match_over:
		var next_button := _command_button("下一手", COLOR_BRASS, _ink_color())
		next_button.pressed.connect(func():
			game.start_next_hand()
			_play_sound(360.0, 0.06)
			_render_table()
		)
		buttons.add_child(next_button)
	var restart_button := _command_button("重新开始", COLOR_ACTION, _white_color())
	restart_button.pressed.connect(_show_menu)
	buttons.add_child(restart_button)
	row.add_child(buttons)
	_fade_in(row, 0.22)
	return row

func _card_view(card: Dictionary, face_up: bool, compact: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE_COMPACT if compact else CARD_SIZE
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var card_region := Rect2(50, 45, 320, 440) if face_up else Rect2(735, 40, 330, 455)
	var card_art := _texture_rect(_atlas_texture(CARD_COMPONENTS_TEXTURE, card_region), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(card_art)
	var label := Label.new()
	label.text = CardUtil.card_label(card) if face_up else "◆"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _card_color(card) if face_up else COLOR_BRASS)
	label.add_theme_font_size_override("font_size", FONT_CARD_COMPACT if compact else FONT_CARD)
	panel.add_child(label)
	return panel

func _avatar_state(player_index: int) -> int:
	var player: Dictionary = game.players[player_index]
	if player.status == TableState.STATUS_FOLDED or player.status == TableState.STATUS_OUT:
		return 3
	if player_index == game.current_player_index and game.stage != TableState.STAGE_HAND_OVER:
		return 1
	if not str(player.last_action).is_empty():
		return 2
	return 0

func _add_action_button(parent: Control, label: String, action: String, legal: Dictionary, color: Color) -> void:
	if not legal.actions.has(action):
		return
	var button := _command_button(label, color, _white_color() if color != COLOR_BRASS else _ink_color())
	button.pressed.connect(func(): _on_action(action, 0))
	parent.add_child(button)

func _command_button(label: String, color: Color, text_color: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", _muted_color())
	button.add_theme_font_size_override("font_size", FONT_BUTTON)
	_apply_command_button_style(button, color)
	return button

func _raise_step_button(label: String) -> Button:
	var button := _command_button(label, COLOR_ACTION, _white_color())
	button.custom_minimum_size = BUTTON_STEP_SIZE
	button.tooltip_text = "按最小单位调整加注"
	return button

func _change_raise_by_step(direction: int) -> void:
	if raise_slider == null:
		return
	var step_amount := maxi(1, int(raise_slider.step))
	var next_value := int(raise_slider.value) + direction * step_amount
	raise_slider.value = clampi(next_value, int(raise_slider.min_value), int(raise_slider.max_value))

func _on_raise_slider_changed(value: float) -> void:
	if raise_button:
		raise_button.text = "加注到 %d" % int(value)

func _on_sound_toggled(enabled: bool) -> void:
	profile.settings.sound_enabled = enabled
	LocalProfileScript.save_profile(profile)

func _on_music_toggled(enabled: bool) -> void:
	profile.settings.music_enabled = enabled
	LocalProfileScript.save_profile(profile)

func _on_reset_stats_pressed() -> void:
	if not stats_reset_pending:
		stats_reset_pending = true
		_refresh_stats_panel()
		return
	profile = LocalProfileScript.reset_stats(profile)
	LocalProfileScript.save_profile(profile)
	stats_reset_pending = false
	_refresh_stats_panel()

func _on_action(action: String, amount: int) -> void:
	game.apply_action(action, amount)
	_play_action_sound(action)
	_render_table()

func _run_ai_turn() -> void:
	var delay := _ai_action_delay(game.players[game.current_player_index])
	await get_tree().create_timer(delay).timeout
	if game.is_ai_turn():
		var idx := game.current_player_index
		var decision := AiDecision.decide(game, idx)
		game.apply_action(decision.action_type, int(decision.get("amount", 0)), str(decision.get("decision_label", "")))
		_play_action_sound(str(decision.action_type))
	ai_pending = false
	_render_table()

func _ai_action_delay(player: Dictionary) -> float:
	if str(player.get("difficulty", "medium")) != "hard":
		return randf_range(3.0, 5.0)
	var personality: Variant = player.get("personality", {})
	var profile_name := ""
	if personality is Dictionary:
		profile_name = str(personality.get("name", ""))
	match profile_name:
		"LooseAggressive":
			return randf_range(1.8, 3.2)
		"TightAggressive":
			return randf_range(2.6, 4.2)
		"CallingStation":
			return randf_range(3.2, 5.0)
		"Rock":
			return randf_range(4.0, 6.0)
		_:
			return randf_range(2.8, 4.6)

func _record_completed_hand_if_needed() -> void:
	if game.stage != TableState.STAGE_HAND_OVER:
		return
	if game.hand_number <= 0 or game.hand_number == last_recorded_hand_number:
		return
	last_recorded_hand_number = game.hand_number
	profile = LocalProfileScript.normalize_profile(profile)
	profile.stats.total_hands += 1
	profile.stats.total_net_profit += game.last_hand_human_delta
	if game.last_hand_human_won:
		profile.stats.total_win_hands += 1
	if game.last_hand_human_delta > profile.stats.max_single_hand_win:
		profile.stats.max_single_hand_win = game.last_hand_human_delta
	LocalProfileScript.save_profile(profile)

func _setup_audio() -> void:
	sound_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = AUDIO_SAMPLE_RATE
	stream.buffer_length = 0.08
	sound_player.stream = stream
	add_child(sound_player)
	sound_player.play()

func _play_action_sound(action: String) -> void:
	match action:
		TableState.ACTION_FOLD:
			_play_sound(180.0, 0.05)
		TableState.ACTION_RAISE, TableState.ACTION_ALL_IN:
			_play_sound(520.0, 0.09)
		_:
			_play_sound(300.0, 0.05)

func _play_sound(frequency: float, duration: float) -> void:
	if not bool(profile.settings.sound_enabled) or sound_player == null:
		return
	if not sound_player.playing:
		sound_player.play()
	var playback := sound_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames := int(AUDIO_SAMPLE_RATE * duration)
	for i in range(frames):
		var phase := TAU * frequency * float(i) / float(AUDIO_SAMPLE_RATE)
		var envelope := 1.0 - float(i) / float(maxi(1, frames))
		var sample := sin(phase) * 0.08 * envelope
		playback.push_frame(Vector2(sample, sample))

func _fade_in(control: CanvasItem, duration: float) -> void:
	if control == null:
		return
	control.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(control, "modulate:a", 1.0, clampf(duration, 0.08, 0.35))

func _pulse_control(control: CanvasItem, color: Color) -> void:
	if control == null:
		return
	control.modulate = color.lightened(0.10)
	var tween := create_tween()
	tween.tween_property(control, "modulate", Color.WHITE, 0.18)

func _last_event_type() -> String:
	if game.event_log.is_empty():
		return ""
	return str(game.event_log[game.event_log.size() - 1].type)

func _atlas_texture(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas

func _texture_rect(texture: Texture2D, stretch_mode_value: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = stretch_mode_value
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect

func _background(texture: Texture2D = null, tint: Color = COLOR_DEEP) -> Control:
	var background := Control.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture != null:
		var art := _texture_rect(texture, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.add_child(art)
	var tint_layer := ColorRect.new()
	tint_layer.color = tint
	tint_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(tint_layer)
	return background

func _edge_color() -> Color:
	return Color(0.190, 0.270, 0.235)

func _white_color() -> Color:
	return COLOR_CARD.lightened(0.05)

func _muted_color() -> Color:
	return Color(0.565, 0.545, 0.455)

func _ink_color() -> Color:
	return Color(0.025, 0.028, 0.024)

func _panel_style(bg: Color, border: Color, radius: int, border_width: int, margins: Vector2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var pixel_radius := clampi(radius, 0, 3)
	var pixel_border := maxi(border_width, 1)
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = pixel_border
	style.border_width_top = pixel_border
	style.border_width_right = pixel_border
	style.border_width_bottom = pixel_border
	style.corner_radius_top_left = pixel_radius
	style.corner_radius_top_right = pixel_radius
	style.corner_radius_bottom_left = pixel_radius
	style.corner_radius_bottom_right = pixel_radius
	style.content_margin_left = margins.x
	style.content_margin_right = margins.x
	style.content_margin_top = margins.y
	style.content_margin_bottom = margins.y
	return style

func _button_style(bg: Color, outline_alpha: float) -> StyleBoxFlat:
	var border := COLOR_CARD.darkened(0.10) if outline_alpha > 0.0 else bg.lightened(0.12)
	var style := _panel_style(bg, border, 1, 2, Vector2(14, 8))
	style.shadow_color = Color(0.005, 0.012, 0.010, 0.72)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 3)
	if outline_alpha > 0.0:
		style.expand_margin_left = 2
		style.expand_margin_top = 2
		style.expand_margin_right = 2
		style.expand_margin_bottom = 2
	return style

func _texture_style(texture: Texture2D, region: Rect2, margins: Vector2) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _atlas_texture(texture, region)
	style.texture_margin_left = 8.0
	style.texture_margin_top = 6.0
	style.texture_margin_right = 8.0
	style.texture_margin_bottom = 6.0
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.x
	style.content_margin_bottom = margins.y
	return style

func _apply_texture_button_style(control: Control, regions: Dictionary) -> void:
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	control.add_theme_stylebox_override("normal", _texture_style(BUTTON_ATLAS_TEXTURE, regions.normal, Vector2(16, 7)))
	control.add_theme_stylebox_override("hover", _texture_style(BUTTON_ATLAS_TEXTURE, regions.hover, Vector2(16, 7)))
	control.add_theme_stylebox_override("pressed", _texture_style(BUTTON_ATLAS_TEXTURE, regions.pressed, Vector2(16, 7)))
	control.add_theme_stylebox_override("disabled", _texture_style(BUTTON_ATLAS_TEXTURE, regions.disabled, Vector2(16, 7)))
	control.add_theme_stylebox_override("focus", _texture_style(BUTTON_ATLAS_TEXTURE, regions.focus, Vector2(16, 7)))

func _apply_command_button_style(control: Control, color: Color) -> void:
	var regions := BUTTON_BLUE_REGIONS
	if color == COLOR_BRASS:
		regions = BUTTON_GOLD_REGIONS
	elif color == COLOR_DANGER:
		regions = BUTTON_RED_REGIONS
	_apply_texture_button_style(control, regions)

func _select_field_style(region: Rect2) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _atlas_texture(FORM_CONTROLS_ATLAS_TEXTURE, region)
	style.content_margin_left = 16.0
	style.content_margin_top = 7.0
	style.content_margin_right = 40.0
	style.content_margin_bottom = 7.0
	return style

func _apply_select_field_style(control: Control) -> void:
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	control.add_theme_stylebox_override("normal", _select_field_style(FIELD_SELECT_CLOSED_REGION))
	control.add_theme_stylebox_override("hover", _select_field_style(FIELD_SELECT_OPEN_REGION))
	control.add_theme_stylebox_override("pressed", _select_field_style(FIELD_SELECT_OPEN_REGION))
	control.add_theme_stylebox_override("disabled", _select_field_style(FIELD_SELECT_CLOSED_REGION))
	control.add_theme_stylebox_override("focus", _select_field_style(FIELD_SELECT_OPEN_REGION))
	control.add_theme_icon_override("arrow", _atlas_texture(FORM_CONTROLS_ATLAS_TEXTURE, TRANSPARENT_PIXEL_REGION))

func _field_style(bg: Color, border: Color, focused: bool = false) -> StyleBoxFlat:
	var style := _panel_style(bg, border, 1, 2, Vector2(12, 7))
	style.shadow_color = Color(0.004, 0.010, 0.008, 0.68)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	if focused:
		style.expand_margin_left = 1
		style.expand_margin_top = 1
		style.expand_margin_right = 1
		style.expand_margin_bottom = 1
	return style

func _card_color(card: Dictionary) -> Color:
	if card.suit == "H" or card.suit == "D":
		return COLOR_DANGER
	return _ink_color()

func _stage_label(stage_name: String) -> String:
	return STAGE_LABELS.get(stage_name, stage_name)

func _status_message() -> String:
	if game.stage == TableState.STAGE_HAND_OVER:
		return game.last_message
	if game.current_player_index >= 0:
		var actor: Dictionary = game.players[game.current_player_index]
		if actor.is_human:
			return "轮到你行动"
		return "等待 %s 行动" % actor.name
	return game.last_message

func _seat_name(player_index: int) -> String:
	var player: Dictionary = game.players[player_index]
	if player.is_human:
		return "你"
	return player.name

func _action_label(action: String) -> String:
	if action.begins_with("Blind"):
		return action.replace("Blind", "盲注")
	if action.begins_with("Raise"):
		return action.replace("Raise", "加注到")
	match action:
		"Fold":
			return "弃牌"
		"Check":
			return "让牌"
		"Call":
			return "跟注"
		"All-in":
			return "全下"
	return action
