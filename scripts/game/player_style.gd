class_name PlayerStyle
extends RefCounted
## Mergeable sufficient statistics; dimensions describe style, not skill.
const VERSION := 1
const DIMENSIONS := ["luck", "aggression", "defense", "risk", "vpip", "pressure"]
const LABELS_ZH := {"luck":"运气", "aggression":"进攻", "defense":"防守", "risk":"冒险", "vpip":"入池", "pressure":"施压"}
const LABELS_EN := {"luck":"Luck", "aggression":"Aggression", "defense":"Defense", "risk":"Risk", "vpip":"VPIP", "pressure":"Pressure"}
const MIN_DECISIONS := {"aggression":30, "defense":30, "risk":30, "pressure":30, "vpip":20}
const GROUPS := ["preflop", "postflop", "button", "small_blind", "big_blind", "early", "late"]

static func empty() -> Dictionary: return _finalize(_empty_accumulator())
static func _empty_accumulator() -> Dictionary:
	var raw := {"hands":0, "voluntary_hands":0, "aggressive":0, "defensive":0, "priced":0,
		"decisions":0, "low_equity":0, "low_equity_paid":0, "low_equity_reasonable":0,
		"low_equity_below_price":0, "risk_sum":0.0, "risk_count":0,
		"pressure_opportunities":0, "pressure_aggressive":0, "pressure_draw":0, "pressure_no_draw":0,
		"luck_delta":0.0, "luck_variance":0.0, "luck_hands":0, "luck_variable_hands":0, "groups":{}}
	for key in GROUPS: raw.groups[key] = {"decisions":0,"aggressive":0,"priced":0,"defensive":0,"paid":0}
	return raw

static func from_record(record: Dictionary, estimates: Dictionary = {}) -> Dictionary:
	if estimates.is_empty() and validate(record.get("style")): return record.style.duplicate(true)
	var acc := _empty_accumulator()
	var preflop := false
	var voluntary := false
	var frames: Array = record.get("frames", [])
	for index in range(frames.size()):
		var frame: Variant = frames[index]
		if not frame is Dictionary or not frame.get("action") is Dictionary: continue
		var action: Dictionary = frame.action
		if int(action.get("actor", -1)) != 0 or not frame.get("decision_context") is Dictionary: continue
		var context: Dictionary = frame.decision_context
		if int(context.get("hero", -1)) != 0 or CoachContext.restore(context) == null: continue
		var normalized := FiniteSearch.normalize_actual(CoachContext.restore(context), 0, {"action_type":action.get("type"),"amount":action.get("amount",0)})
		if normalized.is_empty(): continue
		accumulate(acc, context, action, estimates.get(index, {}))
		if context.stage == TableState.STAGE_PREFLOP:
			preflop = true
			voluntary = voluntary or int(action.get("paid", 0)) > 0
	acc.hands = int(preflop)
	acc.voluntary_hands = int(voluntary)
	return _finalize(acc)

static func from_records(records: Array) -> Dictionary:
	var styles := []
	for record in records:
		if record is Dictionary: styles.append(from_record(record))
	return merge(styles)

static func accumulate(acc: Dictionary, context: Dictionary, action: Dictionary, estimate: Dictionary) -> void:
	var hero := int(context.hero)
	var player: Dictionary = context.players[hero]
	var kind := str(action.type)
	var paid := clampf(float(action.get("paid", 0)), 0.0, float(player.stack))
	var aggressive := kind in [TableState.ACTION_RAISE, TableState.ACTION_ALL_IN] and float(player.current_bet) + paid > float(context.current_bet)
	var priced := mini(int(context.to_call), int(player.stack)) > 0
	var continues := kind in [TableState.ACTION_CALL,TableState.ACTION_RAISE,TableState.ACTION_ALL_IN]
	acc.decisions += 1
	acc.aggressive += int(aggressive)
	acc.priced += int(priced)
	acc.defensive += int(priced and continues)
	var position := "early"
	if hero == int(context.button_index): position = "button"
	elif hero == int(context.small_blind_player_index): position = "small_blind"
	elif hero == int(context.big_blind_player_index): position = "big_blind"
	elif (hero - int(context.button_index) + context.players.size()) % context.players.size() >= context.players.size() - 2: position = "late"
	for key in ["preflop" if context.stage == TableState.STAGE_PREFLOP else "postflop", position]:
		var group: Dictionary = acc.groups[key]
		group.decisions += 1
		group.aggressive += int(aggressive)
		group.priced += int(priced)
		group.defensive += int(priced and continues)
		group.paid += int(paid > 0)
	if not bool(estimate.get("available", false)): return
	var equity: Variant = estimate.get("equity")
	if not _number(equity) or equity < 0 or equity > 1: return
	acc.risk_sum += paid / maxf(1.0, float(player.stack)) * (1.0 - float(equity))
	acc.risk_count += 1
	var live := 0
	for seat in context.players:
		if seat.status in [TableState.STATUS_ACTIVE,TableState.STATUS_ALL_IN]: live += 1
	if float(equity) >= minf(0.4, 1.0 / maxi(1, live)): return
	acc.low_equity += 1
	acc.pressure_opportunities += 1
	acc.pressure_aggressive += int(aggressive)
	if aggressive:
		acc.pressure_draw += int(has_draw(player.hole_cards, context.community_cards))
		acc.pressure_no_draw += int(not has_draw(player.hole_cards, context.community_cards))
	if paid > 0:
		acc.low_equity_paid += 1
		var price := float(mini(int(context.to_call),int(player.stack))) / maxf(1.0,float(context.pot)+mini(int(context.to_call),int(player.stack)))
		if float(equity) >= price: acc.low_equity_reasonable += 1
		else: acc.low_equity_below_price += 1

static func has_draw(holes: Array, board: Array) -> bool:
	if board.size() not in [3,4]: return false
	var suits := {}
	var ranks := {}
	for card in holes + board:
		suits[card.suit] = int(suits.get(card.suit,0)) + 1
		ranks[int(card.rank)] = true
		if int(card.rank) == 14: ranks[1] = true
	for card in holes:
		if int(suits.get(card.suit,0)) == 4: return true
	for low in range(1,11):
		var hit := 0
		var own := false
		for rank in range(low,low+5):
			hit += int(ranks.has(rank))
			for card in holes: own = own or int(card.rank) == rank or (rank == 1 and int(card.rank) == 14)
		if hit == 4 and own: return true
	return false

static func merge(styles: Array) -> Dictionary:
	var good := []
	for style in styles:
		if validate(style): good.append(style)
	return _finalize_raw(good)

static func validate(style: Variant) -> bool:
	if not style is Dictionary or style.get("version") != VERSION or not style.get("raw") is Dictionary: return false
	var raw: Dictionary = style.raw
	var prototype := _empty_accumulator()
	for key in prototype:
		if key == "groups": continue
		if not _number(raw.get(key)): return false
		if key != "luck_delta" and float(raw[key]) < 0: return false
		if key not in ["risk_sum","luck_delta","luck_variance"] and float(raw[key]) != floor(float(raw[key])): return false
	for pair in [["aggressive","decisions"],["priced","decisions"],["defensive","priced"],["voluntary_hands","hands"],["risk_count","decisions"],["pressure_opportunities","risk_count"],["pressure_aggressive","pressure_opportunities"],["luck_variable_hands","luck_hands"],["low_equity_paid","low_equity"]]:
		if raw[pair[0]] > raw[pair[1]]: return false
	if raw.risk_sum > raw.risk_count or raw.low_equity != raw.pressure_opportunities or raw.low_equity_reasonable + raw.low_equity_below_price != raw.low_equity_paid: return false
	if raw.pressure_draw + raw.pressure_no_draw != raw.pressure_aggressive: return false
	if not raw.get("groups") is Dictionary: return false
	for key in GROUPS:
		if not raw.groups.get(key) is Dictionary: return false
		var group: Dictionary = raw.groups[key]
		for field in prototype.groups[key]:
			if not _number(group.get(field)) or group[field] < 0 or float(group[field]) != floor(float(group[field])): return false
		if group.aggressive > group.decisions or group.priced > group.decisions or group.defensive > group.priced or group.paid > group.decisions: return false
	var expected := _finalize(raw)
	return style.get("dimensions") == expected.dimensions and style.get("counts") == expected.counts

static func _finalize_raw(styles: Array) -> Dictionary:
	var acc := _empty_accumulator()
	for style in styles:
		var raw: Dictionary = style.raw
		for key in acc:
			if key == "groups":
				for group in GROUPS:
					for field in acc.groups[group]: acc.groups[group][field] += raw.get("groups",{}).get(group,{}).get(field,0)
			else: acc[key] += raw.get(key,0)
	return _finalize(acc)

static func _finalize(acc: Dictionary) -> Dictionary:
	var numerators := {"aggression":acc.aggressive,"defense":acc.defensive,"risk":acc.risk_sum,"vpip":acc.voluntary_hands,"pressure":acc.pressure_aggressive}
	var denominators := {"aggression":acc.decisions,"defense":acc.priced,"risk":acc.risk_count,"vpip":acc.hands,"pressure":acc.pressure_opportunities}
	var dimensions := {"luck":null}
	for key in numerators: dimensions[key] = float(numerators[key])/denominators[key] if denominators[key] >= MIN_DECISIONS[key] else null
	if acc.luck_variable_hands >= 5 and acc.luck_variance > 0: dimensions.luck = clampf(0.5+acc.luck_delta/sqrt(acc.luck_variance)/6.0,0,1)
	var counts := denominators.duplicate()
	counts["luck"] = acc.luck_hands
	counts["luck_variable"] = acc.luck_variable_hands
	counts["decisions"] = acc.decisions
	return {"version":VERSION,"dimensions":dimensions,"counts":counts,"raw":acc.duplicate(true),"details":{
		"numerators":numerators,"denominators":denominators,"sample_minimums":MIN_DECISIONS.duplicate(),"groups":acc.groups.duplicate(true),
		"luck_delta_bb":acc.luck_delta,"luck_variance_bb2":acc.luck_variance,"luck_qualifying_hands":acc.luck_hands,
		"low_equity_paid":acc.low_equity_paid,"low_equity_reasonable":acc.low_equity_reasonable,"low_equity_below_price":acc.low_equity_below_price,
		"pressure_draw":acc.pressure_draw,"pressure_no_draw":acc.pressure_no_draw}}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
