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

Betting invariant: a short all-in below the minimum raise changes the amount to call but does not reopen raising for players who already called or raised. A prior checker may still raise an opening wager, and cumulative short all-ins reopen raising once their increase reaches a full minimum raise.

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

`scripts/ui/main.gd` builds the interface programmatically with Godot `Control` nodes and theme overrides. It composes generated PNG textures from `assets/art/generated/` for the menu, title, table, characters, cards, blind tokens, chip stacks, panel frames, HUD icons, result banners, form fields, and button states. Dynamic Chinese text, card ranks, suits, values, and event content remain runtime-rendered so game information stays exact.

The table is a fixed-aspect `AspectRatioContainer` stage (`TableStage`, ratio 1619:971 matching the table texture). The table texture's built-in dark margins double as standing room: character sprites anchored at each seat overlap the rail from outside, selling players sitting around the table. All seat elements are positioned with fractional anchors from `SEAT_LAYOUTS` so the layout holds at any window size:

- `SEAT_ORDERS_BY_PLAYER_COUNT` selects a balanced subset for 2-6 players while preserving the rules engine's increasing player index as a continuous counterclockwise path around the visible table.
- Characters use the 4-state sheets (idle/thinking/betting/folded); folded players dim, and the current actor and hand winners get a brass ring (all-in gets red).
- Hole cards lie on the felt beside or below each seat (the human's cards sit left of the human character so they never cover the face); AI cards stay face down until showdown, and folded hands are hidden.
- A seat's current action renders as a textured speech tag (`Seat{n}Bet`, brass for raises/blinds, blue-gray for calls/checks, dim for folds; tail points toward the seat) including the amount; the tag replaces per-seat chip piles so tags never collide. Blinds render as token discs on the felt; name and stack sit on a textured nameplate over the character's lower edge (brass state for the current actor and winners, red for all-in).
- Community cards render compact and centered through `CommunityCards`; the pot instrument (`PotLabel`) renders chips plus the pot total below them. Bet/card/pot holders use point anchors with both grow directions (`_stage_place_centered`) so content stays centered on its layout point instead of overflowing from a fixed corner. Dynamic pot chips use `_chip_stack_view()`: amount/big-blind ratio picks one of four stack tiers and a color column.
- Chrome panels (header, event log, action bar) keep their nine-slice content margins at or above the texture slice margins so controls never draw over the decorative frame. The showdown result view is a single compact horizontal strip (banner, winner rows, next-hand/restart buttons) so the table stage keeps its full size at hand-over. A dithered lamplight overlay (`table/table-light-overlay.png`) sits above the table art at reduced opacity for the late-night light pool.

The header, action bar, and event log use nine-sliced panel-atlas frames with HUD icons; key widgets carry stable node names (`HeaderPanel`, `EventLogPanel`, `ActionPanel`, `PotLabel`, `CommunityCards`, `Seat{n}Character/HoleCards/Bet/Plate/Token`) so the UI probes can assert their geometry.

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
- `tests/ui_layout_probe.gd` checks the 1280x720 menu/settings flow and table layout at 1280x720, 1440x900, and 1920x1080 (stretch content 1280x720/1152x720). It also verifies critical generated-asset integration, nearest-neighbor button rendering, event-log compaction, and in-place statistics reset confirmation.
- `tests/ui_playthrough_probe.gd` scripts a full player click-through (menu, settings with reset confirmation, a safe hand, a next-hand all-in, result, restart) at two window sizes, saves per-state screenshots to `/tmp/poker_audit/`, and asserts the machine-checkable UI acceptance metrics in `docs/planning/ui-acceptance.md` (viewport bounds, text fit, panel content margins, seat-widget layering, nearest filtering). Windowed, not part of the headless gate.
- `tests/ui_table_snapshot.gd` is a visual dev tool: it renders preflop tables with 1/3/5 AI plus rigged flop and showdown states and saves PNGs to `/tmp/poker_table_*.png` for manual layout review (opens a window briefly; not part of the headless test gate).
