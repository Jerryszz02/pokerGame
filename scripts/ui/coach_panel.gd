class_name CoachPanel
extends PopupPanel

const CoachServiceScript := preload("res://scripts/ai/coach_service.gd")
var service := CoachServiceScript.new()
var generation := 0
var status: Label
var result_body: VBoxContainer
var close_button: Button
var host: Control
var context_key := ""
var retry_context: Dictionary = {}
var _closing := false
var match_id := ""
var locale := ""

func open_live(owner: Control, context: Dictionary) -> void:
	host = owner
	theme = owner.theme
	add_theme_stylebox_override("panel", owner._panel_style(owner.COLOR_PANEL_DARK, owner.COLOR_BRASS.darkened(0.32), 2, 2, Vector2(22,18)))
	match_id = str(owner.game.match_id)
	locale = TranslationServer.get_locale()
	popup_hide.connect(close)
	name = "CoachPanel"
	size = Vector2(600, 440)
	retry_context = context.duplicate(true)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := Label.new()
	title.text = GameLocalization.present("本地教练")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", owner.COLOR_BRASS)
	box.add_child(title)
	status = Label.new()
	status.text = GameLocalization.present("正在计算…")
	status.add_theme_color_override("font_color", owner._white_color())
	status.add_theme_font_size_override("font_size", 18)
	box.add_child(status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	result_body = VBoxContainer.new()
	result_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(result_body)
	var retry: Button = owner._command_button(GameLocalization.present("重试"),owner.COLOR_ACTION,owner._white_color())
	retry.name = "CoachRetryButton"
	retry.text = GameLocalization.present("重试")
	retry.pressed.connect(func(): _request(retry_context))
	box.add_child(retry)
	close_button = owner._command_button(GameLocalization.present("关闭"),owner.COLOR_ACTION,owner._white_color())
	close_button.text = GameLocalization.present("关闭")
	close_button.pressed.connect(close)
	box.add_child(close_button)
	var toggle: Button = owner._command_button(GameLocalization.present("隐藏提示入口"),owner.COLOR_ACTION,owner._white_color())
	toggle.pressed.connect(func():
		owner.pending_match_config.show_hints = false
		owner.profile.settings.show_hints = false
		owner._save_profile()
		close())
	box.add_child(toggle)
	service.completed.connect(_on_result)
	if get_parent() == null: owner.add_child(self)
	popup_centered(Vector2i(600, 440))
	_request(context)

func _request(context: Dictionary) -> void:
	service.cancel()
	context_key = JSON.stringify(context)
	status.text = GameLocalization.present("正在计算…")
	_clear()
	generation = service.request_live(context, {"max_worlds":96, "seed":int(Time.get_ticks_usec() & 0x7fffffff)})
	if generation < 0: status.text = GameLocalization.present("上一项分析仍在收尾，请稍后重试。")

func close() -> void:
	if _closing: return
	_closing = true
	service.cancel()
	hide()


func _process(_delta: float) -> void:
	service.poll()
	if not _closing and visible and not _same_live_snapshot(): close()
	if _closing and not service.is_busy():
		if is_instance_valid(host) and host._in_match(): host._render_table()
		queue_free()

func _exit_tree() -> void:
	service.finish()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _on_result(token: int, result: Dictionary) -> void:
	if token != generation or not is_instance_valid(self): return
	if not visible or not _same_live_snapshot(): return
	if not bool(result.get("available", false)):
		status.text = GameLocalization.present("本次局面暂时无法计算，可重试。")
		return
	if is_instance_valid(host) and host.has_method("_in_match") and host._in_match():
		host.game.mark_assistance_viewed()
	status.text = GameLocalization.present("基于 %d 个采样世界") % int(result.get("world_count", 0))
	_clear()
	for line in [
		GameLocalization.present("胜出事件概率 %.1f%% · 平分事件概率 %.1f%%") % [float(result.get("win_rate", 0.0))*100.0, float(result.get("tie_probability", 0.0))*100.0],
		GameLocalization.present("权益 %.1f%% · 底池 %d · 跟注价格 %d") % [float(result.get("equity", 0.0))*100.0, int(result.get("pot", 0)), int(result.get("to_call", 0))],
		GameLocalization.present("名义跟注所需权益 %.1f%%；复杂边池请结合复盘。") % (float(result.get("pot_odds",0))*100.0),
		GameLocalization.present("估算基于公开行动推测的中性范围；权益是摊牌份额，范围与有限样本都会带来误差。")]:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size",18)
		label.add_theme_color_override("font_color",host._white_color())
		result_body.add_child(label)

func _same_live_snapshot() -> bool:
	if not is_instance_valid(host) or not host.has_method("_in_match") or not host._in_match(): return false
	if str(host.game.match_id) != match_id or TranslationServer.get_locale() != locale: return false
	var context_script: Variant = load("res://scripts/ai/coach_context.gd")
	if context_script == null: return false
	return JSON.stringify(context_script.capture(host.game, 0)) == context_key

func _clear() -> void:
	for child in result_body.get_children(): child.queue_free()
