extends Control
## Presentation only: resolves live table controls after layout. The controller
## owns progression, and highlighted actions remain the real table buttons.

var host: Control
var tutorial: TutorialController
var revision := 0
var step: Dictionary = {}
var coach_text: Label
var _raise_amount := -1

func configure(owner_node: Control, controller: TutorialController, table_revision: int) -> void:
	host = owner_node
	tutorial = controller
	revision = table_revision
	step = tutorial.current_step()
	name = "TutorialOverlay"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20

func _ready() -> void:
	_build_coach_card()
	if host.raise_expanded and tutorial.lesson_id == "G3" and is_instance_valid(host.raise_slider):
		show_raise_help(int(host.raise_slider.value))
	call_deferred("_focus_current_control")

func _process(_delta: float) -> void:
	# Anchors are resolved by Godot after each table rebuild and window resize.
	queue_redraw()

func _build_coach_card() -> void:
	var panel := PanelContainer.new()
	panel.name = "TutorialCoachCard"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 24
	panel.offset_right = 460
	panel.offset_top = -250
	panel.offset_bottom = -20
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.add_theme_stylebox_override("panel", host._panel_style(host.COLOR_PANEL_DARK, host.COLOR_BRASS, 2, 2, Vector2(16, 14)))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var veteran: Texture2D = host.CHARACTER_TEXTURES[4]
	var portrait: TextureRect = host._texture_rect(host._atlas_texture(veteran, Rect2(0, 0, veteran.get_width() / 4.0, veteran.get_height())), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	portrait.name = "TutorialCoachPortrait"
	portrait.custom_minimum_size = Vector2(64, 86)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 6)
	row.add_child(copy)
	var speaker := Label.new()
	speaker.text = GameLocalization.present("教练")
	speaker.add_theme_font_size_override("font_size", 14)
	speaker.add_theme_color_override("font_color", host.COLOR_BRASS)
	copy.add_child(speaker)
	coach_text = Label.new()
	coach_text.name = "TutorialCoachText"
	coach_text.text = step.text
	coach_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coach_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coach_text.add_theme_font_size_override("font_size", 20)
	coach_text.add_theme_color_override("font_color", host.COLOR_CARD)
	copy.add_child(coach_text)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	column.add_child(footer)
	var sandbox := Label.new()
	sandbox.text = GameLocalization.present("教学筹码 · 每手补齐 1000")
	sandbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sandbox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sandbox.add_theme_font_size_override("font_size", 13)
	sandbox.add_theme_color_override("font_color", host._muted_color())
	footer.add_child(sandbox)
	if bool(step.can_continue):
		var next: Button = host._command_button(GameLocalization.present("继续"), host.COLOR_BRASS, host._ink_color())
		next.name = "TutorialContinueButton"
		next.custom_minimum_size = Vector2(96, 38)
		next.pressed.connect(func(): host._continue_tutorial(str(step.id), revision))
		footer.add_child(next)

func show_raise_help(amount: int) -> void:
	if tutorial.lesson_id != "G3" or not is_instance_valid(coach_text): return
	_raise_amount = amount
	coach_text.text = tutorial.raise_explanation(amount)
	queue_redraw()

func _focus_targets() -> Array[Control]:
	var targets: Array[Control] = []
	var names: Array = ["RaiseControls"] if _raise_amount >= 0 else step.focus
	for target in names:
		if str(target) == "best_five":
			var keys := {}
			for card in tutorial.best_five(): keys[CardUtil.card_key(card)] = true
			for area in ["Seat0HoleCards", "CommunityCards"]:
				var cards := host.find_child(area, true, false)
				if cards == null: continue
				for card in cards.find_children("*", "Control", true, false):
					if card is Control and keys.has(card.get_meta("card_key", "")): targets.append(card)
			continue
		var node_name := "RaiseExpandButton" if str(target) == "Action_raise" else str(target)
		var node := host.find_child(node_name, true, false) as Control
		if node != null and node.is_visible_in_tree(): targets.append(node)
	return targets

func _focus_current_control() -> void:
	if not is_inside_tree() or revision != host._table_revision or not host._tutorial_active(): return
	var next := find_child("TutorialContinueButton", true, false) as Button
	if next != null:
		next.grab_focus()
		return
	for target in _focus_targets():
		if target is Button and not target.disabled:
			target.grab_focus()
			return

func _draw() -> void:
	if host == null or tutorial == null: return
	for target in _focus_targets():
		var rect := target.get_global_rect().grow(5)
		rect.position -= global_position
		draw_rect(rect, host.COLOR_BRASS, false, 2.0)
		var tip := Vector2(rect.get_center().x, maxf(16, rect.position.y - 3))
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-7, -9), tip + Vector2(7, -9)]), host.COLOR_BRASS)
