class_name HandEvaluator
extends RefCounted

const HIGH_CARD = 0
const ONE_PAIR = 1
const TWO_PAIR = 2
const THREE_KIND = 3
const STRAIGHT = 4
const FLUSH = 5
const FULL_HOUSE = 6
const FOUR_KIND = 7
const STRAIGHT_FLUSH = 8

const RANK_NAMES = {
	HIGH_CARD: "高牌",
	ONE_PAIR: "一对",
	TWO_PAIR: "两对",
	THREE_KIND: "三条",
	STRAIGHT: "顺子",
	FLUSH: "同花",
	FULL_HOUSE: "葫芦",
	FOUR_KIND: "四条",
	STRAIGHT_FLUSH: "同花顺"
}

static func evaluate(cards: Array) -> Dictionary:
	if cards.size() < 5:
		return _empty_result()
	var best := _empty_result()
	for a in range(cards.size() - 4):
		for b in range(a + 1, cards.size() - 3):
			for c in range(b + 1, cards.size() - 2):
				for d in range(c + 1, cards.size() - 1):
					for e in range(d + 1, cards.size()):
						var result := _evaluate_five([cards[a], cards[b], cards[c], cards[d], cards[e]])
						if compare_results(result, best) > 0:
							best = result
	return best

static func compare_results(a: Dictionary, b: Dictionary) -> int:
	if a.rank_value > b.rank_value:
		return 1
	if a.rank_value < b.rank_value:
		return -1
	var max_len: int = max(a.tiebreakers.size(), b.tiebreakers.size())
	for i in range(max_len):
		var av: int = a.tiebreakers[i] if i < a.tiebreakers.size() else 0
		var bv: int = b.tiebreakers[i] if i < b.tiebreakers.size() else 0
		if av > bv:
			return 1
		if av < bv:
			return -1
	return 0

static func _empty_result() -> Dictionary:
	return {
		"rank_value": -1,
		"rank_name": "无效",
		"tiebreakers": [],
		"best_cards": []
	}

static func _evaluate_five(cards: Array) -> Dictionary:
	var ranks := []
	var suit_counts := {}
	var rank_counts := {}
	for card in cards:
		ranks.append(card.rank)
		rank_counts[card.rank] = rank_counts.get(card.rank, 0) + 1
		suit_counts[card.suit] = suit_counts.get(card.suit, 0) + 1
	ranks.sort()
	ranks.reverse()
	var flush := suit_counts.size() == 1
	var straight_high := _straight_high(ranks)

	if flush and straight_high > 0:
		return _result(STRAIGHT_FLUSH, [straight_high], cards)

	var groups := _rank_groups(rank_counts)
	if groups[0].count == 4:
		return _result(FOUR_KIND, [groups[0].rank, groups[1].rank], cards)
	if groups[0].count == 3 and groups[1].count == 2:
		return _result(FULL_HOUSE, [groups[0].rank, groups[1].rank], cards)
	if flush:
		return _result(FLUSH, ranks, cards)
	if straight_high > 0:
		return _result(STRAIGHT, [straight_high], cards)
	if groups[0].count == 3:
		var kickers := [groups[0].rank]
		for group in groups:
			if group.count == 1:
				kickers.append(group.rank)
		return _result(THREE_KIND, kickers, cards)
	if groups[0].count == 2 and groups[1].count == 2:
		var pair_ranks := [groups[0].rank, groups[1].rank]
		pair_ranks.sort()
		pair_ranks.reverse()
		var kicker := 0
		for group in groups:
			if group.count == 1:
				kicker = group.rank
		return _result(TWO_PAIR, [pair_ranks[0], pair_ranks[1], kicker], cards)
	if groups[0].count == 2:
		var pair_kickers := [groups[0].rank]
		for group in groups:
			if group.count == 1:
				pair_kickers.append(group.rank)
		return _result(ONE_PAIR, pair_kickers, cards)
	return _result(HIGH_CARD, ranks, cards)

static func _result(rank_value: int, tiebreakers: Array, cards: Array) -> Dictionary:
	return {
		"rank_value": rank_value,
		"rank_name": RANK_NAMES[rank_value],
		"tiebreakers": tiebreakers,
		"best_cards": CardUtil.clone_cards(cards)
	}

static func _rank_groups(rank_counts: Dictionary) -> Array:
	var groups := []
	for rank in rank_counts.keys():
		groups.append({"rank": rank, "count": rank_counts[rank]})
	groups.sort_custom(func(a, b): return a.count > b.count if a.count != b.count else a.rank > b.rank)
	return groups

static func _straight_high(ranks: Array) -> int:
	var unique := []
	for rank in ranks:
		if not unique.has(rank):
			unique.append(rank)
	if unique.has(14):
		unique.append(1)
	for i in range(unique.size() - 4):
		var start: int = unique[i]
		var ok := true
		for j in range(1, 5):
			if unique[i + j] != start - j:
				ok = false
				break
		if ok:
			return start
	return 0
