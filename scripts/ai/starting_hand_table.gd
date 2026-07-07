class_name StartingHandTable
extends RefCounted

static func score(hole_cards: Array) -> int:
	if hole_cards.size() != 2:
		return 0
	var a: int = hole_cards[0].rank
	var b: int = hole_cards[1].rank
	var high: int = max(a, b)
	var low: int = min(a, b)
	var suited: bool = hole_cards[0].suit == hole_cards[1].suit
	var gap: int = high - low
	var value := 0

	if high == low:
		value = 45 + high * 4
	else:
		value = high * 4 + low * 2
		if high == 14:
			value += 12
		if suited:
			value += 8
		if gap == 1:
			value += 7
		elif gap == 2:
			value += 4
		elif gap >= 5:
			value -= 7
		if low <= 5 and high < 11:
			value -= 6
	return clampi(value, 1, 100)

static func label(hole_cards: Array) -> String:
	if hole_cards.size() != 2:
		return ""
	var a: int = hole_cards[0].rank
	var b: int = hole_cards[1].rank
	var high: int = max(a, b)
	var low: int = min(a, b)
	if high == low:
		return "%s%s" % [CardUtil.RANK_LABELS[high], CardUtil.RANK_LABELS[low]]
	var suffix := "s" if hole_cards[0].suit == hole_cards[1].suit else "o"
	return "%s%s%s" % [CardUtil.RANK_LABELS[high], CardUtil.RANK_LABELS[low], suffix]
