class_name PokerReference
extends RefCounted

static func rules_text() -> String:
	return "整场目标：赢得牌桌全部筹码；筹码归零则整场结束。开桌可选人数、筹码和盲注，盲注一场内固定，重新开桌完全免费。\n\n每手用自己的两张底牌与最多五张公共牌选最佳五张。流程为翻前 → 翻牌（三张）→ 转牌（一张）→ 河牌（一张）→ 摊牌；对手全部弃牌时可提前结束。\n\n让牌：无需跟注时免费继续。跟注：补足本轮最高下注，筹码不足时只付剩余筹码。加注到：本轮累计投入的目标总额，不是额外投入。弃牌：放弃本手争夺。全下：投入剩余筹码，但仍受加注权限制。\n\n多人桌翻前从大盲之后开始，翻后从庄位之后第一位可行动者开始。单挑时庄位兼小盲，翻前先行动、翻后后行动。每手庄位轮换。\n\n全下玩家只争夺其投入对应的底池，其余投入形成边池。最佳五张相同则平分，余数按庄位之后的座位顺序分配。无人跟注的多余筹码退回。派奖金额不是净利润，净变化须扣除本手投入。\n\n设置和速览打开期间牌局等待。已完成手牌保存成功后可以跨启动回放；当前未结束的对局不支持续玩。离开时放弃未结算手牌，提前离桌单列。保存失败会明确提示并可重试。"


static func hands() -> Array:
	return [
		_example("同花顺", [c(14,"S"),c(13,"S"),c(12,"S"),c(11,"S"),c(10,"S")], "同一花色的连续五张；皇家同花顺是其中的 A 高同花顺。", HandEvaluator.STRAIGHT_FLUSH),
		_example("四条", [c(9,"S"),c(9,"H"),c(9,"D"),c(9,"C"),c(2,"S")], "四张同点数牌，加一张踢脚牌。", HandEvaluator.FOUR_KIND),
		_example("葫芦", [c(8,"S"),c(8,"H"),c(8,"D"),c(4,"C"),c(4,"S")], "三条加一对。", HandEvaluator.FULL_HOUSE),
		_example("同花", [c(14,"H"),c(11,"H"),c(8,"H"),c(6,"H"),c(2,"H")], "五张同一花色，不要求连续。", HandEvaluator.FLUSH),
		_example("顺子", [c(5,"S"),c(4,"H"),c(3,"D"),c(2,"C"),c(14,"S")], "五张连续点数；A 可作 1，A-2-3-4-5 是最小顺子。", HandEvaluator.STRAIGHT),
		_example("三条", [c(7,"S"),c(7,"H"),c(7,"D"),c(13,"C"),c(2,"S")], "三张同点数牌，比较三条点数后比较踢脚牌。", HandEvaluator.THREE_KIND),
		_example("两对", [c(10,"S"),c(10,"H"),c(6,"D"),c(6,"C"),c(3,"S")], "两组对子，先比高对，再比低对，最后比踢脚牌。", HandEvaluator.TWO_PAIR),
		_example("一对", [c(12,"S"),c(12,"H"),c(9,"D"),c(5,"C"),c(2,"S")], "一组对子；对子相同则依次比较三张踢脚牌。", HandEvaluator.ONE_PAIR),
		_example("高牌", [c(14,"S"),c(11,"H"),c(9,"D"),c(5,"C"),c(2,"S")], "没有更高牌型时比较五张牌的点数。", HandEvaluator.HIGH_CARD)
	]

static func hands_text() -> String:
	var lines := ["牌型从高到低：" ]
	for i in range(hands().size()):
		var item: Dictionary = hands()[i]
		lines.append("%d. %s：%s 示例 %s" % [i + 1, item.name, item.description, CardUtil.labels(item.cards)])
	return "\n".join(lines) + "\n皇家同花顺属于同花顺，不是第十种牌型；公共牌组成的最佳五张牌对所有仍在牌局中的玩家可用。"

static func _example(name: String, cards: Array, description: String, rank: int) -> Dictionary:
	return {"name": name, "cards": CardUtil.clone_cards(cards), "description": description, "rank": rank}

static func c(rank: int, suit: String) -> Dictionary:
	return CardUtil.make_card(rank, suit)
