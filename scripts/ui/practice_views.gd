class_name PracticeViews
extends RefCounted
## Read-only history, statistics and replay views.
const RadarChartScript := preload("res://scripts/ui/radar_chart.gd")
const CoachServiceScript := preload("res://scripts/ai/coach_service.gd")
const LocalReplayReviewScript := preload("res://scripts/ai/local_replay_review.gd")
var host: Control
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
var coach_service := CoachServiceScript.new()
var _review_queue: Array = []
var _review_results: Array = []
var _review_token := -1
var _review_generation := 0
var _review_cache: Dictionary = {}
var _review_scope := ""
var _review_key := ""
var analysis_body: VBoxContainer
var _text_review_body: VBoxContainer
var _text_review_token := -1
var _text_review_scope := ""

func _init(owner_node: Control) -> void:
	host = owner_node
	coach_service.completed.connect(_on_review_result)
	host.deepseek_review.completed.connect(_on_text_review_result)

func _page(title: String, node_name: String) -> Dictionary:
	replay_playing = false
	if node_name != "ReplayPanel": _cancel_replay_analysis()
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
	_filter(choices,GameLocalization.present("难度"),"difficulty",[GameLocalization.present("全部难度"),GameLocalization.present("简单"),GameLocalization.present("普通"),GameLocalization.present("困难"),GameLocalization.present("地狱")],[null,"simple","medium","hard","hell"])
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
	var style: Dictionary = stats_value.get("style", PlayerStyle.empty())
	var radar := RadarChartScript.new()
	radar.name = "StyleRadarChart"
	radar.set_style(style)
	stats_body.add_child(radar)
	stats_body.add_child(_label(GameLocalization.present("风格雷达仅描述决策倾向，不代表强弱；样本不足的维度不会绘制。"),14,host._muted_color()))
	var detail: Dictionary = style.get("details", {})
	var numerators: Dictionary = detail.get("numerators", {})
	var denominators: Dictionary = detail.get("denominators", {})
	var gates: Dictionary = detail.get("sample_minimums", {})
	var style_lines: Array[String] = []
	for key in ["aggression", "defense", "risk", "vpip", "pressure"]:
		var numerator := float(numerators.get(key, 0))
		var denominator := int(denominators.get(key, 0))
		var gate := int(gates.get(key, 0))
		var rendered := "%.1f%%" % (numerator / denominator * 100.0) if denominator > 0 else "—"
		if denominator < gate: rendered += " · " + GameLocalization.present("样本不足")
		style_lines.append("%s %.2f/%d · %s · %s≥%d" % [GameLocalization.present(str(PlayerStyle.LABELS_ZH.get(key, key))), numerator, denominator, rendered, GameLocalization.present("门槛"), gate])
	stats_body.add_child(_label("\n".join(style_lines),14,host._muted_color()))
	var group_names := {"preflop":"翻前","postflop":"翻后","button":"庄位","small_blind":"小盲","big_blind":"大盲","early":"前位","late":"后位"}
	var group_lines: Array[String] = []
	for key in PlayerStyle.GROUPS:
		var group: Dictionary = detail.get("groups",{}).get(key,{})
		group_lines.append(GameLocalization.present("%s：进攻 %d/%d · 防守 %d/%d") % [GameLocalization.present(group_names[key]),int(group.get("aggressive",0)),int(group.get("decisions",0)),int(group.get("defensive",0)),int(group.get("priced",0))])
	stats_body.add_child(_label("\n".join(group_lines),14,host._muted_color()))
	stats_body.add_child(_label(GameLocalization.present("低权益施压：有听牌 %d 次，无听牌 %d 次；仅为当前可见牌的行为代理。") % [int(detail.get("pressure_draw",0)),int(detail.get("pressure_no_draw",0))],14,host._muted_color()))
	stats_body.add_child(_label(GameLocalization.present("低权益投入：%d 次；达到名义跟注门槛 %d 次；低于门槛 %d 次。全下运气：%+.2f BB，合格 %d 手。") % [int(detail.get("low_equity_paid",0)),int(detail.get("low_equity_reasonable",0)),int(detail.get("low_equity_below_price",0)),float(detail.get("luck_delta_bb",0.0)),int(detail.get("luck_qualifying_hands",0))],14,host._muted_color()))
	stats_body.add_child(_label(GameLocalization.present("完整结束 %d 场（赢 %d / 输 %d）· 提前离桌 %d 场\n摊牌获奖 %d 手 · 无人争夺获奖 %d 手 · 单场最高筹码 %d · 最高入场倍数 %.2f") % [stats_value.completed_matches,stats_value.won_matches,stats_value.lost_matches,stats_value.left_matches,stats_value.showdown_wins,stats_value.uncontested_wins,stats_value.peak_stack,stats_value.peak_entry_multiple]))
	stats_body.add_child(_label(GameLocalization.present("按盲注分组的净筹码：")+_counts(stats_value.net_profit),16,host._muted_color()))
	stats_body.add_child(_label(GameLocalization.present("摊牌形成牌型：")+_counts(stats_value.rank_counts)+"\n"+GameLocalization.present("以牌型获奖：")+_counts(stats_value.rank_win_counts)+"\n"+GameLocalization.present("其中独占：")+_counts(stats_value.rank_exclusive_counts)+"\n"+GameLocalization.present("其中平分：")+_counts(stats_value.rank_split_counts),16,host._muted_color()))
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
	_cancel_replay_analysis()
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
	analysis_body = VBoxContainer.new()
	analysis_body.name = "ReplayAnalysisBody"
	analysis_body.add_theme_constant_override("separation", 12)
	page.body.add_child(analysis_body)
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
	page.footer.add_child(_button(GameLocalization.present("分析说明"),"ReplayAnalysisInfo",func(): host._show_text_popup(GameLocalization.present("复盘分析"),GameLocalization.present("分析只使用每个行动前保存的局面、实际行动和中性范围；全知视角不会改变建议。旧牌谱如果没有行动前局面会显示不可用。"),"ReplayAnalysisPopup")))
	page.footer.add_child(_button(GameLocalization.present("返回牌桌") if from_table else GameLocalization.present("返回记录"),"ReplayCloseButton",_close_replay))
	_render_replay_frame()
	_start_replay_analysis()

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

func _start_replay_analysis() -> void:
	_cancel_replay_analysis()
	_review_scope = str(replay.get("id", "")) + ":" + str(CoachAnalysis.VERSION)
	_review_results.clear()
	_clear_children(analysis_body)
	for frame in replay.get("frames", []):
		if frame is Dictionary and frame.get("decision_context") is Dictionary and frame.get("action",{}).get("actor",-1) == 0:
			_review_queue.append(frame)
	if _review_queue.is_empty():
		replay_notice.text = GameLocalization.present("旧牌谱没有保存行动前局面，无法分析。")
		_review_scope = ""
		return
	replay_playing = false
	replay_notice.text = GameLocalization.present("正在分析本手牌，文字解读会自动补充。")
	_review_next()

func _review_next() -> void:
	if _review_scope.is_empty() or _review_token >= 0 or coach_service.is_busy(): return
	while not _review_queue.is_empty():
		var frame: Dictionary = _review_queue[0]
		var actual := {"action_type":str(frame.action.type),"amount":int(frame.action.get("amount",0))}
		_review_key = _review_scope + ":" + (JSON.stringify(frame.decision_context)+JSON.stringify(actual)).sha256_text()
		if _review_cache.has(_review_key):
			_review_results.append(_review_cache[_review_key].duplicate(true))
			_review_queue.pop_front()
			continue
		_review_token = coach_service.request_review(frame.decision_context,actual,{"max_worlds":32,"max_depth":12,"time_budget_ms":1000,"seed":9173+_review_results.size()})
		if _review_token >= 0: _review_queue.pop_front()
		return
	_review_scope = ""
	_render_replay_analysis()

func _on_review_result(token: int, result: Dictionary) -> void:
	if token != _review_token or _review_scope.is_empty() or not is_instance_valid(host) or host.find_child("ReplayPanel",true,false) == null: return
	_review_token = -1
	_review_results.append(result.duplicate(true))
	_review_cache[_review_key] = result.duplicate(true)
	while _review_cache.size() > 32: _review_cache.erase(_review_cache.keys()[0])
	_review_next()

func _review_action(value: Dictionary) -> String:
	var names := {"fold":"弃牌","check":"让牌","call":"跟注","raise":"加注","all_in":"全下"}
	var kind := str(value.get("action_type",""))
	var text := GameLocalization.present(names.get(kind,kind))
	if kind in ["raise","all_in"]: text += " → %d" % int(value.get("amount",0))
	return text

func _review_ev(value: Dictionary) -> String:
	if not value.get("uncertainty_available",false): return "%.2f BB · %s" % [float(value.get("ev_bb",0)),GameLocalization.present("样本不足以估计误差")]
	return "%.2f ± %.2f BB" % [float(value.get("ev_bb",0)),float(value.get("stderr_bb",0))]

func _render_replay_analysis() -> void:
	if not is_instance_valid(analysis_body): return
	_clear_children(analysis_body)
	var worst := -1
	var closest := -1
	var compared := 0
	for i in range(_review_results.size()):
		var result: Dictionary = _review_results[i]
		if not result.get("available",false):
			analysis_body.add_child(_label(GameLocalization.present("决定 %d：没有可靠的分析结果。") % (i+1),15))
			continue
		compared += 1
		if closest < 0 or result.gap_bb < _review_results[closest].gap_bb: closest = i
		if result.get("uncertainty_available",false) and not result.close and (worst < 0 or result.gap_bb > _review_results[worst].gap_bb): worst = i
		var text := GameLocalization.present("决定 %d · %d 个共同样本 · 推演 %d 步") % [i+1,int(result.world_count),int(result.depth)]
		text += "\n" + GameLocalization.present("实际：%s · %s") % [_review_action(result.actual),_review_ev(result.actual)]
		text += "\n" + GameLocalization.present("最高估值：%s · %s") % [_review_action(result.best),_review_ev(result.best)]
		text += "\n" + GameLocalization.present("估值差 %.2f BB · %s") % [float(result.gap_bb),GameLocalization.present("估计接近") if result.close else GameLocalization.present("存在估计差异")]
		analysis_body.add_child(_label(text,15))
	if compared == 0:
		replay_notice.text = GameLocalization.present("没有可比较的本地分析结果；旧局面或取消任务不会补零。")
		return
	var recap := GameLocalization.present("已比较 %d 个决定；第 %d 个最接近本模型的最高估值。") % [compared,closest+1]
	if worst >= 0:
		var result: Dictionary = _review_results[worst]
		recap += "\n" + GameLocalization.present("第 %d 个决定最值得回看。下次类似局面，先比较 %s 与 %s 的投入和后续风险。") % [worst+1,_review_action(result.actual),_review_action(result.best)]
	else: recap += "\n" + GameLocalization.present("现有样本没有区分出明确差异；不要把最高估值当成唯一正确行动。")
	replay_notice.text = recap
	analysis_body.add_child(_label(GameLocalization.present("数值是收益均值 ± 一个采样标准误差，不是保赢范围。中性范围和后续行动模型均为近似；深度耗尽后按过牌/跟注推进摊牌，不代表最优策略。"),14,host._muted_color()))
	_text_review_body = VBoxContainer.new()
	_text_review_body.name = "ReplayTextReviewBody"
	analysis_body.add_child(_text_review_body)
	_text_review_scope = ""
	_request_text_review()

func _text_scope() -> String:
	return str(replay.get("id", "")) + ":" + TranslationServer.get_locale() + ":" + JSON.stringify(DeepSeekReview.make_facts(_review_results)).sha256_text()

func _request_text_review() -> void:
	if _text_review_token >= 0 or _text_review_scope == _text_scope(): return
	if not _review_scope.is_empty() or _review_results.is_empty() or not is_instance_valid(_text_review_body): return
	_text_review_scope = _text_scope()
	_text_review_token = host.deepseek_review.request_review(_review_results, TranslationServer.get_locale())
	# Show useful offline prose immediately, including throughout the HTTP wait.
	_render_text_review(_local_text_review(), _text_review_token >= 0)

func _local_text_review() -> Dictionary:
	return LocalReplayReviewScript.generate(DeepSeekReview.make_facts(_review_results), TranslationServer.get_locale())

func _on_text_review_result(token: int, result: Dictionary) -> void:
	if token != _text_review_token or _text_review_scope != _text_scope() or not is_instance_valid(_text_review_body) or host.find_child("ReplayPanel",true,false) == null: return
	_text_review_token = -1
	_render_text_review(result if result.get("available", false) else _local_text_review())

func _render_text_review(result: Dictionary, pending: bool = false) -> void:
	_clear_children(_text_review_body)
	if not result.get("available", false):
		_text_review_body.add_child(_label(GameLocalization.present("正在生成复盘解读……") if pending else GameLocalization.present("文字解读暂时不可用，本地分析已保留。"),16))
		return
	var local: bool = result.get("source", "") == "local"
	_text_review_body.add_child(_label(GameLocalization.present("本地规则分析") if local else GameLocalization.present("复盘解读"),18,host.COLOR_BRASS))
	_text_review_body.add_child(_label(GameLocalization.present("根据本地收益估值和固定规则生成；不需要联网。") if local else GameLocalization.present("AI 生成的练习建议；数值以本地分析为准。"),14,host._muted_color()))
	if local:
		_text_review_body.add_child(_label(GameLocalization.present("正在尝试云端解读，完成后将自动更新。") if pending else GameLocalization.present("云端解读不可用，已使用本地规则分析。"),14,host._muted_color()))
	for item in result.items:
		_text_review_body.add_child(_label(GameLocalization.present("决定 %d") % int(item.decision_id),16))
		# Service prose is plain text, not BBCode, markup, or executable content.
		_text_review_body.add_child(_label(item.explanation + "\n" + item.next_step,16))

func tick(delta: float) -> void:
	coach_service.poll()
	_review_next()
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
	_cancel_replay_analysis()
	if replay_return_table:
		host._render_table()
	else:
		history()

func _cancel_replay_analysis() -> void:
	_review_generation += 1
	_review_scope = ""
	_review_token = -1
	_review_queue.clear()
	coach_service.cancel()
	_text_review_token = -1
	_text_review_scope = ""
	host.deepseek_review.cancel()

func finish() -> void:
	_cancel_replay_analysis()
	coach_service.finish()

func _mode(mode: String) -> String:
	return {"free":GameLocalization.present("自由对战"),"practice":GameLocalization.present("练习对局"),"tutorial":GameLocalization.present("教程")}.get(mode,mode)

func _difficulty(difficulty: String) -> String:
	return {"simple":GameLocalization.present("简单"),"medium":GameLocalization.present("普通"),"hard":GameLocalization.present("困难"),"hell":GameLocalization.present("地狱")}.get(difficulty,difficulty)
