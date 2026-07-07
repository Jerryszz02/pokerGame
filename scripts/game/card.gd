class_name CardUtil
extends RefCounted

const SUITS = ["S", "H", "D", "C"]
const RANKS = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
const RANK_LABELS = {
	2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8", 9: "9",
	10: "T", 11: "J", 12: "Q", 13: "K", 14: "A"
}
const DISPLAY_RANK_LABELS = {
	2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8", 9: "9",
	10: "10", 11: "J", 12: "Q", 13: "K", 14: "A"
}
const SUIT_LABELS = {
	"S": "♠",
	"H": "♥",
	"D": "♦",
	"C": "♣"
}

static func make_card(rank: int, suit: String) -> Dictionary:
	return {"rank": rank, "suit": suit}

static func card_key(card: Dictionary) -> String:
	return "%s%s" % [RANK_LABELS[card.rank], card.suit]

static func card_label(card: Dictionary) -> String:
	return "%s%s" % [DISPLAY_RANK_LABELS[card.rank], SUIT_LABELS[card.suit]]

static func full_deck() -> Array:
	var cards := []
	for suit in SUITS:
		for rank in RANKS:
			cards.append(make_card(rank, suit))
	return cards

static func clone_cards(cards: Array) -> Array:
	var out := []
	for card in cards:
		out.append({"rank": card.rank, "suit": card.suit})
	return out

static func without_known(cards: Array, known: Array) -> Array:
	var known_keys := {}
	for card in known:
		known_keys[card_key(card)] = true
	var out := []
	for card in cards:
		if not known_keys.has(card_key(card)):
			out.append({"rank": card.rank, "suit": card.suit})
	return out

static func labels(cards: Array) -> String:
	var parts := []
	for card in cards:
		parts.append(card_label(card))
	return " ".join(parts)
