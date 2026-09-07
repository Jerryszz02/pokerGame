#!/usr/bin/env python3
"""Generate deterministic reference hands using direct 5-7 card classification.

This oracle classifies the whole hand by rank/suit counts, unlike the game's
best-of-five combination search. It is offline and has no third-party imports.
"""
from collections import Counter
from pathlib import Path
import json
import random


def straight(ranks):
    ranks = set(ranks)
    if 14 in ranks:
        ranks.add(1)
    return next((high for high in range(14, 4, -1)
                 if set(range(high - 4, high + 1)) <= ranks), 0)


def evaluate(cards):
    counts = Counter(rank for rank, _ in cards)
    ranks = sorted(counts, reverse=True)
    flushes = [[r for r, s in cards if s == suit] for suit in 'CDHS']
    flushes = [sorted(rs, reverse=True) for rs in flushes if len(rs) >= 5]
    suited_straight = max((straight(rs) for rs in flushes), default=0)
    if suited_straight:
        return 8, [suited_straight]
    quads = [r for r in ranks if counts[r] == 4]
    if quads:
        return 7, [quads[0], max(r for r in ranks if r != quads[0])]
    trips = [r for r in ranks if counts[r] >= 3]
    if trips:
        pairs = [r for r in ranks if r != trips[0] and counts[r] >= 2]
        if pairs:
            return 6, [trips[0], pairs[0]]
    if flushes:
        return 5, max(rs[:5] for rs in flushes)
    if straight(ranks):
        return 4, [straight(ranks)]
    if trips:
        return 3, [trips[0]] + [r for r in ranks if r != trips[0]][:2]
    pairs = [r for r in ranks if counts[r] >= 2]
    if len(pairs) >= 2:
        return 2, pairs[:2] + [max(r for r in ranks if r not in pairs[:2])]
    if pairs:
        return 1, pairs + [r for r in ranks if r != pairs[0]][:3]
    return 0, ranks[:5]


def main():
    rng = random.Random(20260906)
    deck = [(r, s) for r in range(2, 15) for s in 'CDHS']
    cases = [rng.sample(deck, 5 + i % 3) for i in range(1500)]
    cases += [
        [(14, 'S'), (5, 'S'), (4, 'S'), (3, 'S'), (2, 'S'), (13, 'D'), (12, 'C')],
        [(14, 'S'), (14, 'H'), (14, 'D'), (13, 'S'), (13, 'H'), (13, 'D'), (2, 'C')],
        [(14, 'S'), (14, 'H'), (13, 'D'), (13, 'S'), (12, 'H'), (12, 'D'), (2, 'C')],
        [(14, 'S'), (14, 'H'), (14, 'D'), (14, 'C'), (13, 'H'), (12, 'D'), (2, 'C')],
    ]
    out = []
    for cards in cases:
        rank, kickers = evaluate(cards)
        out.append({'cards': cards, 'rank': rank, 'kickers': kickers})
    path = Path(__file__).resolve().parents[1] / 'tests/fixtures/hand_reference.json'
    path.write_text(json.dumps(out, separators=(',', ':')) + '\n')
    print(f'Wrote {len(out)} independent reference hands to {path}')


if __name__ == '__main__':
    main()
