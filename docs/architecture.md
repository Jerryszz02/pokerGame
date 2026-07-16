# PokerGame Architecture

## Overview

PokerGame is a local single-player Texas Hold'em prototype built with Godot 4 and GDScript. The player faces 1-5 local AI opponents. Poker rules, AI decisions, local profile persistence, and UI rendering are kept separate so visual work does not become a second source of poker state.

The game remains offline-only. It does not use APIs, LLMs, Steamworks, accounts, real money, networking, telemetry, or third-party poker libraries.

## Runtime Flow

The main scene is `res://scenes/main.tscn`, backed by `scripts/ui/main.gd`.

1. `_ready()` loads `user://poker_profile.cfg`, initializes local audio, and shows the main menu.
2. The menu restores AI count and difficulty and exposes local sound, music, and statistics through a settings popup.
3. Starting a match saves the selected settings and calls `PokerRound.start_new_match()`.
4. `PokerRound.start_next_hand()` shuffles, deals hole cards, posts blinds, records events, and sets the first actor.
5. Human actions come from the UI and call `PokerRound.apply_action()`.
6. AI turns wait for a randomized difficulty/personality-dependent delay, call `AiDecision.decide()`, and pass the returned action through `PokerRound.apply_action()`.
7. The rules engine advances streets, resolves uncontested pots, or runs showdown through `HandEvaluator`.
8. The UI renders the current table and recent event log. Completed hands update the local statistics once.
9. The result panel shows payouts and offers the next hand or a restart.

## Game Layer

`scripts/game/` contains authoritative poker state plus the small local profile boundary.

- `card.gd` defines card creation, labels, deck helpers, and known-card filtering.
- `deck.gd` owns a shuffled 52-card deck and drawing.
- `hand_evaluator.gd` evaluates the best 5-card hand from 5-7 cards, compares results, and supplies Chinese rank names.
- `table_state.gd` stores shared stage, player-status, blind, stack, and action constants.
- `poker_round.gd` owns table state, legal-action checks, betting flow, durable blind positions, event history, side pots, showdown, split pots, and hand lifecycle.
- `local_profile.gd` normalizes and persists local menu settings and aggregate statistics through Godot `ConfigFile` at `user://poker_profile.cfg`.

Important invariant: all human and AI poker actions must pass through `PokerRound.apply_action()`. UI and AI must not directly change stacks, bets, player status, or street progression.

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

The visible wait before an AI action belongs to the UI layer and does not change decision strength. Simple and medium use a randomized 3-5 second delay; hard uses personality-specific ranges defined in `scripts/ui/main.gd`.

## UI And Art Layer

`scripts/ui/main.gd` builds the interface programmatically with Godot `Control` nodes and theme overrides. It now composes generated PNG textures from `assets/art/generated/` for the menu, title, table, characters, cards, blind tokens, chip stacks, form fields, and button states. Dynamic Chinese text, card ranks, suits, values, and event content remain runtime-rendered so game information stays exact.

The UI displays:

- Chinese main menu with AI-count and difficulty controls.
- A settings popup for local sound/music switches and aggregate statistics, including a two-step reset confirmation.
- Hand, street, pot, current bet, status message, community cards, player seats, blind markers, stacks, and bets.
- A right-side event log containing only actual recent game events.
- Legal action buttons plus raise amount controls when raising is legal.
- Result rows with payout and hand-rank text, followed by next-hand or restart controls.

The canonical visual constraints are documented in `docs/art-direction.md`. Asset inventory, source/final file conventions, and production cleanup are documented in `assets/art/generated/README.md`.

## Local Persistence And Audio

- `LocalProfile` stores AI count, difficulty, sound enabled, music enabled, total hands, wins, net profit, and maximum single-hand win.
- Values are normalized when loaded; missing or invalid values fall back to defaults.
- Statistics are aggregate local records, not hand histories, accounts, or cloud saves.
- Action sounds are generated locally with `AudioStreamGenerator`; there are no downloaded audio assets or network calls.
- `music_enabled` is persisted and exposed in settings, but the current code does not provide a music track.

## Tests

- `tests/test_runner.gd` covers cards, hand evaluation, action legality, side/split pots, Chinese result text, event history, local profile round-trips, AI profiles/actions, AI sampling, and Monte Carlo bounds.
- `tests/ui_layout_probe.gd` checks the 1280x720 menu/settings flow and table layout at 1280x720, 1440x900, and 1920x1080. It also verifies critical generated-asset integration, nearest-neighbor button rendering, event-log compaction, and in-place statistics reset confirmation.
