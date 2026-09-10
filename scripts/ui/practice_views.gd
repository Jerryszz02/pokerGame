class_name PracticeViews
extends RefCounted
## Read-only product views; only the tutorial's private controller owns a game.
var host: Control
var tutorial: TutorialController
var replay: Dictionary = {}
var replay_index := 0
var replay_all := false
var replay_playing := false
var replay_elapsed := 0.0
var replay_visited: Dictionary = {}
var replay_return_table := false
var replay_body: VBoxContainer
var replay_counter: Label
var replay_notice: Label
var filters: Dictionary = {}
var stats_body: VBoxContainer
var _tutorial_message := ""

func _init(owner_node: Control) -> void:
	host = owner_node

func _page(title: String, node_name: String) -> Dictionary:
	replay_playing = false
	host._clear()
	host.add_child(host._background(host.MENU_BACKGROUND_TEXTURE, Color(0.008, 0.018, 0.016, 0.65)))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 100)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 42)
	host.add_child(margin)
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", host._panel_style(host.COLOR_PANEL_DARK, host.COLOR_BRASS.darkened(0.3), 2, 2, Vector2(24,18)))
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_label(title, 26, host.COLOR_BRASS))
	var scroll := ScrollContainer.new()
	scroll.name = node_name + "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	box.add_child(footer)
	return {"body":body, "footer":footer, "box":box}

func _label(text: String, font_size: int = 18, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = GameLocalization.present(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, name: String, action: Callable) -> Button:
	var button: Button = host._command_button(text, host.COLOR_ACTION, host._white_color())
	button.text = GameLocalization.present(text)
	button.name = name
	button.pressed.connect(action)
	return button

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _cards(body: Node, title: String, cards: Array, visible_cards: bool = true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	var caption := _label(title, 16, host.COLOR_BRASS)
	caption.custom_minimum_size.x = 160
	row.add_child(caption)
	if cards.is_empty():
		var empty := _label(GameLocalization.present("尚未发出"), 16, host._muted_color())
		empty.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(empty)
	for card in cards:
		row.add_child(host._card_view(card, visible_cards, true))

func tutorial_home() -> void:
	var page := _page(GameLocalization.present("新手教程 · 七课入门"), "TutorialHomePanel")
	page.body.add_child(_label(GameLocalization.present("每课使用预设局面。完成进度单独保存，重练不计入普通战绩。"),18,host._muted_color()))
	for lesson in TutorialController.lessons():
		var done: bool = host.practice_store.state.tutorial_completed.has(lesson.id)
		page.body.add_child(_button("%s  %s%s" % [lesson.id, GameLocalization.present(lesson.title), GameLocalization.present("  ✓ 已完成") if done else ""], "Lesson_"+lesson.id, func(): open_lesson(lesson.id)))
		page.body.add_child(_label(lesson.summary,16,host._muted_color()))
	page.footer.add_child(_button(GameLocalization.present("返回首页"),"TutorialHomeBackButton",host._show_menu))
	_store_notice(page.body)

func open_lesson(id: String) -> void:
	tutorial = TutorialController.new()
	tutorial.start(id)
	host.tutorial_controller = tutorial
	_tutorial_message = ""
	_render_lesson()

func _render_lesson() -> void:
	var step := tutorial.current_step()
	var page := _page("%s · %s" % [tutorial.lesson_id,GameLocalization.present(step.title)],"TutorialLessonPanel")
	var text := _label(step.text)
	text.name = "TutorialStepText"
	page.body.add_child(text)
	if not _tutorial_message.is_empty():
		page.body.add_child(_label(_tutorial_message,18,host.COLOR_BRASS))
	if not str(step.get("detail", "")).is_empty():
		page.body.add_child(_label(str(step.detail),16,host._muted_color()))
	var cards: Array = step.get("cards", [])
	if tutorial.lesson_id == "T1":
		_cards(page.body,GameLocalization.present("你的底牌区域"),cards.slice(0,2))
		_cards(page.body,GameLocalization.present("公共牌区域"),cards.slice(2))
		page.body.add_child(_label(GameLocalization.present("座位旁：玩家筹码区域　　桌面中央：底池区域"),18,host.COLOR_BRASS))
	elif not cards.is_empty():
		_cards(page.body,GameLocalization.present("当前示例牌"),cards)
	if tutorial.game != null:
		_cards(page.body,GameLocalization.present("你的底牌"),tutorial.game.players[0].hole_cards)
		if not tutorial.game.community_cards.is_empty():
			_cards(page.body,GameLocalization.present("当前公共牌"),tutorial.game.community_cards)
	var options := HFlowContainer.new()
	options.name = "TutorialOptions"
	options.add_theme_constant_override("h_separation",8)
	options.add_theme_constant_override("v_separation",8)
	page.body.add_child(options)
	for option in step.options:
		var id: String = option.id
		options.add_child(_button(str(option.label),"TutorialChoice_"+id,func(): submit_lesson(id)))
	if tutorial.completed:
		var saved: bool = host.practice_store.complete_tutorial(tutorial.lesson_id)
		page.body.add_child(_label(GameLocalization.present("课程进度已保存。") if saved else GameLocalization.present("课程已完成，但进度未保存：")+GameLocalization.present(host.practice_store.notice),18,host.COLOR_BRASS))
		if not saved:
			page.footer.add_child(_button(GameLocalization.present("重试保存"),"TutorialSaveRetry",_render_lesson))
		var index: int = PracticeStore.LESSONS.find(tutorial.lesson_id)
		if index < 6:
			page.footer.add_child(_button(GameLocalization.present("下一课"),"TutorialNextLesson",func(): open_lesson(PracticeStore.LESSONS[index+1])))
		else:
			page.footer.add_child(_button(GameLocalization.present("进入自由对战"),"TutorialStartFree",func(): host._show_mode_config("free")))
	page.footer.add_child(_button(GameLocalization.present("重练本课"),"TutorialRestartButton",func(): open_lesson(tutorial.lesson_id)))
	page.footer.add_child(_button(GameLocalization.present("课程列表"),"TutorialBackButton",tutorial_home))

func submit_lesson(choice: String) -> void:
	var result := tutorial.submit(choice)
	_tutorial_message = str(result.message)
	_render_lesson()

func history() -> void:
	var page := _page(GameLocalization.present("牌局记录 · 按整场分组"),"HistoryPanel")
	page.body.name = "HistoryList"
	_pending_notice(page.body)
	var records: Array = host.practice_store.records()
	if records.is_empty():
		page.body.add_child(_label(GameLocalization.present("暂无已保存牌谱。完成一手后可在这里回放；不会生成示例战绩。")))
	var matches := {}
	for record in records:
		if not matches.has(record.match_id):
			matches[record.match_id] = []
		matches[record.match_id].append(record)
	for match_id in matches:
		var first: Dictionary = matches[match_id][0]
		page.body.add_child(_label(GameLocalization.present("%s UTC · %s · 本场 %d 条记录") % [first.created_at.replace("T"," "), _mode(first.config.mode), matches[match_id].size()],20,host.COLOR_BRASS))
		for record in matches[match_id]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation",8)
			page.body.add_child(row)
			var view := _button(GameLocalization.present("第 %d 手 · %d 人 · %s · %d 筹码 · %d/%d · 净变化 %+d") % [record.hand_number,int(record.config.ai_count)+1,_difficulty(record.config.difficulty),record.config.initial_stack,record.config.small_blind,record.config.big_blind,record.net_change],"ReplayRecord_"+record.id,func(): open_replay(record,false))
			view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(view)
			row.add_child(_button(GameLocalization.present("删除"),"DeleteRecord_"+record.id,func(): _confirm_delete(record.id)))
	_store_notice(page.body)
	page.footer.add_child(_button(GameLocalization.present("返回首页"),"HistoryBackButton",host._show_menu))

func _confirm_delete(id: String) -> void:
	var popup: PopupPanel = host._show_text_popup(GameLocalization.present("删除这手牌谱？"),GameLocalization.present("只删除该手完整回放。累计统计、教程进度和已解锁成就保留。"),"DeleteReplayPopup")
	popup.get_child(0).add_child(_button(GameLocalization.present("确认删除"),"ConfirmDeleteReplay",func():
		popup.hide()
		host.practice_store.delete_record(id)
		history()))

func _store_notice(body: Node) -> void:
	if not host.practice_store.notice.is_empty():
		body.add_child(_label(host.practice_store.notice,16,host.COLOR_BRASS))

func _pending_notice(body: Node) -> void:
	if host._pending_records.is_empty() and host._pending_matches.is_empty():
		return
	body.add_child(_label(GameLocalization.present("有尚未保存的记录：%s\n关闭游戏前请重试保存。") % GameLocalization.present(host._practice_save_error),16,host.COLOR_BRASS))
	body.add_child(_button(GameLocalization.present("重试保存"),"PracticeSaveRetry",func():
		host._retry_practice_saves()
		history()))

func stats() -> void:
	var page := _page(GameLocalization.present("我的统计与成就"),"StatsPanel")
	var choices := HFlowContainer.new()
	choices.add_theme_constant_override("h_separation",8)
	choices.add_theme_constant_override("v_separation",8)
	page.body.add_child(choices)
	_filter(choices,GameLocalization.present("时间（UTC）"),"days",[GameLocalization.present("全部时间"),GameLocalization.present("最近 7 天"),GameLocalization.present("最近 30 天")],[null,7,30])
	_filter(choices,GameLocalization.present("模式"),"mode",[GameLocalization.present("全部模式"),GameLocalization.present("自由对战"),GameLocalization.present("练习对局")],[null,"free","practice"])
	_filter(choices,GameLocalization.present("辅助"),"assistance_viewed",[GameLocalization.present("全部辅助来源"),GameLocalization.present("独立对局"),GameLocalization.present("实际查看过辅助")],[null,false,true])
	_filter(choices,GameLocalization.present("难度"),"difficulty",[GameLocalization.present("全部难度"),GameLocalization.present("简单"),GameLocalization.present("普通"),GameLocalization.present("困难")],[null,"simple","medium","hard"])
	_filter(choices,GameLocalization.present("人数"),"ai_count",[GameLocalization.present("全部人数"),GameLocalization.present("2 人"),GameLocalization.present("3 人"),GameLocalization.present("4 人"),GameLocalization.present("5 人"),GameLocalization.present("6 人")],[null,1,2,3,4,5])
	var depths: Array = []
	for stack in MatchConfig.STACKS:
		for blind in MatchConfig.BLINDS:
			var depth: int = int(stack / blind[1])
			if not depths.has(depth): depths.append(depth)
	depths.sort()
	var names := [GameLocalization.present("全部入场深度")]
	var values: Array = [null]
	for depth in depths:
		names.append("%d BB" % depth)
		values.append(depth)
	_filter(choices,GameLocalization.present("深度"),"depth",names,values)
	stats_body = VBoxContainer.new()
	stats_body.name = "StatsSummary"
	stats_body.add_theme_constant_override("separation",10)
	page.body.add_child(stats_body)
	_render_stats()
	page.footer.add_child(_button(GameLocalization.present("指标口径"),"StatsDefinitions",func(): host._show_text_popup(GameLocalization.present("统计口径"),GameLocalization.present("赢手表示独占赢得至少一个主池或边池；平分手另计，两者可以重叠。净盈利手以本手筹码变化大于零计算。未获任何奖池计为输手。\n不同盲注的原始筹码分组显示；BB 是大盲单位。提前离桌不算整场输赢。牌型只统计参与摊牌时的七选五结果。旧历史汇总不能反推牌谱或成就。辅助筛选只看是否真正显示过实时结果，打开不可用面板不算辅助。"),"StatsDefinitionsPopup")))
	page.footer.add_child(_button(GameLocalization.present("返回首页"),"StatsBackButton",host._show_menu))

func _filter(parent: Node, label: String, key: String, names: Array, values: Array) -> void:
	var option := OptionButton.new()
	option.name = "StatsFilter_"+key
	option.tooltip_text = GameLocalization.present(label)
	for name_value in names:
		option.add_item(GameLocalization.present(name_value))
	if filters.has(key):
		var selected := values.find(filters[key])
		option.select(maxi(0,selected))
	host._apply_field_style(option)
	option.item_selected.connect(func(index: int):
		if values[index] == null: filters.erase(key)
		else: filters[key] = values[index]
		_render_stats())
	parent.add_child(option)

func _render_stats() -> void:
	_clear_children(stats_body)
	var stats_value: Dictionary = host.practice_store.statistics(filters)
	stats_body.add_child(_label(GameLocalization.present("完成 %d 手 · 独占获奖 %d 手 · 平分 %d 手 · 未获奖 %d 手\n净盈利手 %d · 总净变化 %+.2f BB · 最大单手净盈利 %.2f BB") % [stats_value.hands,stats_value.exclusive_win_hands,stats_value.split_hands,stats_value.loss_hands,stats_value.positive_net_hands,stats_value.net_bb,stats_value.max_net_bb]))
	stats_body.add_child(_label(GameLocalization.present("完整结束 %d 场（赢 %d / 输 %d）· 提前离桌 %d 场\n摊牌获奖 %d 手 · 无人争夺获奖 %d 手 · 单场最高筹码 %d · 最高入场倍数 %.2f") % [stats_value.completed_matches,stats_value.won_matches,stats_value.lost_matches,stats_value.left_matches,stats_value.showdown_wins,stats_value.uncontested_wins,stats_value.peak_stack,stats_value.peak_entry_multiple]))
	stats_body.add_child(_label(GameLocalization.present("按盲注分组的净筹码：")+_counts(stats_value.net_profit),16,host._muted_color()))
	stats_body.add_child(_label(GameLocalization.present("摊牌形成牌型：")+_counts(stats_value.rank_counts)+"\n"+GameLocalization.present("以牌型获奖：")+_counts(stats_value.rank_win_counts)+"\n"+GameLocalization.present("其中独占：")+_counts(stats_value.rank_exclusive_counts)+"\n"+GameLocalization.present("其中平分：")+_counts(stats_value.rank_split_counts),16,host._muted_color()))
	stats_body.add_child(_label(GameLocalization.present("玩家画像 · 当前筛选样本 %d 手\n画像维度和评分尚未定义，暂不生成雷达图。") % stats_value.hands,18,host.COLOR_BRASS))
	var legacy: Dictionary = host.practice_store.state.legacy_stats
	stats_body.add_child(_label(GameLocalization.present("历史汇总（无法追溯、不参与上述筛选）：%d 手 · 胜手 %d · 净筹码 %d") % [legacy.get("total_hands",0),legacy.get("total_win_hands",0),legacy.get("total_net_profit",0)],16,host._muted_color()))
	stats_body.add_child(_label(GameLocalization.present("已解锁成就（全部来源）"),20,host.COLOR_BRASS))
	var awards: Dictionary = host.practice_store.state.achievements
	if awards.is_empty():
		stats_body.add_child(_label(GameLocalization.present("尚无成就。完成课程、完整回放或正常对局后解锁。"),16))
	for award in awards.values():
		if award is Dictionary:
			stats_body.add_child(_label("✓ %s · %s" % [GameLocalization.present(award.get("name","")),GameLocalization.present(award.get("source",""))],16))

func _counts(values: Dictionary) -> String:
	if values.is_empty(): return GameLocalization.present("暂无数据")
	var text: Array[String] = []
	for key in values: text.append("%s: %s" % [GameLocalization.present(str(key)),str(values[key])])
	return " · ".join(text)

func open_replay(record: Dictionary, from_table: bool) -> void:
	if record.get("frames",[]).is_empty():
		host._show_text_popup(GameLocalization.present("没有完整牌谱"),GameLocalization.present("只有已结算的有效手牌可以回放。"),"ReplayUnavailablePopup")
		return
	replay = record.duplicate(true)
	replay_return_table = from_table
	replay_index = 0
	replay_all = false
	replay_visited = {}
	replay_elapsed = 0.0
	var page := _page(GameLocalization.present("第 %d 手回放 · %s · 净变化 %+d") % [record.hand_number,_mode(record.config.mode),record.net_change],"ReplayPanel")
	replay_counter = _label("",18,host.COLOR_BRASS)
	page.body.add_child(replay_counter)
	var perspective := CheckBox.new()
	perspective.name = "ReplayOmniscientToggle"
	perspective.text = GameLocalization.present("全知视角（仅此已结束手牌，包含已弃牌底牌）")
	perspective.add_theme_font_size_override("font_size",16)
	perspective.toggled.connect(func(value: bool): replay_all = value; _render_replay_frame())
	page.body.add_child(perspective)
	replay_body = VBoxContainer.new()
	replay_body.add_theme_constant_override("separation",8)
	page.body.add_child(replay_body)
	replay_notice = _label(GameLocalization.present("回放是独立只读记录；不会重新计算胜负或累计战绩。"),16,host._muted_color())
	page.body.add_child(replay_notice)
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation",8)
	controls.add_theme_constant_override("v_separation",8)
	page.box.add_child(controls)
	page.box.move_child(controls,page.box.get_child_count()-2)
	controls.add_child(_button(GameLocalization.present("上一动作"),"ReplayPrevious",func(): _seek(replay_index-1)))
	controls.add_child(_button(GameLocalization.present("播放"),"ReplayPlay",func(): replay_playing = true))
	controls.add_child(_button(GameLocalization.present("暂停"),"ReplayPause",func(): replay_playing = false))
	controls.add_child(_button(GameLocalization.present("下一动作"),"ReplayNext",func(): _seek(replay_index+1)))
	var stages := {}
	for i in range(replay.frames.size()):
		var stage: String = replay.frames[i].stage
		if not stages.has(stage): stages[stage] = i
	for stage in stages:
		var index: int = stages[stage]
		controls.add_child(_button(host._stage_label(stage),"ReplayStage_"+stage,func(): _seek(index)))
	page.footer.add_child(_button(GameLocalization.present("分析说明"),"ReplayAnalysis",func(): host._show_text_popup(GameLocalization.present("复盘分析尚不可用"),GameLocalization.present("本地教练算法尚未定义。全知视角可展示底牌，但未来评价历史决策时只能使用当时可知的信息。当前不提供行动评分或最佳行动建议。"),"ReplayAnalysisPopup")))
	page.footer.add_child(_button(GameLocalization.present("返回牌桌") if from_table else GameLocalization.present("返回记录"),"ReplayCloseButton",_close_replay))
	_render_replay_frame()

func _render_replay_frame() -> void:
	if not is_instance_valid(replay_body): return
	_clear_children(replay_body)
	var frame: Dictionary = replay.frames[replay_index]
	replay_visited[replay_index] = true
	replay_counter.text = "%d / %d · %s · %s" % [replay_index+1,replay.frames.size(),host._stage_label(frame.stage),GameLocalization.message(frame.label)]
	_cards(replay_body,GameLocalization.present("当前公共牌"),frame.community_cards)
	for i in range(frame.players.size()):
		var player: Dictionary = frame.players[i]
		var exposed: bool = replay_all or i == 0 or (frame.stage in ["showdown","hand_over"] and not player.hand_result.is_empty())
		_cards(replay_body,GameLocalization.present("%s · 筹码 %d") % [(GameLocalization.present("你") if i == 0 else player.name),player.stack],player.hole_cards,exposed)
		var status: String = {"active":GameLocalization.present("在局"),"folded":GameLocalization.present("已弃牌"),"all_in":GameLocalization.present("全下"),"out":GameLocalization.present("已出局")}.get(player.status,player.status)
		replay_body.add_child(_label(GameLocalization.present("%s · 本轮投入 %d · 本手投入 %d") % [status,player.current_bet,player.total_bet],14,host._muted_color()))
	replay_body.add_child(_label(GameLocalization.present("底池 %d · 本轮最高下注 %d · 庄位 %d · 小盲位 %d · 大盲位 %d") % [frame.pot,frame.current_bet,frame.button_index,frame.small_blind_player_index,frame.big_blind_player_index],16))
	if frame.stage == "hand_over":
		for refund in replay.refunds:
			replay_body.add_child(_label(GameLocalization.present("未跟注返还：%s %d") % [(GameLocalization.present("你") if int(refund.player_index) == 0 else frame.players[int(refund.player_index)].name),refund.amount],16))
		for pot in replay.pots:
			var names: Array[String] = []
			for payout in pot.get("payouts",[]):
				names.append("%s +%d" % [(GameLocalization.present("你") if int(payout.player_index) == 0 else frame.players[int(payout.player_index)].name),payout.amount])
			replay_body.add_child(_label(GameLocalization.present("奖池 %d：%s") % [pot.amount,"、".join(names)],16))
	if replay_visited.size() == replay.frames.size():
		if host.practice_store.mark_replay_complete(replay.id):
			replay_notice.text = GameLocalization.present("已完整遍历这手牌谱；回放成就已保存。")
		else:
			replay_notice.text = GameLocalization.present("已完整回放；成就未保存（牌谱可能尚未成功保存），可在保存后重试回放。")

func _seek(index: int) -> void:
	replay_playing = false
	replay_index = clampi(index,0,replay.frames.size()-1)
	_render_replay_frame()

func tick(delta: float) -> void:
	if not replay_playing or host.find_child("ReplayPanel",true,false) == null or host._has_visible_popup(host): return
	replay_elapsed += delta
	if replay_elapsed < 0.8: return
	replay_elapsed = 0.0
	if replay_index < replay.frames.size()-1:
		replay_index += 1
		_render_replay_frame()
	else:
		replay_playing = false

func _close_replay() -> void:
	replay_playing = false
	if replay_return_table:
		host._render_table()
	else:
		history()

func _mode(mode: String) -> String:
	return {"free":GameLocalization.present("自由对战"),"practice":GameLocalization.present("练习对局"),"tutorial":GameLocalization.present("教程")}.get(mode,mode)

func _difficulty(difficulty: String) -> String:
	return {"simple":GameLocalization.present("简单"),"medium":GameLocalization.present("普通"),"hard":GameLocalization.present("困难")}.get(difficulty,difficulty)
