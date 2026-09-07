# PokerGame Architecture

## Overview

PokerGame is a local single-player Texas Hold'em prototype built with Godot 4 and GDScript. The player faces 1-5 local AI opponents. Poker rules, AI decisions, local profile persistence, and UI rendering are kept separate so visual work does not become a second source of poker state.

The game remains offline-only. It does not use APIs, LLMs, Steamworks, accounts, real money, networking, telemetry, or third-party poker libraries.

## Runtime Flow

The main scene is `res://scenes/main.tscn`, backed by `scripts/ui/main.gd`.

1. `_ready()` loads `user://poker_profile.cfg`, applies the bundled regular font after resource import, initializes local audio, and shows the main menu.
2. The menu restores AI count and difficulty and exposes local sound, action pace, help, and statistics through a settings popup.
3. Starting a match saves the selected settings and calls `PokerRound.start_new_match()`.
4. `PokerRound.start_next_hand()` shuffles, deals hole cards, posts blinds, records events, and sets the first actor.
5. Human actions come from the UI and call `PokerRound.apply_action()`.
6. AI turns compute `AiDecision.decide()` in an `AiTurnWorker` thread over a deep snapshot while the UI tracks a randomized delay. Only a result with the current match generation, hand, actor and street can pass through `PokerRound.apply_action()`. Other players' hole cards are removed from the snapshot.
7. The rules engine advances streets, resolves uncontested pots, or runs showdown through `HandEvaluator`.
8. The UI renders the full-screen table. The event log is a normally closed overlay drawer; opening it blocks UI-driven AI advancement and closing it resumes play.
9. During a match, the settings popup can pause play. The pause overlay blocks player input and AI advancement, and offers resume or return-to-menu. Both scheduled and pending AI callbacks re-check that the table is still active before applying an action.
10. Completed hands update local statistics once. The floating result dock shows payouts and offers the next hand or a restart.

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

The visible wait before an AI action belongs to the UI layer and does not change decision strength. Normal pace uses randomized 3-5 second delays for simple/medium and personality-specific ranges for hard. Fast pace uses 0.25-0.55 seconds. Computation overlaps the delay; pausing freezes the remaining delay and defers completed results.

## UI And Art Layer

`scripts/ui/main.gd` builds the interface programmatically with Godot `Control` nodes and theme overrides. It composes generated PNG textures from `assets/art/generated/` for the menu, title, table, characters, cards, action tags, neutral nameplates, and modular chips. Dynamic Chinese text, card ranks, suits, values, and event content remain runtime-rendered so game information stays exact. Buttons, fields, panels, sliders, blind-role badges, the pot amount plaque, and HUD chrome use hard-edged `StyleBoxFlat` or runtime-drawn controls instead of enlarged UI atlases.

The table is a fixed-aspect `AspectRatioContainer` stage (`TableStage`, ratio 1619:971 matching the table texture). The table texture's built-in dark margins double as standing room: character sprites anchored at each seat overlap the rail from outside, selling players sitting around the table. All seat elements are positioned with fractional anchors from `SEAT_LAYOUTS` so the layout holds at any window size:

- `SEAT_ORDERS_BY_PLAYER_COUNT` selects a balanced subset for 2-6 players while preserving the rules engine's increasing player index as a continuous counterclockwise path around the visible table.
- Portraits use the 4-state character sheets but stand outside the wooden rail. `Seat{n}Info` stays inside the former seat footprint and owns that player's hole cards, exact stack number, modular chip stack, role markers, and latest action. Folded players dim. The current actor uses a shader-generated alpha-contour brass pulse plus a small triangle; all-in and winner contours are stable red and gold. Nameplates remain neutral and no rectangular frame represents turn state.
- `D`, `小盲`, and `大盲` are runtime text over a modular chip top and are attached to the correct `Seat{n}RoleMarkers`. Multiple roles can coexist on one seat.
- Community cards render compact and centered through `CommunityCards`. `PotDisplay` uses a maximum 3x8 module stack and a small exact-number plaque; seat stacks use at most 2x5 visible modules. `_chip_breakdown()` greedily decomposes `[500, 100, 25, 5, 1]`; visible stacks compress at capacity while the labels remain authoritative.
- The full-screen stage has no persistent header, footer, or log column. `FloatingStatus` sits top-left, `UtilityButtons` top-right, and `ActionDock` bottom-right. The raise controls expand only when requested. `LogDrawer` overlays 400 pixels from the right and does not reduce the table. Its unread dot compares the latest event's hand/type/text fingerprint without changing the rules-engine event schema.
- A dithered lamplight overlay (`table/table-light-overlay.png`) sits above the table art at reduced opacity for the late-night light pool.

Key widgets carry stable node names (`TableStageRoot`, `TableFeltSafeZone`, `FloatingStatus`, `LogDrawer`, `ActionDock`, `PotDisplay`, `CommunityCards`, and `Seat{n}Portrait/Info/HoleCards/StackChips/RoleMarkers/Bet/Plate`) so the UI probes can assert geometry and state ownership.

The UI displays:

- Chinese main menu with AI-count and difficulty controls.
- A settings popup for local sound/pace switches and aggregate statistics, including a two-step reset confirmation.
- During a match, the settings popup also exposes pause; the full-screen pause overlay offers resume and return-to-menu.
- A compact floating hand/street/status capsule, community cards, player seats, role markers, stacks, bets, and a physical pot display.
- An on-demand right-side event-log drawer containing only actual game events.
- A bottom-right dock containing only legal actions; raise amount controls appear only after expanding raise.
- Result rows with payout and hand-rank text, followed by next-hand or restart controls.

The canonical visual constraints are documented in `docs/art-direction.md`. Asset inventory, source/final file conventions, and production cleanup are documented in `assets/art/generated/README.md`.

## Local Persistence And Audio

- `LocalProfile` stores AI count, difficulty, sound enabled, fast pace enabled, total hands, wins, net profit, and maximum single-hand win.
- Values are normalized when loaded; missing or invalid values fall back to defaults.
- Statistics are aggregate local records, not hand histories, accounts, or cloud saves.
- Action sounds are generated locally with `AudioStreamGenerator`; there are no downloaded audio assets or network calls.
- No music toggle or music track is shipped. The old unused preference is ignored on load.
- Saves write to a temporary file and then replace the profile; failure returns false and the UI shows an error popup. Tests and package self-test use separate profile paths.

## Tests

- `tests/test_runner.gd` covers cards, hand evaluation, action legality, side/split pots, Chinese result text, event history, local profile round-trips, AI profiles/actions, AI sampling, and Monte Carlo bounds.
- `tests/ui_layout_probe.gd` checks menu/settings and the table at 1280x720, 1440x900, and 1920x1080. It verifies the 78% table width, 1619:971 ratio, floating controls, portrait/felt safety, seat bindings, role markers, log pause/unread behavior, hard-edged `StyleBoxFlat` states, chip breakdowns, and visible-stack capacities.
- `tests/ui_playthrough_probe.gd` scripts a full player click-through (menu, settings with reset confirmation, log drawer, pause/resume, collapsed/expanded actions, safe hand, next-hand all-in, result, restart, and quit-to-menu during an AI turn) at three window sizes (1280x720, 1440x900, 1920x1080). It saves per-state screenshots to `/tmp/poker_audit/` and asserts viewport bounds, text fit, seat-widget layering, control overlap, nearest filtering, and the AI pause/quit safety gates. Windowed, not part of the headless gate.
- `tests/ui_table_snapshot.gd` is a visual dev tool: it renders preflop tables with 1/3/5 AI plus rigged flop and showdown states and saves PNGs to `/tmp/poker_table_*.png` for manual layout review (opens a window briefly; not part of the headless test gate).

## Desktop release changes

The release branch adds exact full-big-blind call amounts for short blinds, all-in raise-right checks, no betting into a dry side pot, refunds for uncontested pots, button-relative odd chips, dead button/small blind handling after elimination, and immediate human-bust match completion. Shuffles use a per-round RNG whose seed tests can fix; production randomizes it.

`AiTurnWorker` never touches the active scene tree or live poker state. `_show_menu()` and `_on_start_pressed()` invalidate the generation; completed stale results are discarded. Closing the scene joins the worker. Queued human input checks that the table is interactive and it is still the human turn before applying an action. Infinite portrait tweens bind to their sprite node, so redraws free the material and animation together.

The default UI font is the bundled Noto Sans SC with an explicit weight-400 `FontVariation`. Help explains the goal, betting and settlement, and leaving a match asks for confirmation. The game intentionally retains aggregate completed-hand statistics, not an unfinished match.

`export_presets.cfg` explicitly lists script and asset roots, including global classes that selected-scene export does not reliably discover. `tools/bootstrap_godot.py` verifies the official Godot 4.7.2 standard editor/templates against SHA-512; `tools/build_release.py` builds versioned ZIPs, hashes them, and runs a native package self-test outside the source checkout. The self-test is a fixed internal diagnostic (`--headless -- --self-test`), not support for arbitrary external scripts. It uses a separate cache profile and does not run in a graphical game.

Release requirements live in [planning/release-plan.md](planning/release-plan.md); build logs, manifests, CI and actual packaged runs establish implementation and verification state. Update this document with changes to these mechanisms.
