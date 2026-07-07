# PokerGame Architecture

## Overview

PokerGame is a local single-player Texas Hold'em prototype built with Godot 4 and GDScript. The user plays against 1-5 AI opponents. The implementation keeps poker rules, AI, and UI in separate layers so rule fixes and AI tuning do not require UI rewrites.

The game is intentionally offline-only in v1. It does not use APIs, LLMs, Steamworks, accounts, real money, networking, or third-party poker libraries.

## Runtime Flow

The main scene is `res://scenes/main.tscn`, backed by `scripts/ui/main.gd`.

1. The main menu selects AI count and difficulty.
2. `PokerRound.start_new_match()` creates the human player plus AI opponents.
3. `PokerRound.start_next_hand()` shuffles, deals hole cards, posts blinds, and sets the first actor.
4. Human actions come from UI buttons and call `PokerRound.apply_action()`.
5. AI turns call `AiDecision.decide()` and then pass the returned action back through `PokerRound.apply_action()`.
6. The rules engine advances streets, resolves uncontested pots, or runs showdown.
7. The result panel shows winner payouts and offers the next hand or restart.

## Game Layer

`scripts/game/` contains the authoritative poker state and rules.

- `card.gd` defines card creation, labels, deck helpers, and known-card filtering.
- `deck.gd` owns a shuffled 52-card deck and drawing.
- `hand_evaluator.gd` evaluates the best 5-card hand from 5-7 cards and compares hand results.
- `table_state.gd` stores shared constants for stages, statuses, blinds, stack size, and actions.
- `poker_round.gd` owns table state, betting flow, legal action checks, side-pot construction, showdown, split pots, and hand lifecycle.

Important invariant: all actions must pass through `PokerRound.apply_action()`. UI and AI should never directly change stacks, bets, player status, or street progression.

## AI Layer

`scripts/ai/` contains local, rules-based AI only.

- `starting_hand_table.gd` scores preflop hole cards from 1-100 using rank, pairs, suitedness, gaps, and high-card value.
- `monte_carlo.gd` estimates postflop equity by simulating unknown opponent cards and remaining board cards.
- `personalities.gd` defines five hard-AI profiles: `TightAggressive`, `LooseAggressive`, `CallingStation`, `Rock`, and `Balanced`.
- `ai_decision.gd` combines equity, pot odds, current action cost, legal actions, and profile parameters into `fold/check/call/raise/all_in`.

Difficulty behavior:

- Simple: rough equity rules and low aggression.
- Medium: preflop starting-hand score, postflop rule equity, moderate pot-odds tolerance.
- Hard: preflop starting-hand score plus position and pressure; postflop Monte Carlo equity with the assigned personality profile.

## UI Layer

`scripts/ui/main.gd` builds the UI programmatically with Godot `Control` nodes. There are no custom art dependencies beyond `assets/icon.svg`.

The UI displays:

- Main menu difficulty and AI-count controls.
- Hand number, street, pot, current bet, and status message.
- Opponent seats, player seat, hole cards, community cards, stacks, bets, status, and AI personality label.
- Legal action buttons and a raise slider when raising is legal.
- Result panel with payout rows and next-hand/restart controls.

## Tests

`tests/test_runner.gd` is a Godot script test runner. It covers:

- 52 unique cards after shuffle/draw.
- Standard hand-rank detection and kicker comparison.
- Illegal check while facing a bet.
- Side-pot resolution.
- Split-pot resolution.
- Hard-AI personality assignment.
- AI legal action shape.
- Monte Carlo equity bounds.
