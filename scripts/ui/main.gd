extends Control

const AUDIO_CREDITS := "Airport Lounge — Kevin MacLeod (incompetech.com)\nCC BY 4.0 · https://creativecommons.org/licenses/by/4.0/\nhttps://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100806\nUnmodified recording, repeated at reduced volume.\n\nCasino Audio — Kenney (kenney.nl)\nCC0 · https://kenney.nl/assets/casino-audio"

const COLOR_DEEP = Color(0.018, 0.043, 0.039)
const COLOR_PANEL = Color(0.055, 0.067, 0.058)
const COLOR_PANEL_DARK = Color(0.030, 0.037, 0.033)
const COLOR_CARD = Color(0.930, 0.875, 0.720)
const COLOR_SLOT = Color(0.026, 0.067, 0.056)
const COLOR_BRASS = Color(0.795, 0.630, 0.300)
const COLOR_ACTION = Color(0.195, 0.310, 0.365)
const COLOR_DANGER = Color(0.620, 0.180, 0.165)

const FONT_CAPTION := 13
const FONT_SMALL := 14
const FONT_BODY := 15
const FONT_LABEL := 15
const FONT_BUTTON := 16
const FONT_CARD_COMPACT := 16
const FONT_TITLE := 18
const FONT_VALUE := 20
const FONT_CARD := 21
const FONT_DISPLAY := 24

const BUTTON_SIZE := Vector2(104, 40)
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
const GameAudioScript := preload("res://scripts/ui/game_audio.gd")
const MENU_SELECTION_SIZE := Vector2(180, 38)
const MENU_BOARD_SIZE := Vector2(600, 540)
const MENU_START_BUTTON_SIZE := Vector2(360, 48)
const MENU_TITLE_ANCHOR_X := 676.5
const MENU_TITLE_REGION := Rect2(14, 260, 1325, 350)
const ExportSelfTestScript := preload("res://scripts/game/export_self_test.gd")
const LocalProfileScript := preload("res://scripts/game/local_profile.gd")
const GameLocalizationScript := preload("res://scripts/game/localization.gd")
const UI_FONT := preload("res://assets/fonts/UI-Regular.tres")
const MENU_BACKGROUND_TEXTURE := preload("res://assets/art/generated/misc/menu-background.png")
const MENU_NOTICE_BOARD_TEXTURE := preload("res://assets/art/generated/ui/menu-notice-board.png")
const MENU_PREVIEW_TEXTURE := preload("res://assets/art/generated/misc/menu-table-preview.png")
const TITLE_LOGO_TEXTURE := preload("res://assets/art/generated/misc/title-logo.png")
const TABLE_TEXTURE := preload("res://assets/art/generated/table/poker-table.png")
const CARD_COMPONENTS_TEXTURE := preload("res://assets/art/generated/cards/card-components.png")
const CHIP_MODULES_TEXTURE := preload("res://assets/art/generated/ui/chip-modules.png")
const ChipStackViewScript := preload("res://scripts/ui/chip_stack.gd")
const PORTRAIT_OUTLINE_SHADER := preload("res://scripts/ui/portrait_outline.gdshader")
const CHARACTER_TEXTURES := [
	preload("res://assets/art/generated/characters/player.png"),
	preload("res://assets/art/generated/characters/ai-fox.png"),
	preload("res://assets/art/generated/characters/ai-croupier.png"),
	preload("res://assets/art/generated/characters/ai-bear.png"),
	preload("res://assets/art/generated/characters/ai-veteran.png"),
	preload("res://assets/art/generated/characters/ai-crow.png")
]
const ACTION_TAGS_TEXTURE := preload("res://assets/art/generated/ui/action-tags.png")
const SEAT_NAMEPLATES_TEXTURE := preload("res://assets/art/generated/ui/seat-nameplates.png")
const TABLE_LIGHT_OVERLAY_TEXTURE := preload("res://assets/art/generated/table/table-light-overlay.png")
const SEAT_ORDERS_BY_PLAYER_COUNT := {
	2: [0, 2],
	3: [0, 3, 1],
	4: [0, 5, 2, 4],
	5: [0, 5, 3, 1, 4],
	6: [0, 5, 3, 2, 1, 4]
}
const SEAT_LAYOUTS := {
	0: {"portrait": Vector2(0.500, 0.910), "portrait_h": 0.245, "info": Vector2(0.500, 0.735), "plate": Vector2(0.500, 0.835)},
	1: {"portrait": Vector2(0.280, 0.090), "portrait_h": 0.225, "info": Vector2(0.280, 0.285), "plate": Vector2(0.280, 0.175)},
	2: {"portrait": Vector2(0.500, 0.080), "portrait_h": 0.225, "info": Vector2(0.500, 0.280), "plate": Vector2(0.500, 0.165)},
	3: {"portrait": Vector2(0.720, 0.090), "portrait_h": 0.225, "info": Vector2(0.720, 0.285), "plate": Vector2(0.720, 0.175)},
	4: {"portrait": Vector2(0.070, 0.500), "portrait_h": 0.230, "info": Vector2(0.205, 0.500), "plate": Vector2(0.120, 0.625)},
	5: {"portrait": Vector2(0.930, 0.500), "portrait_h": 0.230, "info": Vector2(0.795, 0.500), "plate": Vector2(0.880, 0.625)}
}

var game := PokerRound.new()
var profile_path := LocalProfileScript.PROFILE_PATH
var _ai_worker := AiTurnWorker.new()
var _ai_epoch := 0
var _ai_request := {}
var _ai_result := {}
var _ai_wait := 0.0
var _save_notice_pending := false
var profile := LocalProfileScript.default_profile()
var ai_count_spin: SpinBox
var difficulty_options: OptionButton
var sound_toggle: CheckBox
var pace_toggle: CheckBox
var raise_slider: HSlider
var raise_button: Button
var sound_player: GameAudioScript
var stats_label: Label
var stats_reset_button: Button
var stats_reset_pending := false
var last_recorded_hand_number := 0
var ai_pending := false
var log_open := false
var paused := false
var raise_expanded := false
var last_seen_event_fingerprint := ""
var last_rendered_pot := -1
var current_mode := "free"
var pending_match_config: Dictionary = MatchConfig.DEFAULTS.duplicate(true)
var mode_config_panel: Control
var mode_config_notice: Label
var practice_store: PracticeStore
var tutorial_controller: TutorialController
var practice_views: PracticeViews
var _pending_records: Dictionary = {}
var _pending_matches: Dictionary = {}
var _submitted_hands: Dictionary = {}
var _practice_save_error := ""
var _auto_next_elapsed := 0.0
var _match_open := false

func _ready() -> void:
	# Apply after resource import; project-level custom fonts load before first import.
	theme = Theme.new()
	theme.default_font = UI_FONT
	var self_test := OS.get_cmdline_user_args().has("--self-test")
	if self_test:
		if DisplayServer.get_name() != "headless":
			push_error("Run the package self-test with --headless -- --self-test")
			get_tree().quit(1)
			return
		profile_path = OS.get_cache_dir().path_join("poker_export_self_test.cfg")
	randomize()
	profile = LocalProfileScript.load_profile(profile_path)
	GameLocalizationScript.apply_choice(profile.settings.get("language", GameLocalizationScript.SYSTEM))
	practice_store = PracticeStore.new("user://poker_practice" if profile_path == LocalProfileScript.PROFILE_PATH else profile_path + ".practice")
	practice_store.migrate_legacy(profile)
	pending_match_config = MatchConfig.normalize(profile.settings)
	practice_views = PracticeViews.new(self)
	get_window().min_size = Vector2i(1280, 720)
	get_tree().auto_accept_quit = false
	_setup_audio()
	_show_menu()
	if not str(profile.get("notice", "")).is_empty():
		_show_text_popup(GameLocalization.present("配置恢复"), profile.notice, "ProfileNoticePopup")
	if not practice_store.notice.is_empty():
		_show_text_popup(GameLocalization.present("本地资料"), practice_store.notice, "PracticeNoticePopup")
	if self_test:
		call_deferred("_run_package_self_test")

func _process(delta: float) -> void:
	practice_views.tick(delta)
	if _ai_can_advance() and game.stage == TableState.STAGE_HAND_OVER and not game.match_over and game.match_config.mode == "practice" and not game.match_config.pause_each_hand and _pending_records.is_empty():
		_auto_next_elapsed += delta
		if _auto_next_elapsed >= 3.0:
			_next_hand()
	if _ai_worker.is_ready():
		var result := _ai_worker.take_result()
		if _ai_request_is_current():
			_ai_result = result
		else:
			ai_pending = false
	if not _ai_can_advance() or not game.is_ai_turn():
		return
	if ai_pending:
		_ai_wait = maxf(0.0, _ai_wait - delta)
		if _ai_wait == 0.0 and _execute_ai_turn_if_allowed():
			ai_pending = false
			_ai_result = {}
			_render_table()
	elif not _ai_worker.is_started():
		_run_ai_turn()

func _exit_tree() -> void:
	_ai_worker.finish()
	if is_instance_valid(sound_player):
		sound_player.stop_all()
		sound_player.stream = null

func _invalidate_ai_turn() -> void:
	_ai_epoch += 1
	ai_pending = false
	_ai_result = {}

func _ai_request_is_current() -> bool:
	return not _ai_request.is_empty() and _ai_request.epoch == _ai_epoch and _ai_request.hand == game.hand_number and _ai_request.actor == game.current_player_index and _ai_request.stage == game.stage

func _clear() -> void:
	raise_slider = null
	raise_button = null
	for child in get_children():
		if child == sound_player:
			continue
		remove_child(child)
		child.queue_free()

func _show_menu(reset_pending: bool = true) -> void:
	if _match_open:
		_record_match_outcome()
		_match_open = false
	_invalidate_ai_turn()
	if reset_pending:
		stats_reset_pending = false
	paused = false
	_clear()
	add_child(_background(MENU_BACKGROUND_TEXTURE, Color(0.008, 0.018, 0.016, 0.24)))

	var shell := CenterContainer.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shell)
	var menu_stack := VBoxContainer.new()
	menu_stack.add_theme_constant_override("separation", 2)
	menu_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_child(menu_stack)

	if TranslationServer.get_locale().begins_with("en"):
		var logo := Label.new()
		logo.name = "MenuTitleLogo"
		logo.text = "♠ POKERGAME ♦"
		logo.custom_minimum_size = Vector2(520, 96)
		logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		logo.add_theme_font_size_override("font_size", 40)
		logo.add_theme_color_override("font_color", COLOR_BRASS.lightened(0.25))
		menu_stack.add_child(logo)
	else:
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
	var primary := GridContainer.new()
	primary.name = "PrimaryModeEntries"
	primary.columns = 1
	primary.add_theme_constant_override("h_separation", 6)
	primary.add_theme_constant_override("v_separation", 6)
	for entry in [{"name":GameLocalization.present("新手教程"), "id":"tutorial", "node":"HomeTutorialButton"}, {"name":GameLocalization.present("自由对战"), "id":"free", "node":"HomeFreePlayButton"}, {"name":GameLocalization.present("练习对局 · 基础流程"), "id":"practice", "node":"HomePracticeButton"}]:
		var mode_button := _command_button(str(entry.name), COLOR_ACTION, _white_color())
		mode_button.name = str(entry.node)
		mode_button.custom_minimum_size = Vector2(0, 42)
		mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_button.pressed.connect(func(): _open_mode(str(entry.id)))
		primary.add_child(mode_button)
	box.add_child(primary)
	var secondary := HBoxContainer.new()
	secondary.name = "SecondaryHomeEntries"
	secondary.alignment = BoxContainer.ALIGNMENT_CENTER
	secondary.add_theme_constant_override("separation", 6)
	for entry in [{"name":GameLocalization.present("牌局记录"), "id":"history"}, {"name":GameLocalization.present("统计与成就"), "id":"stats"}]:
		var secondary_button := _command_button(str(entry.name), COLOR_PANEL_DARK, _muted_color())
		secondary_button.name = "Home%sButton" % str(entry.id).capitalize()
		secondary_button.custom_minimum_size = Vector2(132, 34)
		secondary_button.pressed.connect(func(): _open_home_secondary(str(entry.id)))
		secondary.add_child(secondary_button)
	box.add_child(secondary)
	var help_button := _command_button(GameLocalization.present("玩法说明"), COLOR_ACTION, _white_color())
	help_button.name = "MenuHelpButton"
	help_button.custom_minimum_size = Vector2(180, 36)
	help_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	help_button.pressed.connect(_show_help)
	box.add_child(help_button)
	return panel

func _build_ai_spin() -> SpinBox:
	ai_count_spin = SpinBox.new()
	ai_count_spin.min_value = 1
	ai_count_spin.max_value = 5
	ai_count_spin.step = 1
	ai_count_spin.value = int(pending_match_config.ai_count)
	ai_count_spin.custom_minimum_size = MENU_SELECTION_SIZE
	_apply_field_style(ai_count_spin)
	return ai_count_spin

func _build_difficulty_options() -> OptionButton:
	difficulty_options = OptionButton.new()
	difficulty_options.add_item(GameLocalization.present("简单"), 0)
	difficulty_options.add_item(GameLocalization.present("普通"), 1)
	difficulty_options.add_item(GameLocalization.present("困难"), 2)
	match str(pending_match_config.difficulty):
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
	sound_toggle.text = tr("开启本地音效")
	sound_toggle.button_pressed = bool(profile.settings.sound_enabled)
	sound_toggle.add_theme_color_override("font_color", _white_color())
	sound_toggle.add_theme_font_size_override("font_size", FONT_BODY)
	sound_toggle.toggled.connect(_on_sound_toggled)
	return sound_toggle

func _build_pace_toggle() -> Control:
	pace_toggle = CheckBox.new()
	pace_toggle.text = tr("快速行动")
	pace_toggle.button_pressed = bool(profile.settings.fast_mode)
	pace_toggle.add_theme_color_override("font_color", _white_color())
	pace_toggle.add_theme_font_size_override("font_size", FONT_BODY)
	pace_toggle.toggled.connect(_on_pace_toggled)
	return pace_toggle

func _settings_button() -> Button:
	var button := _command_button(GameLocalization.present("设置"), COLOR_ACTION, _white_color())
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
	var in_match := _in_match()
	var popup := PopupPanel.new()
	popup.theme = theme
	popup.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, _edge_color(), 2, 2, Vector2(14, 12)))
	add_child(popup)
	popup.popup_hide.connect(func(): popup.queue_free())
	popup.add_child(_settings_panel(popup, in_match))
	popup.popup_centered(Vector2i(540, 670) if in_match else Vector2i(540, 610))

func _settings_panel(popup: PopupPanel, in_match: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, _edge_color(), 1, 1, Vector2(10, 6)))
	panel.custom_minimum_size = Vector2(350, 318 if in_match else 270)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = tr("设置")
	title.add_theme_color_override("font_color", COLOR_BRASS)
	title.add_theme_font_size_override("font_size", FONT_LABEL)
	box.add_child(title)
	box.add_child(_menu_row(GameLocalization.present("音效"), _build_sound_toggle()))
	box.add_child(_menu_row(GameLocalization.present("音乐音量"), _audio_volume_control("music_volume")))
	box.add_child(_menu_row(GameLocalization.present("音效音量"), _audio_volume_control("sound_volume")))
	box.add_child(_menu_row(GameLocalization.present("节奏"), _build_pace_toggle()))
	box.add_child(_language_row(popup, in_match))
	box.add_child(_stats_panel())
	var help_button := _command_button(GameLocalization.present("规则速览"), COLOR_ACTION, _white_color())
	help_button.name = "RulesReferenceButton"
	help_button.pressed.connect(func():
		popup.hide()
		_show_help()
	)
	box.add_child(help_button)
	var hands_button := _command_button(GameLocalization.present("牌型速览"), COLOR_ACTION, _white_color())
	hands_button.name = "HandsReferenceButton"
	hands_button.pressed.connect(func(): popup.hide(); _show_hand_reference())
	box.add_child(hands_button)
	var credits := _command_button(GameLocalization.present("音频署名"), COLOR_ACTION, _white_color())
	credits.name = "AudioCreditsButton"
	credits.pressed.connect(func():
		popup.hide()
		_show_text_popup(GameLocalization.present("音频署名"), AUDIO_CREDITS, "AudioCreditsPopup"))
	box.add_child(credits)
	if in_match and current_mode == "practice":
		var hints := CheckBox.new()
		hints.text = tr("显示提示入口（尚无分析结果）")
		hints.button_pressed = pending_match_config.show_hints
		hints.toggled.connect(func(value: bool): pending_match_config.show_hints = value; profile.settings.show_hints = value; _save_profile())
		box.add_child(hints)
	if in_match:
		var pause_button := _command_button(GameLocalization.present("继续游戏") if paused else GameLocalization.present("暂停游戏"), COLOR_ACTION, _white_color())
		pause_button.name = "PauseToggleButton"
		pause_button.custom_minimum_size = Vector2(0, 36)
		pause_button.pressed.connect(func():
			popup.hide()
			_toggle_pause()
		)
		box.add_child(pause_button)
	var close_button := _command_button(GameLocalization.present("关闭"), COLOR_ACTION, _white_color())
	close_button.custom_minimum_size = Vector2(0, 36)
	close_button.pressed.connect(func():
		popup.hide()
		if in_match: _render_table())
	box.add_child(close_button)
	return panel

func _language_row(popup: PopupPanel, in_match: bool) -> Control:
	var options := OptionButton.new()
	options.name = "LanguageOptions"
	options.add_item(GameLocalizationScript.choice_label(GameLocalizationScript.SYSTEM), 0)
	options.add_item(GameLocalizationScript.choice_label(GameLocalizationScript.ZH_CN), 1)
	options.add_item(GameLocalizationScript.choice_label(GameLocalizationScript.EN), 2)
	var current := GameLocalizationScript.normalize_choice(profile.settings.get("language", GameLocalizationScript.SYSTEM))
	options.select({GameLocalizationScript.SYSTEM: 0, GameLocalizationScript.ZH_CN: 1, GameLocalizationScript.EN: 2}.get(current, 0))
	_apply_field_style(options)
	options.item_selected.connect(func(index: int):
		var choices := [GameLocalizationScript.SYSTEM, GameLocalizationScript.ZH_CN, GameLocalizationScript.EN]
		profile.settings.language = GameLocalizationScript.apply_choice(choices[index])
		_save_profile()
		popup.hide()
		if in_match: _render_table()
		else: _show_menu(false))
	return _menu_row(GameLocalization.present("语言 / Language"), options)

func _stats_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = tr("旧版历史汇总（无法追溯）")
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
		stats_label.text = tr("总手数 %d · 胜手 %d\n净盈利 %d · 最大单手 +%d") % [
			int(profile.stats.total_hands),
			int(profile.stats.total_win_hands),
			int(profile.stats.total_net_profit),
			int(profile.stats.max_single_hand_win)
		]
	if stats_reset_button:
		var color := COLOR_DANGER if stats_reset_pending else COLOR_ACTION
		stats_reset_button.text = tr("再次点击确认" if stats_reset_pending else GameLocalization.present("重置历史汇总"))
		_apply_command_button_style(stats_reset_button, color)

func _menu_row(label_text: String, field: Control, centered: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	if centered:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := Label.new()
	label.text = tr(label_text)
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
		_apply_command_button_style(field, COLOR_ACTION)
		var line_edit := (field as SpinBox).get_line_edit()
		line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_edit.add_theme_color_override("font_color", _white_color())
		line_edit.add_theme_color_override("caret_color", COLOR_BRASS)
		line_edit.add_theme_font_size_override("font_size", FONT_LABEL)
		line_edit.add_theme_stylebox_override("normal", _field_style(COLOR_SLOT, _edge_color()))
		line_edit.add_theme_stylebox_override("focus", _field_style(COLOR_SLOT.lightened(0.04), COLOR_BRASS, true))
	else:
		_apply_command_button_style(field, COLOR_ACTION)

func _on_start_pressed() -> void:
	_invalidate_ai_turn()
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
	last_recorded_hand_number = 0
	last_seen_event_fingerprint = ""
	last_rendered_pot = -1
	log_open = false
	paused = false
	raise_expanded = false
	pending_match_config.ai_count = int(ai_count_spin.value)
	pending_match_config.difficulty = difficulty
	pending_match_config.mode = current_mode
	pending_match_config = MatchConfig.normalize(pending_match_config)
	for key in pending_match_config:
		profile.settings[key] = pending_match_config[key]
	_save_profile()
	_match_open = true
	_auto_next_elapsed = 0.0
	_start_game_with_config(pending_match_config)
	_play_sound(420.0, 0.08)
	_render_table()

func _start_game_with_config(options: Dictionary) -> void:
	game.start_new_match(int(options.get("ai_count", 3)), str(options.get("difficulty", "medium")), options.duplicate(true))

func _open_mode(mode: String) -> void:
	if mode == "tutorial":
		_show_tutorial_home()
		return
	_show_mode_config(mode)

func _show_mode_config(mode: String) -> void:
	current_mode = mode
	pending_match_config.mode = mode
	pending_match_config = MatchConfig.normalize(pending_match_config)
	_clear()
	add_child(_background(MENU_BACKGROUND_TEXTURE, Color(0.008, 0.018, 0.016, 0.48)))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "ModeConfigPanel"
	panel.custom_minimum_size = Vector2(620, 500)
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, COLOR_BRASS.darkened(0.3), 2, 2, Vector2(24, 18)))
	center.add_child(panel)
	mode_config_panel = panel
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(570, 460)
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	scroll.add_child(box)
	var title := Label.new()
	title.text = tr("新手教程" if mode == "tutorial" else (GameLocalization.present("练习对局配置") if mode == "practice" else GameLocalization.present("自由对战配置")))
	title.add_theme_font_size_override("font_size", FONT_DISPLAY)
	title.add_theme_color_override("font_color", COLOR_BRASS)
	box.add_child(title)
	box.add_child(_config_row(GameLocalization.present("AI 对手"), _build_ai_spin()))
	box.add_child(_config_row(GameLocalization.present("难度"), _build_difficulty_options()))
	var stack := OptionButton.new()
	stack.name = "InitialStackOptions"
	for stack_value in MatchConfig.STACKS:
		stack.add_item(GameLocalization.present("%d 筹码") % int(stack_value), int(stack_value))
		if int(pending_match_config.get("initial_stack", 1000)) == int(stack_value): stack.select(stack.item_count - 1)
	_apply_field_style(stack)
	box.add_child(_config_row(GameLocalization.present("初始筹码"), stack))
	var blind := OptionButton.new()
	blind.name = "BlindOptions"
	for item in [[5,10],[10,20],[25,50],[50,100]]:
		blind.add_item("%d / %d" % item, item[1])
		if int(pending_match_config.get("big_blind", 20)) == item[1]: blind.select(blind.item_count - 1)
	_apply_field_style(blind)
	box.add_child(_config_row(GameLocalization.present("大小盲"), blind))
	if mode == "practice":
		var hints := CheckBox.new()
		hints.name = "ShowHintsToggle"
		hints.text = tr("显示提示入口（本地教练尚不可用）")
		hints.button_pressed = bool(pending_match_config.get("show_hints", false))
		hints.add_theme_color_override("font_color", _white_color())
		hints.toggled.connect(func(value): pending_match_config.show_hints = value)
		box.add_child(hints)
		var pause_hand := CheckBox.new()
		pause_hand.name = "PauseEachHandToggle"
		pause_hand.text = GameLocalization.present("每手结束时暂停复盘")
		pause_hand.button_pressed = bool(pending_match_config.get("pause_each_hand", true))
		pause_hand.add_theme_color_override("font_color", _white_color())
		pause_hand.toggled.connect(func(value): pending_match_config.pause_each_hand = value)
		box.add_child(pause_hand)
	mode_config_notice = Label.new()
	mode_config_notice.name = "ModeConfigNotice"
	mode_config_notice.add_theme_color_override("font_color", _muted_color())
	mode_config_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(mode_config_notice)
	_update_config_notice()
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var start := _command_button(GameLocalization.present("开始"), COLOR_BRASS, _ink_color())
	start.name = "ConfigStartButton"
	start.custom_minimum_size = Vector2(180, 42)
	start.pressed.connect(func():
		pending_match_config.initial_stack = stack.get_selected_id()
		var blind_index := blind.get_selected_id()
		pending_match_config.big_blind = blind_index
		pending_match_config.small_blind = 5 if blind_index == 10 else (10 if blind_index == 20 else (25 if blind_index == 50 else 50))
		if _validate_match_config(pending_match_config):
			_on_start_pressed()
	)
	stack.item_selected.connect(func(index):
		pending_match_config.initial_stack = stack.get_item_id(index)
		_update_config_notice())
	blind.item_selected.connect(func(index):
		var selected_pair: Array = MatchConfig.BLINDS[index]
		pending_match_config.small_blind = selected_pair[0]
		pending_match_config.big_blind = selected_pair[1]
		_update_config_notice()
	)
	ai_count_spin.value_changed.connect(func(value): pending_match_config.ai_count = int(value))
	difficulty_options.item_selected.connect(func(index): pending_match_config.difficulty = ["simple", "medium", "hard"][index])
	actions.add_child(start)
	var cancel := _command_button(GameLocalization.present("取消"), COLOR_ACTION, _white_color())
	cancel.name = "ConfigCancelButton"
	cancel.custom_minimum_size = Vector2(140, 42)
	cancel.pressed.connect(_show_menu)
	actions.add_child(cancel)
	box.add_child(actions)

func _config_row(label_text: String, field: Control) -> Control:
	return _menu_row(label_text, field)

func _validate_match_config(config: Dictionary) -> bool:
	if not MatchConfig.validate(config):
		if mode_config_notice:
			mode_config_notice.text = tr("配置无效：请选择支持的 AI 数量、筹码和大小盲。")
		return false
	var valid := int(config.get("ai_count", 0)) >= 1 and int(config.get("ai_count", 0)) <= 5
	valid = valid and int(config.get("initial_stack", 0)) >= 1000
	valid = valid and int(config.get("small_blind", 0)) > 0 and int(config.get("small_blind", 0)) < int(config.get("big_blind", 0))
	if not valid and mode_config_notice:
		mode_config_notice.text = tr("配置无效：请选择 1–5 名 AI、合法筹码和大小盲。")
	return valid

func _update_config_notice() -> void:
	if not is_instance_valid(mode_config_notice): return
	mode_config_notice.text = tr("%d 筹码 · %d/%d 盲注 · %.0f BB\nBB 是大盲单位。本场盲注固定，可免费重开。不同筹码尺度的 AI 表现仍待专项验证。") % [pending_match_config.initial_stack,pending_match_config.small_blind,pending_match_config.big_blind,float(pending_match_config.initial_stack)/pending_match_config.big_blind]

func _show_tutorial_home() -> void:
	practice_views.tutorial_home()

func _open_tutorial_lesson(lesson_id: String) -> void:
	practice_views.open_lesson(lesson_id)

func _open_home_secondary(section: String) -> void:
	if section == "history": _show_history_view()
	else: _show_stats_view()

func _show_history_view() -> void:
	practice_views.history()

func _show_stats_view() -> void:
	practice_views.stats()

func _show_replay_view(record: Dictionary) -> void:
	practice_views.open_replay(record,_in_match())

func _render_table() -> void:
	_record_completed_hand_if_needed()
	_clear()
	add_child(_background(MENU_BACKGROUND_TEXTURE, Color(0.005, 0.014, 0.012, 0.76)))

	var root := Control.new()
	root.name = "TableSceneRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var table := _build_table_shell()
	table.anchor_left = 0.105
	table.anchor_top = 0.045
	table.anchor_right = 0.895
	table.anchor_bottom = 0.955
	root.add_child(table)
	root.add_child(_build_floating_status())
	root.add_child(_build_utility_buttons())
	root.add_child(_build_action_dock())
	if log_open:
		root.add_child(_build_log_drawer())
	if paused:
		root.add_child(_build_pause_overlay())

func _build_floating_status() -> Control:
	var panel := PanelContainer.new()
	panel.name = "FloatingStatus"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 24
	panel.offset_top = 20
	panel.offset_right = 292
	panel.offset_bottom = 80
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, COLOR_BRASS.darkened(0.32), 2, 1, Vector2(12, 7)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)
	var title := Label.new()
	title.name = "FloatingStatusTitle"
	title.text = tr("第 %d 手 · %s") % [game.hand_number, _stage_label(game.stage)]
	title.add_theme_color_override("font_color", COLOR_BRASS)
	title.add_theme_font_size_override("font_size", FONT_BUTTON)
	box.add_child(title)
	var detail := Label.new()
	detail.name = "FloatingStatusDetail"
	detail.text = _status_detail()
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.add_theme_color_override("font_color", _white_color() if game.is_human_turn() else _muted_color())
	detail.add_theme_font_size_override("font_size", FONT_CAPTION)
	box.add_child(detail)
	return panel

func _status_detail() -> String:
	if game.is_human_turn():
		return GameLocalization.present("轮到你行动")
	var events := game.recent_events(1)
	if not events.is_empty():
		return _event_log_text(str(events[0].text))
	return _status_message()

func _build_utility_buttons() -> Control:
	var row := HBoxContainer.new()
	row.name = "UtilityButtons"
	row.anchor_left = 1.0
	row.anchor_top = 0.0
	row.anchor_right = 1.0
	row.anchor_bottom = 0.0
	row.offset_left = -224
	row.offset_top = 20
	row.offset_right = -24
	row.offset_bottom = 60
	row.add_theme_constant_override("separation", 8)
	var log_button := _command_button(GameLocalization.present("记录"), COLOR_ACTION, _white_color())
	log_button.name = "LogButton"
	log_button.custom_minimum_size = Vector2(96, 40)
	log_button.pressed.connect(_toggle_log)
	if _has_unread_log():
		var unread := Label.new()
		unread.name = "LogUnreadDot"
		unread.text = "●"
		unread.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unread.add_theme_color_override("font_color", COLOR_DANGER.lightened(0.15))
		unread.add_theme_font_size_override("font_size", FONT_CAPTION)
		unread.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		unread.offset_left = -17
		unread.offset_top = 2
		unread.offset_right = -3
		unread.offset_bottom = 18
		unread.mouse_filter = Control.MOUSE_FILTER_IGNORE
		log_button.add_child(unread)
	row.add_child(log_button)
	var settings := _command_button(GameLocalization.present("设置"), COLOR_ACTION, _white_color())
	settings.name = "SettingsButton"
	settings.custom_minimum_size = Vector2(96, 40)
	settings.pressed.connect(_show_settings_popup)
	row.add_child(settings)
	if current_mode == "practice" and bool(pending_match_config.show_hints):
		row.offset_left = -328
		var hint := _command_button(GameLocalization.present("提示"), COLOR_ACTION, _white_color())
		hint.name = "PracticeHintsButton"
		hint.custom_minimum_size = Vector2(96, 40)
		hint.pressed.connect(_show_analysis_unavailable)
		row.add_child(hint)
	return row

func _show_analysis_unavailable() -> void:
	var popup := _show_text_popup(GameLocalization.present("实时提示暂不可用"), GameLocalization.present("本地教练尚未接入，当前没有建议或胜率。打开此面板不会计作使用实时辅助，也不改变发牌或对手行为。"), "AnalysisUnavailablePanel")
	var retry := _command_button(GameLocalization.present("重试"), COLOR_ACTION, _white_color())
	retry.name = "AnalysisRetryButton"
	retry.pressed.connect(func(): popup.hide(); _show_analysis_unavailable())
	popup.get_child(0).add_child(retry)
	var toggle := _command_button(GameLocalization.present("隐藏提示入口"), COLOR_ACTION, _white_color())
	toggle.pressed.connect(func():
		pending_match_config.show_hints = false
		profile.settings.show_hints = false
		_save_profile()
		popup.hide()
		_render_table())
	popup.get_child(0).add_child(toggle)

func _toggle_log() -> void:
	log_open = not log_open
	if log_open:
		last_seen_event_fingerprint = _event_fingerprint()
	_render_table()

func _build_log_drawer() -> Control:
	var drawer := PanelContainer.new()
	drawer.name = "LogDrawer"
	drawer.anchor_left = 1.0
	drawer.anchor_top = 0.0
	drawer.anchor_right = 1.0
	drawer.anchor_bottom = 1.0
	drawer.offset_left = -424
	drawer.offset_top = 72
	drawer.offset_right = -24
	drawer.offset_bottom = -24
	drawer.z_index = 50
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	drawer.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, COLOR_BRASS.darkened(0.25), 2, 2, Vector2(16, 14)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	drawer.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var title := Label.new()
	title.text = tr("牌局记录")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", COLOR_BRASS)
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)
	var close := _command_button(GameLocalization.present("关闭"), COLOR_ACTION, _white_color())
	close.name = "LogCloseButton"
	close.custom_minimum_size = Vector2(72, 34)
	close.pressed.connect(_toggle_log)
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for event in game.recent_events(40):
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "> %s" % _event_log_text(str(event.text))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", _muted_color())
		label.add_theme_font_size_override("font_size", 14)
		list.add_child(label)
	return drawer

func _in_match() -> bool:
	return find_child("TableSceneRoot", true, false) != null

func _toggle_pause() -> void:
	if not _in_match():
		return
	paused = not paused
	if paused:
		log_open = false
	raise_expanded = false
	_render_table()

func _build_pause_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.name = "PauseOverlay"
	overlay.color = Color(0.004, 0.010, 0.009, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, COLOR_BRASS.darkened(0.32), 2, 2, Vector2(26, 18)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = tr("已暂停")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_BRASS)
	title.add_theme_font_size_override("font_size", FONT_DISPLAY)
	box.add_child(title)
	var resume_button := _command_button(GameLocalization.present("继续游戏"), COLOR_BRASS, _ink_color())
	resume_button.name = "PauseResumeButton"
	resume_button.custom_minimum_size = Vector2(160, 40)
	resume_button.pressed.connect(_toggle_pause)
	box.add_child(resume_button)
	var quit_button := _command_button(GameLocalization.present("返回菜单"), COLOR_ACTION, _white_color())
	quit_button.name = "PauseQuitButton"
	quit_button.custom_minimum_size = Vector2(160, 40)
	quit_button.pressed.connect(func(): _confirm_leave(false))
	box.add_child(quit_button)
	return overlay

func _build_table_shell() -> Control:
	var stage := AspectRatioContainer.new()
	stage.name = "TableStage"
	stage.ratio = TABLE_ASPECT
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	var felt_safe_zone := Control.new()
	felt_safe_zone.name = "TableFeltSafeZone"
	felt_safe_zone.anchor_left = 0.145
	felt_safe_zone.anchor_top = 0.205
	felt_safe_zone.anchor_right = 0.855
	felt_safe_zone.anchor_bottom = 0.795
	felt_safe_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table_root.add_child(felt_safe_zone)

	table_root.add_child(_build_pot_instrument())
	var seat_order: Array = _seat_order_for_player_count(game.players.size())
	for player_index in range(game.players.size()):
		if player_index >= seat_order.size():
			break
		var seat_index := int(seat_order[player_index])
		var layout: Dictionary = SEAT_LAYOUTS[seat_index]
		table_root.add_child(_seat_portrait(player_index, layout))
		table_root.add_child(_seat_info(player_index, layout))
		table_root.add_child(_seat_nameplate(player_index, layout))
		var current_marker := _seat_current_marker(player_index, layout)
		if current_marker != null:
			table_root.add_child(current_marker)
	if _last_event_type() == "street":
		_pulse_control(stage, COLOR_BRASS)
	return stage

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

func _seat_portrait(player_index: int, layout: Dictionary) -> Control:
	var player: Dictionary = game.players[player_index]
	var height_frac: float = layout.portrait_h
	var width_frac := height_frac * _character_cell_aspect(player_index) / TABLE_ASPECT
	var frame := Control.new()
	frame.name = "Seat%dPortrait" % player_index
	_stage_place(frame, layout.portrait, Vector2(width_frac, height_frac))
	var texture_index := clampi(player_index, 0, CHARACTER_TEXTURES.size() - 1)
	var texture: Texture2D = CHARACTER_TEXTURES[texture_index]
	var cell_width := float(texture.get_width()) / 4.0
	var region := Rect2(cell_width * clampi(_avatar_state(player_index), 0, 3), 0, cell_width, texture.get_height())
	var sprite := _texture_rect(_atlas_texture(texture, region), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(sprite)
	var outline_state := _portrait_outline_state(player_index)
	if not outline_state.is_empty():
		var material := ShaderMaterial.new()
		material.shader = PORTRAIT_OUTLINE_SHADER
		material.set_shader_parameter("source_texel", Vector2(1.0 / float(texture.get_width()), 1.0 / float(texture.get_height())))
		material.set_shader_parameter("outline_color", outline_state.color)
		material.set_shader_parameter("outline_alpha", 0.9)
		sprite.material = material
		if bool(outline_state.current):
			var tween := create_tween().bind_node(sprite).set_loops()
			tween.tween_method(func(alpha: float): material.set_shader_parameter("outline_alpha", alpha), 0.58, 1.0, 0.75)
			tween.tween_method(func(alpha: float): material.set_shader_parameter("outline_alpha", alpha), 1.0, 0.58, 0.75)
	match str(player.status):
		TableState.STATUS_FOLDED:
			sprite.modulate = Color(0.45, 0.47, 0.44)
		TableState.STATUS_OUT:
			sprite.modulate = Color(0.30, 0.32, 0.30)
	return frame

func _seat_current_marker(player_index: int, layout: Dictionary) -> Control:
	if player_index != game.current_player_index or game.stage == TableState.STAGE_HAND_OVER:
		return null
	var holder := CenterContainer.new()
	holder.name = "Seat%dCurrentMarker" % player_index
	var portrait_position: Vector2 = layout.portrait
	var vertical_offset := 0.09 if portrait_position.y > 0.75 else 0.11
	_stage_place_centered(holder, Vector2(portrait_position.x, portrait_position.y - vertical_offset))
	holder.z_as_relative = false
	holder.z_index = 5
	var marker := Label.new()
	marker.text = "▼"
	marker.custom_minimum_size = Vector2(28, 22)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_color_override("font_color", COLOR_BRASS)
	marker.add_theme_color_override("font_outline_color", COLOR_DEEP)
	marker.add_theme_constant_override("outline_size", 3)
	marker.add_theme_font_size_override("font_size", FONT_TITLE)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(marker)
	return holder

func _portrait_outline_state(player_index: int) -> Dictionary:
	var player: Dictionary = game.players[player_index]
	var is_current := player_index == game.current_player_index and game.stage != TableState.STAGE_HAND_OVER
	var is_winner := false
	if game.stage == TableState.STAGE_HAND_OVER:
		for win in game.winners:
			if int(win.player_index) == player_index:
				is_winner = true
	if is_winner:
		return {"color": COLOR_BRASS.lightened(0.14), "current": false}
	if player.status == TableState.STATUS_ALL_IN:
		return {"color": COLOR_DANGER.lightened(0.08), "current": false}
	if is_current:
		return {"color": COLOR_BRASS, "current": true}
	return {}

func _seat_info(player_index: int, layout: Dictionary) -> Control:
	var player: Dictionary = game.players[player_index]
	var holder := CenterContainer.new()
	holder.name = "Seat%dInfo" % player_index
	_stage_place_centered(holder, layout.info)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	holder.add_child(box)
	var cards := HBoxContainer.new()
	cards.name = "Seat%dHoleCards" % player_index
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 3)
	if player.status != TableState.STATUS_FOLDED and player.status != TableState.STATUS_OUT:
		var reveal := bool(player.is_human) or game.stage == TableState.STAGE_HAND_OVER
		for card in player.hole_cards:
			cards.add_child(_card_view(card, reveal, true))
	box.add_child(cards)
	var resources := HBoxContainer.new()
	resources.alignment = BoxContainer.ALIGNMENT_CENTER
	resources.add_theme_constant_override("separation", 5)
	var stack_chips := _chip_stack_view(int(player.stack), 2, 5, 1)
	stack_chips.name = "Seat%dStackChips" % player_index
	resources.add_child(stack_chips)
	var stack_label := Label.new()
	stack_label.name = "Seat%dStackAmount" % player_index
	stack_label.text = str(int(player.stack))
	stack_label.add_theme_color_override("font_color", _white_color())
	stack_label.add_theme_font_size_override("font_size", FONT_CAPTION)
	resources.add_child(stack_label)
	var roles := HBoxContainer.new()
	roles.name = "Seat%dRoleMarkers" % player_index
	roles.add_theme_constant_override("separation", 2)
	for role in _role_markers(player_index):
		roles.add_child(_role_marker(player_index, role))
	resources.add_child(roles)
	box.add_child(resources)
	var bet := int(player.current_bet)
	var last_action := str(player.last_action)
	if bet > 0 or not last_action.is_empty():
		var bet_holder := CenterContainer.new()
		bet_holder.name = "Seat%dBet" % player_index
		if not last_action.is_empty():
			bet_holder.add_child(_action_tag(player_index, last_action, bet, layout.portrait.y > layout.info.y))
		else:
			bet_holder.add_child(_chip_stack_view(bet, 2, 3, 1))
		box.add_child(bet_holder)
	return holder

func _role_markers(player_index: int) -> Array:
	var roles: Array = []
	if player_index == game.button_index:
		roles.append({"key": "Dealer", "text": "D", "atlas_index": 0})
	if player_index == game.small_blind_player_index:
		roles.append({"key": "SmallBlind", "text": "SB" if TranslationServer.get_locale().begins_with("en") else "小盲", "atlas_index": 1})
	if player_index == game.big_blind_player_index:
		roles.append({"key": "BigBlind", "text": "BB" if TranslationServer.get_locale().begins_with("en") else "大盲", "atlas_index": 4})
	return roles

func _role_marker(player_index: int, role: Dictionary) -> Control:
	var marker := Control.new()
	marker.name = "Seat%d%s" % [player_index, str(role.key)]
	marker.custom_minimum_size = Vector2(48, 24)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := _texture_rect(_atlas_texture(CHIP_MODULES_TEXTURE, Rect2(int(role.atlas_index) * 32 + 4, 4, 24, 12)), TextureRect.STRETCH_SCALE)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	marker.add_child(art)
	var label := Label.new()
	label.text = str(role.text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", _ink_color() if int(role.atlas_index) != 4 else COLOR_CARD)
	label.add_theme_font_size_override("font_size", FONT_CAPTION)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(label)
	return marker

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
	var tag := Control.new()
	tag.custom_minimum_size = Vector2(96, 24)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := 0 if tail_down else 1
	var art := _texture_rect(_atlas_texture(ACTION_TAGS_TEXTURE, Rect2(col * 104 + 4, row * 32 + 4, 96, 24)), TextureRect.STRETCH_SCALE)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(art)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", FONT_CAPTION)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(label)
	return tag

func _seat_nameplate(player_index: int, layout: Dictionary) -> Control:
	var player: Dictionary = game.players[player_index]
	var holder := CenterContainer.new()
	holder.name = "Seat%dPlate" % player_index
	_stage_place_centered(holder, layout.plate)
	var plate := Control.new()
	plate.custom_minimum_size = Vector2(110, 26)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(plate)
	var art := _texture_rect(_atlas_texture(SEAT_NAMEPLATES_TEXTURE, Rect2(4, 4, 110, 26)), TextureRect.STRETCH_SCALE)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(art)
	var label := Label.new()
	label.text = _nameplate_text(player_index)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.clip_text = true
	var font_color := _white_color()
	if player.status == TableState.STATUS_FOLDED or player.status == TableState.STATUS_OUT:
		font_color = _muted_color()
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_font_size_override("font_size", FONT_CAPTION)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return holder

func _nameplate_text(player_index: int) -> String:
	var player: Dictionary = game.players[player_index]
	var display_name := _seat_name(player_index)
	match str(player.status):
		TableState.STATUS_FOLDED:
			return "%s · %s" % [display_name, tr("已弃牌")]
		TableState.STATUS_ALL_IN:
			return "%s · %s" % [display_name, tr("全下")]
		TableState.STATUS_OUT:
			return "%s · %s" % [display_name, tr("出局")]
	return display_name

func _event_log_text(event_text: String) -> String:
	var compact_text := _localized_game_message(event_text)
	var chinese_parentheses := RegEx.new()
	chinese_parentheses.compile("（[^）]*）")
	compact_text = chinese_parentheses.sub(compact_text, "", true)
	var parentheses := RegEx.new()
	parentheses.compile("\\([^)]*\\)")
	return parentheses.sub(compact_text, "", true).strip_edges()

## PokerRound keeps Chinese messages for save/test compatibility.  Presentation
## localizes their stable sentence shapes here, without changing round state.
func _localized_game_message(message: String) -> String:
	return GameLocalizationScript.message(message)

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
	_stage_place_centered(cards_holder, Vector2(0.5, 0.450))
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 6)
	for card in game.community_cards:
		cards.add_child(_card_view(card, true, true))
	cards_holder.add_child(cards)
	overlay.add_child(cards_holder)

	var pot_holder := CenterContainer.new()
	pot_holder.name = "PotDisplay"
	_stage_place_centered(pot_holder, Vector2(0.5, 0.555))
	var pot_box := VBoxContainer.new()
	pot_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pot_box.add_theme_constant_override("separation", 2)
	var chips := _chip_stack_view(game.total_pot(), 3, 8, 1)
	chips.name = "PotChips"
	chips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pot_box.add_child(chips)
	var amount_plate := PanelContainer.new()
	amount_plate.name = "PotAmountPlate"
	amount_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	amount_plate.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, COLOR_BRASS.darkened(0.18), 1, 1, Vector2(10, 3)))
	var amount := Label.new()
	amount.name = "PotAmount"
	amount.text = str(game.total_pot())
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_color_override("font_color", COLOR_BRASS)
	amount.add_theme_font_size_override("font_size", FONT_BUTTON)
	amount_plate.add_child(amount)
	pot_box.add_child(amount_plate)
	pot_holder.add_child(pot_box)
	overlay.add_child(pot_holder)
	if last_rendered_pot >= 0 and last_rendered_pot != game.total_pot():
		_pulse_control(amount_plate, COLOR_BRASS)
		chips.scale = Vector2(0.92, 0.92)
		create_tween().bind_node(chips).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(chips, "scale", Vector2.ONE, 0.22)
	last_rendered_pot = game.total_pot()
	return panel

func _chip_breakdown(amount: int) -> Array:
	var result: Array = []
	var remaining := maxi(0, amount)
	var values := [500, 100, 25, 5, 1]
	var atlas_indices := [4, 3, 2, 1, 0]
	for index in range(values.size()):
		var count := remaining / int(values[index])
		if count > 0:
			result.append({"denomination": int(values[index]), "count": count, "atlas_index": int(atlas_indices[index])})
			remaining %= int(values[index])
	return result

func _chip_stack_view(amount: int, max_columns: int, max_layers: int, pixel_scale: int) -> Control:
	var chips := ChipStackViewScript.new()
	chips.configure(CHIP_MODULES_TEXTURE, _chip_breakdown(amount), max_columns, max_layers, pixel_scale)
	return chips

func _build_action_dock() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ActionDock"
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	var dock_width := 580 if game.stage == TableState.STAGE_HAND_OVER else 372
	var dock_height := _result_dock_height() if game.stage == TableState.STAGE_HAND_OVER else (110 if raise_expanded and game.is_human_turn() else 60)
	panel.offset_left = -dock_width - 24
	panel.offset_top = -dock_height - 20
	panel.offset_right = -24
	panel.offset_bottom = -20
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, _edge_color(), 2, 1, Vector2(10, 9)))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	if game.stage == TableState.STAGE_HAND_OVER:
		box.add_child(_result_panel())
		return panel
	if not game.is_human_turn():
		var waiting := Label.new()
		waiting.text = tr("等待 AI…")
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
	actions_row.add_theme_constant_override("separation", 6)
	box.add_child(actions_row)

	_add_action_button(actions_row, GameLocalization.present("弃牌"), TableState.ACTION_FOLD, legal, COLOR_DANGER)
	_add_action_button(actions_row, GameLocalization.present("让牌"), TableState.ACTION_CHECK, legal, COLOR_ACTION)
	_add_action_button(actions_row, "%s %d" % [tr("跟注"), mini(game.get_to_call(0), int(game.players[0].stack))], TableState.ACTION_CALL, legal, COLOR_ACTION)
	_add_action_button(actions_row, GameLocalization.present("全下"), TableState.ACTION_ALL_IN, legal, COLOR_DANGER)

	if legal.actions.has(TableState.ACTION_RAISE):
		var expand_button := _command_button(GameLocalization.present("加注"), COLOR_BRASS, _ink_color())
		expand_button.name = "RaiseExpandButton"
		expand_button.custom_minimum_size = Vector2(68, 38)
		expand_button.pressed.connect(func():
			raise_expanded = not raise_expanded
			_render_table()
		)
		actions_row.add_child(expand_button)
	if raise_expanded and legal.actions.has(TableState.ACTION_RAISE):
		var raise_row := HBoxContainer.new()
		raise_row.alignment = BoxContainer.ALIGNMENT_CENTER
		raise_row.add_theme_constant_override("separation", 6)
		box.add_child(raise_row)
		var decrease_button := _raise_step_button("-")
		decrease_button.pressed.connect(func(): _change_raise_by_step(-1))
		raise_row.add_child(decrease_button)
		raise_slider = HSlider.new()
		raise_slider.min_value = legal.min_raise_to
		raise_slider.max_value = legal.max_raise_to
		raise_slider.step = game.big_blind
		raise_slider.value = legal.min_raise_to
		raise_slider.custom_minimum_size = Vector2(176, 32)
		raise_slider.add_theme_stylebox_override("slider", _panel_style(COLOR_SLOT, _edge_color().darkened(0.30), 1, 2, Vector2(0, 0)))
		raise_slider.add_theme_stylebox_override("grabber_area", _panel_style(COLOR_BRASS, COLOR_BRASS.darkened(0.30), 1, 2, Vector2(0, 0)))
		raise_slider.value_changed.connect(_on_raise_slider_changed)
		raise_row.add_child(raise_slider)
		var increase_button := _raise_step_button("+")
		increase_button.pressed.connect(func(): _change_raise_by_step(1))
		raise_row.add_child(increase_button)
		raise_button = _command_button(GameLocalization.present("加注到"), COLOR_BRASS, _ink_color())
		raise_button.custom_minimum_size = Vector2(96, 36)
		raise_button.pressed.connect(func(): _on_action(TableState.ACTION_RAISE, int(raise_slider.value)))
		raise_row.add_child(raise_button)
		_on_raise_slider_changed(raise_slider.value)
	return panel

func _result_dock_height() -> int:
	var payout_players: Dictionary = {}
	for win in game.winners:
		payout_players[int(win.player_index)] = true
	var row_count := payout_players.size()
	if game.match_over and not game.match_summary.is_empty():
		row_count += 1
	return maxi(148, 120 + row_count * 22) + (44 if not _pending_records.is_empty() or not _pending_matches.is_empty() else 0)

func _result_panel() -> Control:
	# Vertical stacking keeps every line within the fixed 580px dock width,
	# even on the match-over screen with the summary and payout lines.
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = _status_message()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_BRASS)
	title.add_theme_font_size_override("font_size", FONT_BUTTON)
	column.add_child(title)
	if game.match_over and not game.match_summary.is_empty():
		var summary := Label.new()
		summary.text = tr("总手数 %d · 最终筹码 %d · 净盈利 %d · 最大单手 +%d") % [
			int(game.match_summary.hands),
			int(game.match_summary.final_stack),
			int(game.match_summary.net_profit),
			int(game.match_summary.max_single_hand_win)
		]
		summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		summary.add_theme_color_override("font_color", _white_color())
		summary.add_theme_font_size_override("font_size", FONT_SMALL)
		column.add_child(summary)
	var payouts: Dictionary = {}
	var payout_order: Array[int] = []
	for win in game.winners:
		var player_index := int(win.player_index)
		if not payouts.has(player_index):
			payouts[player_index] = {"amount": 0, "rank_name": str(win.rank_name)}
			payout_order.append(player_index)
		payouts[player_index].amount += int(win.amount)
	for player_index in payout_order:
		var payout: Dictionary = payouts[player_index]
		var win_label := Label.new()
		win_label.text = "%s +%d (%s)" % [_seat_name(player_index), int(payout.amount), tr(str(payout.rank_name))]
		win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		win_label.add_theme_color_override("font_color", _white_color())
		win_label.add_theme_font_size_override("font_size", FONT_SMALL)
		column.add_child(win_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	if current_mode == "practice" or current_mode == "free":
		var replay := _command_button(GameLocalization.present("复盘本手"), COLOR_ACTION, _white_color())
		replay.name = "ReplayCurrentHandButton"
		replay.pressed.connect(func(): _show_replay_view(game.completed_hand_record()))
		buttons.add_child(replay)
	if game.players[0].stack > 0 and not game.match_over:
		var next_button := _command_button(GameLocalization.present("下一手"), COLOR_BRASS, _ink_color())
		next_button.pressed.connect(_next_hand)
		buttons.add_child(next_button)
	var restart_button := _command_button(GameLocalization.present("重新开始"), COLOR_ACTION, _white_color())
	restart_button.pressed.connect(func(): _confirm_leave(false))
	buttons.add_child(restart_button)
	column.add_child(buttons)
	var save_label := Label.new()
	save_label.text = tr("本手牌谱已保存" if _pending_records.is_empty() else GameLocalization.present("牌谱未保存，可重试或清理旧牌谱"))
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_label.add_theme_font_size_override("font_size", FONT_SMALL)
	column.add_child(save_label)
	if not _pending_records.is_empty() or not _pending_matches.is_empty():
		var retry := _command_button(GameLocalization.present("重试保存"), COLOR_ACTION, _white_color())
		retry.name = "PracticeSaveRetry"
		retry.pressed.connect(func(): _retry_practice_saves(); _render_table())
		column.add_child(retry)
	return column

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
	button.custom_minimum_size = Vector2(94 if action == TableState.ACTION_CALL else 72, 38)
	button.pressed.connect(func(): _on_action(action, 0))
	parent.add_child(button)

func _command_button(label: String, color: Color, text_color: Color) -> Button:
	var button := Button.new()
	button.text = tr(label)
	button.pressed.connect(func(): _play_effect("deal"))
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
	button.tooltip_text = tr("按最小单位调整加注")
	return button

func _change_raise_by_step(direction: int) -> void:
	if raise_slider == null:
		return
	var step_amount := maxi(1, int(raise_slider.step))
	var next_value := int(raise_slider.value) + direction * step_amount
	raise_slider.value = clampi(next_value, int(raise_slider.min_value), int(raise_slider.max_value))

func _on_raise_slider_changed(value: float) -> void:
	if raise_button:
		raise_button.text = "%s %d" % [tr("加注到"), int(value)]

func _on_sound_toggled(enabled: bool) -> void:
	profile.settings.sound_enabled = enabled
	if is_instance_valid(sound_player): sound_player.apply_settings(profile.settings)
	_save_profile()

func _on_pace_toggled(enabled: bool) -> void:
	profile.settings.fast_mode = enabled
	_save_profile()

func _on_reset_stats_pressed() -> void:
	if not stats_reset_pending:
		stats_reset_pending = true
		_refresh_stats_panel()
		return
	if not practice_store.reset_legacy():
		_show_text_popup(GameLocalization.present("未能重置"),practice_store.notice,"ResetLegacyError")
		return
	profile = LocalProfileScript.reset_stats(profile)
	_save_profile()
	stats_reset_pending = false
	_refresh_stats_panel()

func _on_action(action: String, amount: int) -> void:
	if not _ai_can_advance() or not game.is_human_turn():
		return
	if not game.apply_action(action, amount):
		return
	raise_expanded = false
	_play_action_sound(action)
	_render_table()

func _run_ai_turn() -> void:
	_ai_request = {"epoch": _ai_epoch, "hand": game.hand_number, "actor": game.current_player_index, "stage": game.stage}
	_ai_wait = _ai_action_delay(game.players[game.current_player_index])
	_ai_result = {}
	var error := _ai_worker.start(game, game.current_player_index)
	if error != OK:
		paused = true
		_render_table()
		_show_text_popup(GameLocalization.present("AI 暂停"), GameLocalization.present("AI 计算未能启动。关闭提示后，点击继续游戏重试。"), "AiErrorPopup")
		return
	ai_pending = true

func _execute_ai_turn_if_allowed() -> bool:
	if not _ai_can_advance() or not game.is_ai_turn() or not _ai_request_is_current() or _ai_result.is_empty():
		return false
	var action := str(_ai_result.get("action_type", ""))
	if not game.apply_action(action, int(_ai_result.get("amount", 0)), str(_ai_result.get("decision_label", ""))):
		_ai_result = {}
		ai_pending = false
		return false
	_play_action_sound(action)
	return true

func _ai_can_advance() -> bool:
	return _in_match() and not paused and not log_open and not _has_visible_popup(self)

func _has_visible_popup(node: Node) -> bool:
	for child in node.get_children():
		if child is Popup and (child as Popup).visible:
			return true
		if _has_visible_popup(child):
			return true
	return false

func _event_fingerprint() -> String:
	if game.event_log.is_empty():
		return ""
	var event: Dictionary = game.event_log[game.event_log.size() - 1]
	return "%d|%s|%s" % [int(event.get("hand", game.hand_number)), str(event.get("type", "")), str(event.get("text", ""))]

func _has_unread_log() -> bool:
	var current := _event_fingerprint()
	return not log_open and not current.is_empty() and current != last_seen_event_fingerprint

func _ai_action_delay(player: Dictionary) -> float:
	if bool(profile.settings.fast_mode):
		return randf_range(0.25, 0.55)
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
	var record := game.completed_hand_record()
	if record.is_empty() or _submitted_hands.has(record.id): return
	_submitted_hands[record.id] = true
	_play_effect("settle")
	last_recorded_hand_number = game.hand_number
	_pending_records[record.id] = record
	_auto_next_elapsed = 0.0
	_retry_practice_saves()
	if game.match_over: _record_match_outcome()

func _retry_practice_saves() -> void:
	_practice_save_error = ""
	for id in _pending_records.keys():
		if practice_store.commit_hand(_pending_records[id]):
			_pending_records.erase(id)
		else:
			_practice_save_error = practice_store.notice
	for id in _pending_matches.keys():
		if _pending_match_has_records(id):
			continue
		var entry: Dictionary = _pending_matches[id]
		if practice_store.finish_match(id,entry.outcome,entry.config):
			_pending_matches.erase(id)
		else:
			_practice_save_error = practice_store.notice

func _pending_match_has_records(match_id: String) -> bool:
	for record in _pending_records.values():
		if str(record.get("match_id", "")) == match_id:
			return true
	return false

func _record_match_outcome() -> void:
	if game.match_id.is_empty(): return
	var outcome := "left"
	if game.match_over: outcome = "lost" if game.players[0].stack == 0 else "won"
	_pending_matches[game.match_id] = {"outcome":outcome,"config":game.match_config.duplicate(true)}
	_retry_practice_saves()

func _next_hand() -> void:
	if not _ai_can_advance() or game.stage != TableState.STAGE_HAND_OVER: return
	_auto_next_elapsed = 0.0
	game.start_next_hand()
	_play_sound(360.0, 0.06)
	_render_table()

func _setup_audio() -> void:
	sound_player = GameAudioScript.new()
	sound_player.apply_settings(profile.settings)
	add_child(sound_player)

func _audio_volume_control(key: String) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slider := HSlider.new()
	slider.name = "MusicVolume" if key == "music_volume" else "SoundVolume"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = float(profile.settings[key]) * 100.0
	slider.custom_minimum_size = Vector2(140, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 42
	value_label.text = "%d%%" % int(slider.value)
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float):
		profile.settings[key] = value / 100.0
		value_label.text = "%d%%" % int(value)
		if is_instance_valid(sound_player): sound_player.apply_settings(profile.settings)
		_save_profile())
	return row

func _play_effect(kind: String) -> void:
	if is_instance_valid(sound_player):
		sound_player.apply_settings(profile.settings)
		sound_player.play_effect(kind)

func _play_action_sound(action: String) -> void:
	match action:
		TableState.ACTION_FOLD: _play_effect("fold")
		TableState.ACTION_CHECK: _play_effect("deal")
		_: _play_effect("chip")

# Retain the probe-facing cue entry point; the cues now use local recordings.
func _play_sound(frequency: float, _duration: float) -> void:
	_play_effect("shuffle" if frequency >= 400.0 else "deal")

func _fade_in(control: CanvasItem, duration: float) -> void:
	if control == null:
		return
	control.modulate.a = 0.0
	var tween := create_tween().bind_node(control)
	tween.tween_property(control, "modulate:a", 1.0, clampf(duration, 0.08, 0.35))

func _pulse_control(control: CanvasItem, color: Color) -> void:
	if control == null:
		return
	control.modulate = color.lightened(0.10)
	var tween := create_tween().bind_node(control)
	tween.tween_property(control, "modulate", Color.WHITE, 0.18)

func _last_event_type() -> String:
	if game.event_log.is_empty():
		return ""
	return str(game.event_log[game.event_log.size() - 1].type)

func _atlas_texture(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
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
	return Color(0.690, 0.665, 0.555)

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
	style.anti_aliasing = false
	return style

func _button_style(bg: Color, outline_alpha: float) -> StyleBoxFlat:
	var border := COLOR_CARD.darkened(0.10) if outline_alpha > 0.0 else bg.lightened(0.12)
	var style := _panel_style(bg, border, 1, 2, Vector2(14, 8))
	style.shadow_color = Color(0.005, 0.012, 0.010, 0.72)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	if outline_alpha > 0.0:
		style.expand_margin_left = 2
		style.expand_margin_top = 2
		style.expand_margin_right = 2
		style.expand_margin_bottom = 2
	return style

func _apply_command_button_style(control: Control, color: Color) -> void:
	control.add_theme_stylebox_override("normal", _button_style(color, 0.0))
	control.add_theme_stylebox_override("hover", _button_style(color.lightened(0.10), 0.0))
	var pressed := _button_style(color.darkened(0.10), 0.0)
	pressed.content_margin_top = 9
	pressed.content_margin_bottom = 7
	control.add_theme_stylebox_override("pressed", pressed)
	control.add_theme_stylebox_override("disabled", _button_style(color.darkened(0.42), 0.0))
	control.add_theme_stylebox_override("focus", _button_style(color, 1.0))

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
	return tr(STAGE_LABELS.get(stage_name, stage_name))

func _status_message() -> String:
	if game.stage == TableState.STAGE_HAND_OVER:
		return _localized_game_message(game.last_message)
	if game.current_player_index >= 0:
		var actor: Dictionary = game.players[game.current_player_index]
		if actor.is_human:
			return tr("轮到你行动")
		return tr("等待 %s 行动") % _seat_name(game.current_player_index)
	return _localized_game_message(game.last_message)

func _seat_name(player_index: int) -> String:
	var player: Dictionary = game.players[player_index]
	if player.is_human:
		return tr("你")
	return player.name

func _action_label(action: String) -> String:
	if action.begins_with("Blind"):
		return action.replace("Blind", tr("盲注"))
	if action.begins_with("Raise"):
		return action.replace("Raise", tr("加注到"))
	match action:
		"Fold":
			return tr("弃牌")
		"Check":
			return tr("让牌")
		"Call":
			return tr("跟注")
		"All-in":
			return tr("全下")
	return action

func _save_profile() -> void:
	if not LocalProfileScript.save_profile(profile, profile_path) and not _save_notice_pending:
		_save_notice_pending = true
		call_deferred("_show_save_notice")

func _show_save_notice() -> void:
	_save_notice_pending = false
	_show_text_popup(GameLocalization.present("未能保存"), GameLocalization.present("设置本次仍然有效，但未能写入本地文件。请检查磁盘空间和存档目录权限；退出后本次更新可能丢失。"), "SaveErrorPopup")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_confirm_leave(true)

func _confirm_leave(quit_app: bool) -> void:
	if (not _match_open or game.match_over) and _pending_records.is_empty() and _pending_matches.is_empty():
		if quit_app: get_tree().quit()
		else: _show_menu()
		return
	if find_child("LeavePopup", true, false) != null: return
	var message := GameLocalization.present("已成功保存的手牌、教程进度和设置保留。当前整场不支持续玩；离开会放弃未结算手牌，提前离桌单列。重新开桌免费。")
	if not _pending_records.is_empty() or not _pending_matches.is_empty():
		message += GameLocalization.present("\n还有未保存资料，退出应用会丢失这部分更新，请先重试保存。")
	var popup := _show_text_popup(GameLocalization.present("离开牌桌？"),message,"LeavePopup")
	var box := popup.get_child(0) as VBoxContainer
	var leave := _command_button(GameLocalization.present("确认退出") if quit_app else GameLocalization.present("确认返回菜单"), COLOR_DANGER, _white_color())
	leave.name = "ConfirmLeaveButton"
	leave.pressed.connect(func():
		popup.hide()
		if _match_open: _record_match_outcome()
		_match_open = false
		if quit_app: get_tree().quit()
		else: _show_menu())
	box.add_child(leave)

func _show_help() -> void:
	var body := GameLocalizationScript.present(PokerReference.rules_text())
	_show_text_popup(tr("规则速览"), body, "HelpPopup")

func _show_hand_reference() -> void:
	_show_text_popup(tr("牌型速览"), tr(PokerReference.hands_text()), "HandReferencePopup")

func _show_text_popup(title_text: String, body: String, node_name: String) -> PopupPanel:
	var popup := PopupPanel.new()
	popup.theme = theme
	popup.name = node_name
	popup.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, COLOR_BRASS.darkened(0.32), 2, 2, Vector2(22, 18)))
	add_child(popup)
	popup.popup_hide.connect(func(): popup.queue_free())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size.x = 540
	popup.add_child(box)
	var title := Label.new()
	title.text = tr(title_text)
	title.add_theme_font_size_override("font_size", FONT_DISPLAY)
	title.add_theme_color_override("font_color", COLOR_BRASS)
	box.add_child(title)
	var content := Label.new()
	content.text = tr(body)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.custom_minimum_size.x = 540
	content.add_theme_font_size_override("font_size", FONT_BODY)
	content.add_theme_color_override("font_color", _white_color())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 250)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	scroll.add_child(content)
	var close := _command_button(GameLocalization.present("关闭"), COLOR_ACTION, _white_color())
	close.name = "PopupCloseButton"
	close.pressed.connect(func(): popup.hide())
	box.add_child(close)
	popup.popup_centered(Vector2i(584, 440))
	return popup

func _run_package_self_test() -> void:
	var diagnostic := ExportSelfTestScript.new()
	var failures: int = await diagnostic.run(self)
	get_tree().quit(failures)
