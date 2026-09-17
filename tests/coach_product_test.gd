extends SceneTree
var failures := 0
class FaultStore extends PracticeStore:
	var fail_metadata := false
	func _atomic_write(path: String, value: Variant) -> bool:
		if fail_metadata and path.ends_with("profile.json"): return false
		return super._atomic_write(path,value)
func _init() -> void: call_deferred("_run")
func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)
func _record() -> Dictionary:
	var game := PokerRound.new()
	game.shuffle_rng.seed = 9173
	game.start_new_match(1,"simple",{"mode":"practice"})
	while game.stage != TableState.STAGE_HAND_OVER:
		var legal := game.get_legal_actions(game.current_player_index)
		game.apply_action(TableState.ACTION_CALL if legal.actions.has(TableState.ACTION_CALL) else TableState.ACTION_CHECK)
	return game.completed_hand_record()
func _style(record: Dictionary) -> Dictionary:
	var estimates := {}
	for i in range(record.frames.size()): estimates[i] = {"available":true,"equity":0.2}
	return PlayerStyle.from_record(record,estimates)
func _run() -> void:
	var record := _record()
	var style := _style(record)
	check(style.raw.hands == 1 and style.raw.voluntary_hands == 1,"one VPIP hand per actual preflop opportunity")
	check(style.raw.decisions == 4 and style.raw.risk_count == 4,"all human streets use before-action contexts")
	check(style.raw.aggressive == 0 and style.raw.defensive == 1,"calls and checks are not aggression")
	check(style.dimensions.aggression == null and style.counts.aggression == 4,"under-gate values remain null with actual denominator")
	check(style.raw.groups.preflop.decisions == 1 and style.raw.groups.postflop.decisions == 3,"street counters preserve separate opportunities")
	var base := PlayerStyle.from_record(record)
	check(base.raw.decisions == 4 and base.raw.risk_count == 0,"equity failure retains base frequencies without fake risk")
	var merged := PlayerStyle.merge([style,style,style,style,style,style,style,style])
	check(merged.dimensions.aggression == 0 and merged.counts.aggression == 32,"valid zero differs from missing data")
	check(merged.dimensions.vpip == null,"VPIP has an independent hand gate")
	check(PlayerStyle.validate(style) and not PlayerStyle.validate(null),"only versioned raw styles validate")
	var negative: Dictionary = style.raw.duplicate(true)
	negative.luck_hands = 1; negative.luck_variable_hands = 1; negative.luck_delta = -3.0; negative.luck_variance = 2.0
	check(PlayerStyle.validate(PlayerStyle._finalize(negative)),"negative luck deviation is valid data")
	var bad := style.duplicate(true)
	bad.raw.risk_sum = NAN
	check(not PlayerStyle.validate(bad),"non-finite raw data rejects")
	bad = style.duplicate(true); bad.raw.aggressive = 90
	check(not PlayerStyle.validate(bad),"numerator cannot exceed denominator")
	bad = style.duplicate(true); bad.dimensions.risk = 1.0
	check(not PlayerStyle.validate(bad),"derived score cannot disagree with raw counts")
	var g := PokerRound.new(); g.start_new_match(1,"simple")
	var ctx := CoachContext.capture(g,0)
	var acc := PlayerStyle._empty_accumulator()
	PlayerStyle.accumulate(acc,ctx,{"type":"all_in","amount":0,"paid":int(g.players[0].stack)},{"available":true,"equity":0.2})
	check(acc.aggressive == 1,"all-in raise with amount zero is derived from chips actually paid")
	acc = PlayerStyle._empty_accumulator()
	PlayerStyle.accumulate(acc,ctx,{"type":"all_in","amount":0,"paid":int(ctx.to_call)},{"available":true,"equity":0.2})
	check(acc.aggressive == 0 and acc.defensive == 1,"all-in call is defense, not aggression")
	check(PlayerStyle.has_draw([CardUtil.make_card(14,"H"),CardUtil.make_card(10,"H")],[CardUtil.make_card(2,"H"),CardUtil.make_card(7,"H"),CardUtil.make_card(9,"C")]),"four hearts is a visible draw proxy")
	_test_store(record,style)
	_calibration()
	await _test_async(ctx,record)
	if failures == 0: print("Coach product tests passed.")
	quit(failures)
func _test_store(record: Dictionary, style: Dictionary) -> void:
	var path := OS.get_cache_dir().path_join("coach-store-%d" % Time.get_ticks_usec())
	var store := FaultStore.new(path)
	check(store.commit_hand(record),"base record committed before optional analysis")
	store.fail_metadata = true
	check(not store.update_style(record.id,style),"metadata failure is observable")
	var restored := PracticeStore.new(path)
	check(restored.statistics().style.raw.decisions == 4,"durable enriched hand repairs interrupted metadata update")
	check(restored.update_style(record.id,style) and restored.update_style(record.id,style),"enrichment retries are idempotent")
	check(restored.statistics().hands == 1 and restored.statistics().style.raw.decisions == 4,"retry never double counts")
	check(restored.delete_record(record.id),"delete full replay")
	check(restored.update_style(record.id,style),"late enrichment updates ledger after replay deletion")
	var reopened := PracticeStore.new(path)
	check(reopened.records().is_empty() and reopened.statistics().style.raw.decisions == 4,"deletion cannot resurrect replay or erase style")
	check(reopened.statistics({"difficulty":"hard"}).style.raw.decisions == 0,"style honors the same difficulty filter")
	check(reopened.statistics({"mode":"practice","assistance_viewed":false}).style.raw.decisions == 4,"style honors practice/assistance filters")
func _test_async(context: Dictionary, record: Dictionary) -> void:
	var service := CoachService.new()
	var results := []
	service.completed.connect(func(token,result): results.append([token,result]))
	service.request_live(context,{"max_worlds":96,"seed":2})
	service.cancel()
	await _drain(service)
	check(results.is_empty(),"cancelled completion never leaks to UI")
	var token := service.request_live(context,{"max_worlds":8,"seed":2})
	await _drain(service)
	check(results.size() == 1 and results[0][0] == token and results[0][1].available,"service can be reused after cancel/join")
	var style_results := []
	service.style_completed.connect(func(_token,result): style_results.append(result))
	service.request_style(record,{"max_worlds":8,"seed":2})
	await _drain(service)
	check(style_results.size() == 1 and PlayerStyle.validate(style_results[0].style),"actual asynchronous record pipeline returns valid mergeable style")
	service.request_live(context,{"max_worlds":1024})
	service.finish()
	check(not service.is_busy(),"owner exit cancels and joins all worker threads")
func _drain(service: CoachService) -> void:
	var deadline := Time.get_ticks_msec()+15000
	while service.is_busy() and Time.get_ticks_msec() < deadline:
		service.poll()
		await process_frame
	check(not service.is_busy(),"asynchronous work finishes within bounded wait")
	service.poll()
func _calibration() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 9173
	for n in [20,30]:
		var covered := 0
		var width := 0.0
		for sample in range(2000):
			var successes := 0
			for i in range(n): successes += int(rng.randf()<0.5)
			var p: float = float(successes)/n
			var denom: float = 1.0+3.8416/n
			var center: float = (p+3.8416/(2*n))/denom
			var half: float = 1.96*sqrt(p*(1-p)/n+3.8416/(4*n*n))/denom
			covered += int(center-half <= 0.5 and center+half >= 0.5)
			width += 2*half
		check(covered > 1800,"Wilson display-gate calibration has expected conservative coverage")
		print("Style gate calibration n=%d: mean Wilson 95%% width %.3f, coverage %.3f; display gate, not proof of skill" % [n,width/2000.0,covered/2000.0])
