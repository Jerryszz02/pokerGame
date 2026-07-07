class_name Deck
extends RefCounted

var cards: Array = []
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()
	reset()

func reset() -> void:
	cards = CardUtil.full_deck()

func shuffle() -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp

func draw(count: int = 1) -> Array:
	var out := []
	for _i in range(count):
		if cards.is_empty():
			break
		out.append(cards.pop_back())
	return out

func remaining_count() -> int:
	return cards.size()
