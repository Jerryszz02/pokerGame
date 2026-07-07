extends Control

const COLOR_DEEP = Color(0.035, 0.125, 0.105)
const COLOR_FELT = Color(0.070, 0.220, 0.180)
const COLOR_CARD = Color(0.953, 0.910, 0.820)
const COLOR_BRASS = Color(0.839, 0.659, 0.310)
const COLOR_ACTION = Color(0.180, 0.435, 0.620)
const COLOR_DANGER = Color(0.714, 0.251, 0.227)

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

var game := PokerRound.new()
var ai_count_spin: SpinBox
var difficulty_options: OptionButton
var raise_slider: HSlider
var raise_label: Label
var ai_pending := false

func _ready() -> void:
	randomize()
	_show_menu()

func _process(_delta: float) -> void:
	if game.is_ai_turn() and not ai_pending:
		ai_pending = true
		_run_ai_turn()

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func _show_menu() -> void:
	_clear()
	add_child(_background())

	var shell := CenterContainer.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shell)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 430)
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_DEEP.lightened(0.08), _edge_color(), 18, 2, Vector2(34, 30)))
	shell.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var kicker := Label.new()
	kicker.text = "本地单机牌局"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_color_override("font_color", COLOR_BRASS)
	kicker.add_theme_font_size_override("font_size", 15)
	box.add_child(kicker)

	var title := Label.new()
	title.text = "深夜德州扑克"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", _white_color())
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)

	var table_mark := Label.new()
	table_mark.text = "规则清晰、信息优先的战术牌桌"
	table_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table_mark.add_theme_color_override("font_color", _muted_color())
	table_mark.add_theme_font_size_override("font_size", 16)
	box.add_child(table_mark)

	box.add_child(_menu_row("AI 对手", _build_ai_spin()))
	box.add_child(_menu_row("难度", _build_difficulty_options()))

	var start_button := _command_button("开始牌局", COLOR_BRASS, _ink_color())
	start_button.custom_minimum_size = Vector2(0, 48)
	start_button.pressed.connect(_on_start_pressed)
	box.add_child(start_button)

	var note := Label.new()
	note.text = "离线运行，不接 API，不使用 LLM。"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", _muted_color())
	note.add_theme_font_size_override("font_size", 13)
	box.add_child(note)

func _build_ai_spin() -> SpinBox:
	ai_count_spin = SpinBox.new()
	ai_count_spin.min_value = 1
	ai_count_spin.max_value = 5
	ai_count_spin.step = 1
	ai_count_spin.value = 3
	ai_count_spin.custom_minimum_size = Vector2(160, 38)
	return ai_count_spin

func _build_difficulty_options() -> OptionButton:
	difficulty_options = OptionButton.new()
	difficulty_options.add_item("简单", 0)
	difficulty_options.add_item("中等", 1)
	difficulty_options.add_item("困难", 2)
	difficulty_options.select(1)
	difficulty_options.custom_minimum_size = Vector2(160, 38)
	return difficulty_options

func _menu_row(label_text: String, field: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _white_color())
	label.add_theme_font_size_override("font_size", 17)
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return row

func _on_start_pressed() -> void:
	var difficulty := "medium"
	match difficulty_options.get_selected_id():
		0:
			difficulty = "simple"
		1:
			difficulty = "medium"
		2:
			difficulty = "hard"
	game.start_new_match(int(ai_count_spin.value), difficulty)
	_render_table()

func _render_table() -> void:
	_clear()
	add_child(_background())

	var root := VBoxContainer.new()
	root.anchor_left = 0.035
	root.anchor_top = 0.0
	root.anchor_right = 0.965
	root.anchor_bottom = 1.0
	root.offset_top = 14
	root.offset_bottom = -14
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	root.add_child(_build_header())
	root.add_child(_build_table_shell())
	root.add_child(_build_actions())

func _build_header() -> Control:
	var header := PanelContainer.new()
	header.custom_minimum_size = Vector2(0, 54)
	header.add_theme_stylebox_override("panel", _panel_style(COLOR_DEEP.darkened(0.10), _edge_color(), 10, 1, Vector2(16, 8)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
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
	message.add_theme_font_size_override("font_size", 16)
	row.add_child(message)
	return header

func _metric_label(label_text: String, value_text: String, accent: Color) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(112, 0)
	box.add_theme_constant_override("separation", 0)
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", _muted_color())
	label.add_theme_font_size_override("font_size", 12)
	box.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", accent)
	value.add_theme_font_size_override("font_size", 24)
	box.add_child(value)
	return box

func _build_table_shell() -> Control:
	var table := PanelContainer.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.add_theme_stylebox_override("panel", _panel_style(COLOR_FELT, _edge_color(), 120, 3, Vector2(18, 12)))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	table.add_child(box)
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
	return table

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
	spacer.custom_minimum_size = Vector2(172, 102)
	return spacer

func _build_pot_instrument() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 176)
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_DEEP.darkened(0.02), _edge_color(), 32, 2, Vector2(18, 10)))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

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
	pot.add_theme_font_size_override("font_size", 30)
	box.add_child(pot)

	var bet := Label.new()
	bet.text = "当前下注 %d · 待跟 %d" % [game.current_bet, _current_to_call()]
	bet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bet.add_theme_color_override("font_color", _white_color())
	bet.add_theme_font_size_override("font_size", 13)
	box.add_child(bet)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 10)
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
	chip.custom_minimum_size = Vector2(86, 26)
	var fill := COLOR_BRASS if current else COLOR_FELT.darkened(0.08)
	var border := COLOR_BRASS.lightened(0.12) if current else _edge_color()
	chip.add_theme_stylebox_override("panel", _panel_style(fill, border, 14, 1, Vector2(10, 5)))
	var label := Label.new()
	label.text = _stage_label(stage_name)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _ink_color() if current else _muted_color())
	label.add_theme_font_size_override("font_size", 13)
	chip.add_child(label)
	return chip

func _build_actions() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 96)
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_DEEP.darkened(0.10), _edge_color(), 12, 1, Vector2(16, 10)))

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
		waiting.add_theme_font_size_override("font_size", 20)
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
		raise_label.add_theme_color_override("font_color", _white_color())
		raise_label.add_theme_font_size_override("font_size", 15)
		raise_row.add_child(raise_label)
		raise_slider = HSlider.new()
		raise_slider.min_value = legal.min_raise_to
		raise_slider.max_value = legal.max_raise_to
		raise_slider.step = game.big_blind
		raise_slider.value = legal.min_raise_to
		raise_slider.custom_minimum_size = Vector2(390, 32)
		raise_slider.value_changed.connect(_on_raise_slider_changed)
		raise_row.add_child(raise_slider)
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
	if game.players[0].stack > 0:
		var next_button := _command_button("下一手", COLOR_ACTION, _white_color())
		next_button.pressed.connect(func():
			game.start_next_hand()
			_render_table()
		)
		buttons.add_child(next_button)
	var restart_button := _command_button("重新开始", COLOR_BRASS, _ink_color())
	restart_button.pressed.connect(_show_menu)
	buttons.add_child(restart_button)
	return box

func _seat_panel(player_index: int, reveal: bool) -> Control:
	var player: Dictionary = game.players[player_index]
	var is_current := player_index == game.current_player_index and game.stage != TableState.STAGE_HAND_OVER
	var is_human := bool(player.is_human)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(172 if not is_human else 340, 96)
	var bg := COLOR_DEEP.lightened(0.04)
	var border := COLOR_BRASS if is_current else _edge_color()
	if player.status == TableState.STATUS_FOLDED:
		bg = COLOR_DEEP.darkened(0.08)
	elif player.status == TableState.STATUS_ALL_IN:
		border = COLOR_DANGER
	panel.add_theme_stylebox_override("panel", _panel_style(bg, border, 10, 2 if is_current else 1, Vector2(10, 6)))

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(76 if not is_human else 140, 0)
	info.add_theme_constant_override("separation", 1)
	box.add_child(info)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 5)
	info.add_child(title_row)

	var title := Label.new()
	title.text = _seat_name(player_index)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", _white_color())
	title.add_theme_font_size_override("font_size", 16 if is_human else 14)
	title_row.add_child(title)

	var blind_badge := _blind_badge(player_index)
	if blind_badge != null:
		title_row.add_child(blind_badge)

	var state := Label.new()
	state.text = "筹码 %d\n下注 %d · %s" % [player.stack, player.current_bet, _status_label(player.status)]
	state.add_theme_color_override("font_color", _muted_color())
	state.add_theme_font_size_override("font_size", 12)
	info.add_child(state)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 6)
	for card in player.hole_cards:
		cards.add_child(_card_view(card, reveal or game.stage == TableState.STAGE_HAND_OVER))
	box.add_child(cards)

	var footer := Label.new()
	footer.text = _seat_footer(player)
	footer.add_theme_color_override("font_color", COLOR_BRASS if is_current else _muted_color())
	footer.add_theme_font_size_override("font_size", 12)
	info.add_child(footer)
	return panel

func _blind_badge(player_index: int) -> Control:
	var text := ""
	var color := COLOR_FELT
	if player_index == game.button_index:
		text = "BTN"
		color = COLOR_BRASS
	elif player_index == game.small_blind_player_index:
		text = "SB"
		color = COLOR_BRASS.lightened(0.04)
	elif player_index == game.big_blind_player_index:
		text = "BB"
		color = COLOR_DANGER
	else:
		return null

	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", _panel_style(color, color, 4, 0, Vector2(7, 2)))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _ink_color() if text == "BTN" else _white_color())
	label.add_theme_font_size_override("font_size", 11)
	badge.add_child(label)
	return badge

func _card_view(card: Dictionary, face_up: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(58, 80)
	if face_up:
		panel.add_theme_stylebox_override("panel", _panel_style(COLOR_CARD, COLOR_CARD.darkened(0.16), 6, 1, Vector2(4, 4)))
	else:
		panel.add_theme_stylebox_override("panel", _panel_style(COLOR_ACTION.darkened(0.28), COLOR_ACTION.lightened(0.16), 6, 1, Vector2(4, 4)))
	var label := Label.new()
	label.text = CardUtil.card_label(card) if face_up else "◆"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _card_color(card) if face_up else COLOR_BRASS)
	label.add_theme_font_size_override("font_size", 22)
	panel.add_child(label)
	return panel

func _empty_card(index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(58, 80)
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_FELT.darkened(0.10), _edge_color(), 6, 1, Vector2(4, 4)))
	var label := Label.new()
	label.text = "街%d" % (index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _muted_color())
	label.add_theme_font_size_override("font_size", 13)
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
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _button_style(color, 0.0))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.08), 0.0))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.10), 0.0))
	button.add_theme_stylebox_override("focus", _button_style(color.lightened(0.08), 0.16))
	return button

func _on_raise_slider_changed(value: float) -> void:
	if raise_label:
		raise_label.text = "加注到 %d" % int(value)

func _on_action(action: String, amount: int) -> void:
	game.apply_action(action, amount)
	_render_table()

func _run_ai_turn() -> void:
	await get_tree().create_timer(0.35).timeout
	if game.is_ai_turn():
		var idx := game.current_player_index
		var decision := AiDecision.decide(game, idx)
		game.apply_action(decision.action_type, int(decision.get("amount", 0)))
	ai_pending = false
	_render_table()

func _background() -> ColorRect:
	var background := ColorRect.new()
	background.color = COLOR_DEEP
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	return background

func _edge_color() -> Color:
	return COLOR_FELT.lightened(0.22)

func _white_color() -> Color:
	return COLOR_CARD.lightened(0.07)

func _muted_color() -> Color:
	return COLOR_CARD.darkened(0.30)

func _ink_color() -> Color:
	return COLOR_DEEP.darkened(0.45)

func _panel_style(bg: Color, border: Color, radius: int, border_width: int, margins: Vector2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = margins.x
	style.content_margin_right = margins.x
	style.content_margin_top = margins.y
	style.content_margin_bottom = margins.y
	return style

func _button_style(bg: Color, outline_alpha: float) -> StyleBoxFlat:
	var style := _panel_style(bg, COLOR_CARD.lightened(0.08) if outline_alpha > 0.0 else bg, 8, 2 if outline_alpha > 0.0 else 0, Vector2(14, 8))
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
