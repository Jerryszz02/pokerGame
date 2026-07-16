extends Control

const COLOR_DEEP = Color(0.018, 0.043, 0.039)
const COLOR_PANEL = Color(0.055, 0.067, 0.058)
const COLOR_PANEL_DARK = Color(0.030, 0.037, 0.033)
const COLOR_CARD = Color(0.930, 0.875, 0.720)
const COLOR_SLOT = Color(0.026, 0.067, 0.056)
const COLOR_BRASS = Color(0.795, 0.630, 0.300)
const COLOR_ACTION = Color(0.195, 0.310, 0.365)
const COLOR_DANGER = Color(0.620, 0.180, 0.165)

const STAGE_ORDER = [
	TableState.STAGE_PREFLOP,
	TableState.STAGE_FLOP,
	TableState.STAGE_TURN,
	TableState.STAGE_RIVER,
	TableState.STAGE_SHOWDOWN
]

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

var game := PokerRound.new()
var profile := LocalProfileScript.default_profile()
var ai_count_spin: SpinBox
var difficulty_options: OptionButton
var sound_toggle: CheckBox
var music_toggle: CheckBox
var raise_slider: HSlider
var raise_label: Label
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
	sound_toggle.add_theme_font_size_override("font_size", 13)
	sound_toggle.toggled.connect(_on_sound_toggled)
	return sound_toggle

func _build_music_toggle() -> Control:
	music_toggle = CheckBox.new()
	music_toggle.text = "开启本地音乐"
	music_toggle.button_pressed = bool(profile.settings.music_enabled)
	music_toggle.add_theme_color_override("font_color", _white_color())
	music_toggle.add_theme_font_size_override("font_size", 13)
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
	title.add_theme_font_size_override("font_size", 14)
	box.add_child(title)
	box.add_child(_menu_row("音效", _build_sound_toggle()))
	box.add_child(_menu_row("音乐", _build_music_toggle()))
	box.add_child(_stats_panel())
	var close_button := _command_button("关闭", COLOR_ACTION, _white_color())
	close_button.custom_minimum_size = Vector2(0, 34)
	close_button.pressed.connect(func(): popup.hide())
	box.add_child(close_button)
	return panel

func _stats_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = "本地记录"
	title.add_theme_color_override("font_color", COLOR_BRASS)
	title.add_theme_font_size_override("font_size", 14)
	box.add_child(title)
	stats_label = Label.new()
	stats_label.add_theme_color_override("font_color", _muted_color())
	stats_label.add_theme_font_size_override("font_size", 12)
	box.add_child(stats_label)
	stats_reset_button = _command_button("", COLOR_ACTION, _white_color())
	stats_reset_button.custom_minimum_size = Vector2(0, 34)
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
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if centered else Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return row

func _apply_field_style(field: Control) -> void:
	field.add_theme_color_override("font_color", _white_color())
	field.add_theme_color_override("font_hover_color", COLOR_CARD)
	field.add_theme_color_override("font_focus_color", COLOR_CARD)
	field.add_theme_color_override("font_pressed_color", COLOR_CARD)
	field.add_theme_font_size_override("font_size", 14)
	if field is SpinBox:
		_apply_texture_button_style(field, BUTTON_BLUE_REGIONS)
		var line_edit := (field as SpinBox).get_line_edit()
		line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_edit.add_theme_color_override("font_color", _white_color())
		line_edit.add_theme_color_override("caret_color", COLOR_BRASS)
		line_edit.add_theme_font_size_override("font_size", 14)
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
	header.custom_minimum_size = Vector2(0, 48)
	header.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, _edge_color(), 1, 2, Vector2(14, 7)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	header.add_child(row)

	row.add_child(_metric_label("手牌", str(game.hand_number), COLOR_BRASS))
	row.add_child(_metric_label("街道", _stage_label(game.stage), COLOR_ACTION))
	row.add_child(_metric_label("底池", str(game.total_pot()), COLOR_BRASS))
	row.add_child(_metric_label("当前下注", str(game.current_bet), COLOR_ACTION))

	var message := Label.new()
	message.text = _status_message()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.add_theme_color_override("font_color", _white_color())
	message.add_theme_font_size_override("font_size", 15)
	row.add_child(message)
	return header

func _metric_label(label_text: String, value_text: String, accent: Color) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(112, 0)
	box.add_theme_constant_override("separation", 0)
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", _muted_color())
	label.add_theme_font_size_override("font_size", 11)
	box.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", accent)
	value.add_theme_font_size_override("font_size", 22)
	box.add_child(value)
	return box

func _build_table_shell() -> Control:
	var table := PanelContainer.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var table_art := _texture_rect(TABLE_TEXTURE, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	table_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.add_child(table_art)

	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 22)
	inset.add_theme_constant_override("margin_top", 16)
	inset.add_theme_constant_override("margin_right", 22)
	inset.add_theme_constant_override("margin_bottom", 12)
	table.add_child(inset)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	inset.add_child(box)
	box.add_child(_build_top_opponents())

	var center := HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 12)
	center.add_child(_side_seat(4))
	center.add_child(_build_pot_instrument())
	center.add_child(_side_seat(5))
	box.add_child(center)

	var player_row := HBoxContainer.new()
	player_row.alignment = BoxContainer.ALIGNMENT_CENTER
	player_row.add_child(_seat_panel(0, true))
	box.add_child(player_row)
	if _last_event_type() == "street":
		_pulse_control(table, COLOR_BRASS)
	return table

func _build_event_log() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, _edge_color(), 1, 2, Vector2(12, 8)))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	var title := Label.new()
	title.text = "牌局记录 / LOG"
	title.add_theme_color_override("font_color", COLOR_BRASS)
	title.add_theme_font_size_override("font_size", 12)
	box.add_child(title)

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
		label.custom_minimum_size = Vector2(0, 22)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "> %s" % _event_log_text(str(event.text))
		label.clip_text = true
		label.add_theme_color_override("font_color", _muted_color())
		label.add_theme_font_size_override("font_size", 12)
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

func _build_top_opponents() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for i in range(1, min(game.players.size(), 4)):
		row.add_child(_seat_panel(i, false))
	return row

func _side_seat(player_index: int) -> Control:
	if player_index < game.players.size():
		return _seat_panel(player_index, false)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(218, 82)
	return spacer

func _build_pot_instrument() -> Control:
	var panel := PanelContainer.new()
	panel.name = "PotInstrument"
	panel.custom_minimum_size = Vector2(420, 148)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 14)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_right", 14)
	content.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(content)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	content.add_child(box)

	var stage_row := HBoxContainer.new()
	stage_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_row.add_theme_constant_override("separation", 8)
	for stage_name in STAGE_ORDER:
		stage_row.add_child(_stage_chip(stage_name))
	box.add_child(stage_row)

	var pot := Label.new()
	pot.text = "底池 %d" % game.total_pot()
	pot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pot.add_theme_color_override("font_color", COLOR_BRASS)
	pot.add_theme_font_size_override("font_size", 25)
	box.add_child(pot)
	box.add_child(_pot_chip_view())

	var bet := Label.new()
	bet.text = "当前下注 %d · 待跟 %d" % [game.current_bet, _current_to_call()]
	bet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bet.add_theme_color_override("font_color", _white_color())
	bet.add_theme_font_size_override("font_size", 12)
	box.add_child(bet)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 8)
	for i in range(5):
		if i < game.community_cards.size():
			cards.add_child(_card_view(game.community_cards[i], true))
		else:
			cards.add_child(_empty_card(i))
	box.add_child(cards)
	return panel

func _stage_chip(stage_name: String) -> Control:
	var current := stage_name == game.stage or (game.stage == TableState.STAGE_HAND_OVER and stage_name == TableState.STAGE_SHOWDOWN)
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(72, 26)
	var fill := COLOR_BRASS if current else COLOR_SLOT
	var border := COLOR_BRASS if current else _edge_color().darkened(0.18)
	chip.add_theme_stylebox_override("panel", _panel_style(fill, border, 1, 2, Vector2(10, 4)))
	var label := Label.new()
	label.text = _stage_label(stage_name)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _ink_color() if current else _muted_color())
	label.add_theme_font_size_override("font_size", 12)
	chip.add_child(label)
	return chip

func _build_actions() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 100)
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, _edge_color(), 1, 2, Vector2(16, 10)))

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
		waiting.add_theme_color_override("font_color", _white_color())
		waiting.add_theme_font_size_override("font_size", 18)
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
	_add_action_button(actions_row, "全下", TableState.ACTION_ALL_IN, legal, COLOR_BRASS)

	if legal.actions.has(TableState.ACTION_RAISE):
		var raise_row := HBoxContainer.new()
		raise_row.alignment = BoxContainer.ALIGNMENT_CENTER
		raise_row.add_theme_constant_override("separation", 12)
		box.add_child(raise_row)
		raise_label = Label.new()
		raise_label.custom_minimum_size = Vector2(170, 0)
		raise_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		raise_label.add_theme_color_override("font_color", COLOR_BRASS)
		raise_label.add_theme_font_size_override("font_size", 14)
		raise_row.add_child(raise_label)
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
		var raise_button := _command_button("加注到", COLOR_BRASS, _ink_color())
		raise_button.pressed.connect(func(): _on_action(TableState.ACTION_RAISE, int(raise_slider.value)))
		raise_row.add_child(raise_button)
		_on_raise_slider_changed(raise_slider.value)
	return panel

func _result_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = _status_message()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_BRASS)
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	if game.match_over and not game.match_summary.is_empty():
		var summary := Label.new()
		summary.text = "总手数 %d · 最终筹码 %d · 净盈利 %d · 最大单手 +%d" % [
			int(game.match_summary.hands),
			int(game.match_summary.final_stack),
			int(game.match_summary.net_profit),
			int(game.match_summary.max_single_hand_win)
		]
		summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		summary.add_theme_color_override("font_color", _white_color())
		summary.add_theme_font_size_override("font_size", 14)
		box.add_child(summary)
	for win in game.winners:
		var row := Label.new()
		row.text = "%s +%d (%s)" % [game.players[win.player_index].name, win.amount, win.rank_name]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_color_override("font_color", _white_color())
		row.add_theme_font_size_override("font_size", 14)
		box.add_child(row)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	if game.players[0].stack > 0 and not game.match_over:
		var next_button := _command_button("下一手", COLOR_ACTION, _white_color())
		next_button.pressed.connect(func():
			game.start_next_hand()
			_play_sound(360.0, 0.06)
			_render_table()
		)
		buttons.add_child(next_button)
	var restart_button := _command_button("重新开始", COLOR_BRASS, _ink_color())
	restart_button.pressed.connect(_show_menu)
	buttons.add_child(restart_button)
	_fade_in(box, 0.22)
	return box

func _seat_panel(player_index: int, reveal: bool) -> Control:
	var player: Dictionary = game.players[player_index]
	var is_current := player_index == game.current_player_index and game.stage != TableState.STAGE_HAND_OVER
	var is_human := bool(player.is_human)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(218 if not is_human else 320, 82)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := Color(COLOR_PANEL.r, COLOR_PANEL.g, COLOR_PANEL.b, 0.92)
	var border := COLOR_BRASS if is_current else _edge_color()
	if player.status == TableState.STATUS_FOLDED:
		bg = COLOR_PANEL_DARK
	elif player.status == TableState.STATUS_ALL_IN:
		border = COLOR_DANGER
	panel.add_theme_stylebox_override("panel", _panel_style(bg, border, 1, 3 if is_current else 2, Vector2(10, 6)))
	if is_current:
		_pulse_control(panel, COLOR_BRASS)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_avatar_view(player_index, _avatar_state(player_index)))

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(62 if not is_human else 104, 0)
	info.add_theme_constant_override("separation", 1)
	box.add_child(info)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 5)
	info.add_child(title_row)

	var title := Label.new()
	title.text = _seat_name(player_index)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", _white_color())
	title.add_theme_font_size_override("font_size", 15 if is_human else 13)
	title_row.add_child(title)

	var blind_badge := _blind_badge(player_index)
	if blind_badge != null:
		title_row.add_child(blind_badge)

	var state := Label.new()
	state.text = "筹码 %d\n下注 %d · %s" % [player.stack, player.current_bet, _status_label(player.status)]
	state.add_theme_color_override("font_color", _muted_color())
	state.add_theme_font_size_override("font_size", 11)
	info.add_child(state)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 4)
	for card in player.hole_cards:
		cards.add_child(_card_view(card, reveal or game.stage == TableState.STAGE_HAND_OVER, not is_human))
	box.add_child(cards)

	var footer := Label.new()
	footer.text = _seat_footer(player)
	footer.add_theme_color_override("font_color", COLOR_BRASS if is_current else _muted_color())
	footer.add_theme_font_size_override("font_size", 11)
	info.add_child(footer)
	return panel

func _blind_badge(player_index: int) -> Control:
	var text := ""
	var token_index := 0
	if player_index == game.button_index:
		text = "庄"
		token_index = 0
	elif player_index == game.small_blind_player_index:
		text = "小盲"
		token_index = 1
	elif player_index == game.big_blind_player_index:
		text = "大盲"
		token_index = 2
	else:
		return null

	var badge := HBoxContainer.new()
	badge.add_theme_constant_override("separation", 2)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	var regions := [Rect2(205, 42, 345, 370), Rect2(645, 42, 350, 370), Rect2(1090, 42, 390, 370)]
	var icon := _texture_rect(_atlas_texture(BLIND_TOKENS_TEXTURE, regions[token_index]), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	icon.custom_minimum_size = Vector2(22, 22)
	badge.add_child(icon)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_BRASS if text != "大盲" else COLOR_DANGER.lightened(0.18))
	label.add_theme_font_size_override("font_size", 10)
	badge.add_child(label)
	return badge

func _card_view(card: Dictionary, face_up: bool, compact: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(40, 52) if compact else Vector2(52, 68)
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
	label.add_theme_font_size_override("font_size", 16 if compact else 21)
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

func _avatar_view(player_index: int, state_index: int) -> TextureRect:
	var texture_index := clampi(player_index, 0, CHARACTER_TEXTURES.size() - 1)
	var texture: Texture2D = CHARACTER_TEXTURES[texture_index]
	var cell_width := float(texture.get_width()) / 4.0
	var region := Rect2(cell_width * clampi(state_index, 0, 3), 0, cell_width, texture.get_height())
	var avatar := _texture_rect(_atlas_texture(texture, region), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	avatar.custom_minimum_size = Vector2(48, 64)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return avatar

func _pot_chip_view() -> TextureRect:
	var color_index := clampi(int(game.total_pot() / 250), 0, 4)
	var region := Rect2(color_index * 325.0, 215.0, 325.0, 260.0)
	var chips := _texture_rect(_atlas_texture(CHIP_ATLAS_TEXTURE, region), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	chips.custom_minimum_size = Vector2(0, 24)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chips

func _empty_card(index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(52, 68)
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_SLOT, _edge_color().darkened(0.25), 1, 2, Vector2(4, 4)))
	var label := Label.new()
	label.text = "街%d" % (index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _muted_color())
	label.add_theme_font_size_override("font_size", 12)
	panel.add_child(label)
	return panel

func _add_action_button(parent: Control, label: String, action: String, legal: Dictionary, color: Color) -> void:
	if not legal.actions.has(action):
		return
	var button := _command_button(label, color, _white_color() if color != COLOR_BRASS else _ink_color())
	button.pressed.connect(func(): _on_action(action, 0))
	parent.add_child(button)

func _command_button(label: String, color: Color, text_color: Color) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(118, 42)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", _muted_color())
	button.add_theme_font_size_override("font_size", 15)
	_apply_command_button_style(button, color)
	return button

func _raise_step_button(label: String) -> Button:
	var button := _command_button(label, COLOR_ACTION, _white_color())
	button.custom_minimum_size = Vector2(42, 36)
	button.tooltip_text = "按最小单位调整加注"
	return button

func _change_raise_by_step(direction: int) -> void:
	if raise_slider == null:
		return
	var step_amount := maxi(1, int(raise_slider.step))
	var next_value := int(raise_slider.value) + direction * step_amount
	raise_slider.value = clampi(next_value, int(raise_slider.min_value), int(raise_slider.max_value))

func _on_raise_slider_changed(value: float) -> void:
	if raise_label:
		raise_label.text = "加注到 %d" % int(value)

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

func _current_to_call() -> int:
	if game.players.is_empty():
		return 0
	if game.is_human_turn():
		return game.get_to_call(0)
	if game.current_player_index >= 0:
		return game.get_to_call(game.current_player_index)
	return 0

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

func _seat_footer(player: Dictionary) -> String:
	if not player.last_action.is_empty():
		return _action_label(player.last_action)
	if player.personality is Dictionary and player.personality.has("label"):
		return player.personality.label
	return "等待行动"

func _status_label(status: String) -> String:
	match status:
		TableState.STATUS_ACTIVE:
			return "在局"
		TableState.STATUS_FOLDED:
			return "已弃牌"
		TableState.STATUS_ALL_IN:
			return "全下"
		TableState.STATUS_OUT:
			return "出局"
	return status

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
