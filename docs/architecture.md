# PokerGame Architecture

## Overview

PokerGame is an offline Texas Hold'em practice game built with Godot 4 and GDScript. The player faces 1-5 local AI opponents. Poker rules, AI decisions, local profile persistence, and UI rendering are kept separate so visual work does not become a second source of poker state.

Desktop play is offline; the Web build loads assets over HTTP(S), then runs rules and opponent AI locally. Version 1.3.0 provides local numerical analysis and rule-based replay prose, then automatically requests a cloud explanation from an owner-operated service. A valid response replaces the local prose; failures leave the local review available. The Cloudflare Worker in `services/coach-worker/` calls DeepSeek using a Secret binding; `tools/coach_service.py` remains a loopback development alternative that reads the owner's `.env.local`. The Godot client contains only a public service URL. There is no multiplayer backend, Steamworks integration, game account, real-money wagering, game telemetry, or third-party poker library. Current source and public release status are tracked in [the planning index](planning/README.md); cloud configuration and verification are tracked in the [cloud service runbook](runbook.md#cloudflare-文字复盘服务).

## Runtime Flow

The main scene is `res://scenes/main.tscn`, backed by `scripts/ui/main.gd`.

1. `_ready()` loads `user://poker_profile.cfg`, applies the bundled regular font after resource import, initializes local audio, and shows the main menu.
2. The home page routes to tutorials, free play, or the basic practice flow. Configuration keeps an unsubmitted draft; a new match receives a copy of the selected opponent count, difficulty, stack and fixed blinds.
3. Starting a match saves the selected settings and calls `PokerRound.start_new_match()`.
4. `PokerRound.start_next_hand()` shuffles, deals hole cards, posts blinds, records events, and sets the first actor.
5. Human actions come from the UI and call `PokerRound.apply_action()`.
6. AI turns compute `AiDecision.decide()` in an `AiTurnWorker` thread over a deep snapshot while the UI tracks a randomized delay. Only a result with the current match generation, hand, actor and street can pass through `PokerRound.apply_action()`. The snapshot contains only the actor's own cards/profile, public player/betting fields, the board and public action history. Opponents' cards, profiles, private notes/results and the real remaining deck are excluded.
7. The rules engine advances streets, resolves uncontested pots, or runs showdown through `HandEvaluator`.
8. The UI renders the full-screen table. The event log is a normally closed overlay drawer; opening it blocks UI-driven AI advancement and closing it resumes play.
9. During a match, the settings popup can pause play. The pause overlay blocks player input and AI advancement, and offers resume or return-to-menu. Both scheduled and pending AI callbacks re-check that the table is still active before applying an action.
10. Completed hands expose an immutable structured record. The UI submits it to `PracticeStore`, retains failed submissions for retry, and offers replay or the next hand. Practice can pause each hand or advance after three active seconds; overlays freeze that timer.

## Game Layer

`scripts/game/` contains authoritative poker state plus the small local profile boundary.

- `card.gd` defines card creation, labels, deck helpers, and known-card filtering.
- `deck.gd` owns a shuffled 52-card deck and drawing.
- `hand_evaluator.gd` evaluates the best 5-card hand from 5-7 cards, compares results, and supplies Chinese rank names.
- `table_state.gd` stores shared stage, player-status, blind, stack, and action constants.
- `poker_round.gd` owns table state, legal-action checks, betting flow, durable blind positions, event history, side pots, showdown, split pots, and hand lifecycle.
- `match_config.gd` validates the supported integer stack/blind presets and normalizes old preferences.
- `local_profile.gd` stores versioned preferences and legacy aggregate statistics at `user://poker_profile.cfg`, guarding newer-format files against overwrite.
- `practice_store.gd` owns atomic completed-hand files, a compact cumulative ledger, match outcomes, separate three-hand guided progress, legacy seven-lesson progress, achievements, and the one-time legacy summary import.
- `tutorial_controller.gd` prepares three independent deterministic teaching hands. Short dialogue and focused table controls guide the first two hands; the third permits free legal actions. All actions use `PokerRound.apply_action()` and normal showdown evaluation. Guided hands do not enter ordinary records or statistics.
- `poker_reference.gd` supplies localized rules and nine hand-rank examples verified with `HandEvaluator`.
- `localization.gd` selects the system/Chinese/English locale and renders translated templates from structured game data without changing poker state or saved records.

`public_action_history` records successful voluntary actions with the before-action board, pot, price, stacks and actual payment. It resets each hand and does not inherit the text event log's 40-entry truncation or private decision labels. It is in-memory strategy input, not a persistent replay system.

Important invariant: all human and AI poker actions must pass through `PokerRound.apply_action()`. UI and AI must not directly change stacks, bets, player status, or street progression.

Betting invariant: a short all-in below the minimum raise changes the amount to call but does not reopen raising for players who already called or raised. A prior checker may still raise an opening wager, and cumulative short all-ins reopen raising once their increase reaches a full minimum raise.

## AI Layer

`scripts/ai/` contains local heuristic strategies and bounded simulations. There is no trained neural network, CFR solver or cross-session opponent learning. Regression coverage is described in [the test plan](planning/test-plan.md#算法与教练回归).

- `starting_hand_table.gd` represents all 169 preflop classes and supplies heuristic opening, continuing and reraising frequencies conditioned on position, players, prior raises, price in big blinds, effective stack and own style. The old `score()`/`label()` API remains compatible; neither the score nor the strength ordering is calibrated equity.
- `opponent_range.gd` estimates weighted possible holdings from public actions in the current hand. It uses the board as it appeared at each observation and excludes known cards. A neutral prior and nonzero bluff support prevent an observed raise from being treated as knowledge of a specific hand.
- `monte_carlo.gd` estimates equity with weighted possible opponent holdings and remaining public cards, counting ties by their pot share. It accepts an independent seeded RNG for tests and does not consume the game's dealing RNG. Worlds are shared across candidate actions.
- `action_ev.gd` compares legal fold/check/call, pot-fraction raises and all-in. The model permits one round of opponent fold/call responses and then checks down to showdown. Responses use current information; sampled future boards are only used for settlement. Each contribution layer has its own eligible winners, including dead money, capped all-ins, split pots and unmatched-chip returns. EV is expected eligible payout minus NEW chips invested; already committed chips are sunk.
- `personalities.gd` keeps five presets: `TightAggressive`, `LooseAggressive`, `CallingStation`, `Rock`, and `Balanced`. `get_profile(name, overrides)` and `normalize_profile()` validate custom style fields; `apply_difficulty()` controls bounded effort and decision noise separately.
- `ai_decision.gd` returns compatible `action_type`, `amount`, and `decision_label` plus `analysis` diagnostics. Postflop personality preferences choose between sufficiently close candidate EVs. The main thread still submits every action through the rules engine.

Difficulty behavior:

- Simple: preflop ranges and cheap postflop rules.
- Medium: preflop ranges and bounded postflop range/EV comparison.
- Hard: preflop ranges and more postflop simulation/history detail with less choice noise.
- Hell: `FiniteSearch` on every street, with at most 16 sampled worlds, depth 8 and a 600 ms budget. Complete scored results use the personality/noise chooser; unavailable or empty results use a conservative check/fold-first fallback.

Medium/hard/hell accept a supplied personality through the seat's `personality` field. Free-play and practice setup expose one whole-table opponent-style selector for these three difficulties; the five shipped `PersonalityProfiles` IDs apply a named preset to every AI seat as an independent copy, `random` draws per seat, and `default` preserves each difficulty's behavior. Simple hides the selector without discarding the remembered choice. The selection is stored as the additive, validated `opponent_personality` config field on `MatchConfig`/`LocalProfile`; configs and hand histories without it remain valid and normalize to `default`. Difficulty still owns effort/noise, and personality presets only change the four style fields `aggression`, `looseness`, `bluff_rate`, and `call_tolerance`; mathematical parameter combinations do not establish distinct or stronger opponents.

The `ActionEV` model used by medium/hard does not search future betting streets or opponent reraises. Hell and replay analysis use bounded `FiniteSearch` rollouts through the rules engine, with a showdown estimate at the cutoff. Both models describe estimates under stated assumptions, not a proven best move or GTO advice. Passing mathematical/behavior tests does not establish expert-level playing strength.

The visible wait before an AI action belongs to the UI layer and does not change decision strength. Normal pace uses randomized 3-5 second delays for simple/medium/hell and personality-specific ranges for hard. Fast pace uses 0.25-0.55 seconds. Computation overlaps the delay; pausing freezes the remaining delay and defers completed results.

## UI And Art Layer

`scripts/ui/main.gd` coordinates live play, configuration, and the guided tutorial on the real table. `scripts/ui/practice_views.gd` renders records, filtered statistics and immutable replay frames without assigning replay state to the live game. The UI builds the interface programmatically with Godot `Control` nodes and theme overrides. It composes generated PNG textures from `assets/art/generated/` for the menu, title, table, characters, cards, action tags, neutral nameplates, and modular chips. Dynamic localized text, card ranks, suits, values, and event content remain runtime-rendered so game information stays exact. Buttons, fields, panels, sliders, blind-role badges, the pot amount plaque, and HUD chrome use hard-edged `StyleBoxFlat` or runtime-drawn controls instead of enlarged UI atlases.

The table is a fixed-aspect `AspectRatioContainer` stage (`TableStage`, ratio 1619:971 matching the table texture). The table texture's built-in dark margins double as standing room: character sprites anchored at each seat overlap the rail from outside, selling players sitting around the table. All seat elements are positioned with fractional anchors from `SEAT_LAYOUTS` so the layout holds at any window size:

- `SEAT_ORDERS_BY_PLAYER_COUNT` selects a balanced subset for 2-6 players while preserving the rules engine's increasing player index as a continuous counterclockwise path around the visible table.
- Portraits use the 4-state character sheets but stand outside the wooden rail. `Seat{n}Info` stays inside the former seat footprint and owns that player's hole cards, exact stack number, modular chip stack, role markers, and latest action. Folded players dim. The current actor uses a shader-generated alpha-contour brass pulse plus a small triangle; all-in and winner contours are stable red and gold. Nameplates remain neutral and no rectangular frame represents turn state.
- `D`, `小盲`, and `大盲` are runtime text over a modular chip top and are attached to the correct `Seat{n}RoleMarkers`. Multiple roles can coexist on one seat.
- Community cards render compact and centered through `CommunityCards`. `PotDisplay` uses a maximum 3x8 module stack and a small exact-number plaque; seat stacks use at most 2x5 visible modules. `_chip_breakdown()` greedily decomposes `[500, 100, 25, 5, 1]`; visible stacks compress at capacity while the labels remain authoritative.
- The full-screen stage has no persistent header, footer, or log column. `FloatingStatus` sits top-left, `UtilityButtons` top-right, and `ActionDock` bottom-right. The raise controls expand only when requested. `LogDrawer` overlays 400 pixels from the right and does not reduce the table. Its unread dot compares the latest event's hand/type/text fingerprint without changing the rules-engine event schema.
- A dithered lamplight overlay (`table/table-light-overlay.png`) sits above the table art at reduced opacity for the late-night light pool.

Key widgets carry stable node names (`TableStageRoot`, `TableFeltSafeZone`, `FloatingStatus`, `LogDrawer`, `ActionDock`, `PotDisplay`, `CommunityCards`, and `Seat{n}Portrait/Info/HoleCards/StackChips/RoleMarkers/Bet/Plate`) so the UI probes can assert geometry and state ownership.

The UI displays:

- Localized home menu with tutorials, free play and basic practice; match configuration includes AI count, difficulty, starting stacks and blinds.
- A settings popup for sound/pace, two scrollable references and the explicitly labeled legacy summary reset. New cumulative statistics and achievements have their own page.
- During a match, the settings popup also exposes pause; the full-screen pause overlay offers resume and return-to-menu.
- A compact floating hand/street/status capsule, community cards, player seats, role markers, stacks, bets, and a physical pot display.
- An on-demand right-side event-log drawer containing only actual game events.
- A bottom-right dock containing only legal actions; raise amount controls appear only after expanding raise.
- Result rows with payout and hand-rank text, followed by next-hand or restart controls.

The canonical visual constraints are documented in `docs/art-direction.md`. Asset inventory, source/final file conventions, and production cleanup are documented in `assets/art/generated/README.md`.

## Local Persistence And Audio

- `LocalProfile` stores preferences plus the preserved old aggregate totals. Invalid fields recover with a visible notice; an unknown newer version remains read-only.
- `user://poker_practice/hand_<id>.json` stores each finished hand (format version 1). Frames include dealt hole cards, the board at that moment, action amounts, bets, stacks, blind/button positions, refunds and final per-pot payouts. IDs use independent cryptographic randomness and do not alter the poker shuffle RNG.
- `user://poker_practice/profile.json` stores the compact per-hand ledger, match outcomes, legacy summary, progress and achievements. It contains no full replay frames. The compact ledger grows with played hands so deletion can retain cumulative filters and deduplication; full replay files are limited to 1000. At capacity, saving pauses for explicit manual cleanup and retry; no replay is silently evicted.
- A hand file is written before its metadata. Failed metadata writes retain the durable record for retry/recovery. Deletion persists the ledger before removing the full record. Invalid or unknown hand files are skipped and reported without removing valid siblings; damaged/newer metadata is read-only.
- Wins mean an exclusive award from any pot; splits are tracked separately and may overlap with wins. Positive-net hands are a separate measure. Raw profit is grouped by blind pair, with BB totals also available. Rank counts require actual showdown participation; tutorial and replay activity never adds ordinary hands. Early departures are separate from completed won/lost matches.
- The UI retains unsaved hand and match submissions in memory and warns on exit. This does not provide unfinished-match resume. Replay is a deep copy; hero-time view hides unrevealed opponents and future board cards, while all-knowing view is restricted to completed hands. A replay achievement requires visiting every frame.
- Test scenes derive an isolated practice directory from their injected profile path; tests and the fixed source/package self-test do not use player data.
- `scripts/ui/game_audio.gd` plays bundled Airport Lounge background music and Kenney card/chip effects through `AudioStreamPlayer` nodes. Music/effects have separate saved volumes; the node survives page rebuilds and Web playback waits for a real input event. Runtime audio does not contact asset sites. Attribution and licenses are bundled; there is no game telemetry, account or cloud save.
- Opponent decisions use the difficulty-specific models described above. The coach captures a versioned, before-action `decision_context` on successful action frames. The game-owned `DecisionSnapshot` owns the neutral capture/restore/schema, so `PokerRound` preloads only that game module and never depends on AI coaching code; the AI-layer `CoachContext` is a thin compatibility facade that keeps the saved version/kind and existing callers unchanged. It validates reopening rights and visible information; `CoachAnalysis.live` estimates fractional showdown equity, while `FiniteSearch` compares future-action rollouts through the rules engine. `CoachService` coordinates background jobs and `PlayerStyle` keeps versioned raw counters in the compact ledger. Only displaying successful live assistance marks a hand assisted. See [coach/radar definitions](#coach-and-player-style) and [regression coverage](planning/test-plan.md#算法与教练回归); finite search does not establish optimality or stronger play.

Hand records retain only the peak observed within that hand. The double-stack achievement requires crossing the threshold during that hand, so an inherited starting stack cannot reattribute an earlier achievement. Match persistence waits until every pending hand of that match has been committed.

## Coach And Player Style

Decision analysis uses only the acting player's cards and the board, betting rights and public actions visible before the decision. Opponent private cards, profiles, future board cards and results cannot influence the neutral estimates. Old replays without a valid versioned `decision_context` remain unanalyzable; omniscient replay display does not change that boundary. Candidate actions share sampled worlds, include the actual raise size, and are compared using paired sampling error. Missing contexts, cancelled jobs and zero effective samples produce no numerical recommendation; insufficient evidence and close estimates remain explicitly uncertain.

`PlayerStyle` version 1 stores mergeable per-hand counts in the compact ledger. Statistics and radar use the same mode, assistance, difficulty, player-count, stack-depth and time filters. Deleting a replay or retrying a save must not change accumulated counts. The six axes describe play and conditional all-in luck, not skill; each retains its denominator and is unavailable below its sample threshold. Missing axes are not drawn as zero, and the polygon fills only when every axis is available.

| Axis | Definition | Display threshold |
| --- | --- | --- |
| 运气 / Luck | Actual minus expected payout after betting is locked, accumulated in BB; normalized as `clamp(0.5 + z / 6, 0, 1)`, where `z = total payout deviation / sqrt(total payout variance)` | 5 qualifying all-in hands with nonzero result variance |
| 进攻 / Aggression | Actions that increase the table's bet price / voluntary decision opportunities; an all-in call counts as a call | 30 decisions |
| 防守 / Defense | Calls or raises / decisions facing a positive call price | 30 priced decisions |
| 冒险 / Risk | Mean of `additional payment / stack before action * (1 - equity)` | 30 decisions with an equity estimate |
| 入池 / VPIP | Hands with voluntary preflop payment / hands with a preflop decision; forced blinds are excluded | 20 hands |
| 施压 / Pressure | Price-increasing actions / low-equity opportunities, where `equity < min(0.4, 1 / live players)` | 30 low-equity opportunities |

Luck uses complete showdowns with at least two contenders, undealt board cards and no voluntary action after the all-in lock. Only this retrospective calculation uses the contenders' showdown cards; folded private cards are not blockers. Pot eligibility, refunds and odd chips use the rules engine. River-only locks, incomplete records and unresolved or zero variance do not produce a luck rating. It is not a measure of all luck during a match. Sample thresholds are display conventions, not evidence of a stable skill assessment; automated correctness and performance checks do not establish expert playing strength.

## Tests

- `tests/practice_save_retry_test.gd` checks match persistence ordering during capacity failure and recovery.

- `tests/practice_data_test.gd` covers all 80 count/stake/blind combinations, record fidelity and isolation, multi-pot classification, atomic retry, migration, corrupt/future files, filtering, milestones and retained statistics after deletion.
- `tests/tutorial_test.gd` covers all three guided hands, deterministic restart, legal actions, and real payouts.
- `tests/practice_ui_probe.gd` drives mode/configuration, references, tutorial completion, real replay traversal, filter controls, isolation and practice auto-advance at three sizes. Its windowed run captures `/tmp/poker_practice_audit/`.

- `tests/test_ai_strategy.gd` checks all 169 preflop classes, position/stack/price scaling, concrete suit-aware posteriors, blocker-weighted and joint sampling frequencies, analytic side-pot/action EVs, response information timing, bounded profiles and personality/category behavior.
- `tests/test_ai_observations.gd` checks successful-action history, resets and deep copies, private-data exclusion from snapshots, and seeded decision invariance when hidden opponent information changes.
- `tests/test_runner.gd` covers cards, hand evaluation, action legality, side/split pots, Chinese result text, event history, local profile round-trips, AI profiles/actions, AI sampling, and Monte Carlo bounds.
- `tests/ui_layout_probe.gd` checks menu/settings and the table at 1280x720, 1440x900, and 1920x1080. It verifies the 78% table width, 1619:971 ratio, floating controls, portrait/felt safety, seat bindings, role markers, log pause/unread behavior, hard-edged `StyleBoxFlat` states, chip breakdowns, and visible-stack capacities.
- `tests/ui_playthrough_probe.gd` scripts a full player click-through (menu, settings with reset confirmation, log drawer, pause/resume, collapsed/expanded actions, safe hand, next-hand all-in, result, restart, and quit-to-menu during an AI turn) at three window sizes (1280x720, 1440x900, 1920x1080). It saves per-state screenshots to `/tmp/poker_audit/` and asserts viewport bounds, text fit, seat-widget layering, control overlap, nearest filtering, and the AI pause/quit safety gates. Windowed, not part of the headless gate.
- `tests/ui_table_snapshot.gd` is a visual dev tool: it renders preflop tables with 1/3/5 AI plus rigged flop and showdown states and saves PNGs to `/tmp/poker_table_*.png` for manual layout review (opens a window briefly; not part of the headless test gate).

## Desktop release changes

The release branch adds exact full-big-blind call amounts for short blinds, all-in raise-right checks, no betting into a dry side pot, refunds for uncontested pots, button-relative odd chips, dead button/small blind handling after elimination, and immediate human-bust match completion. Shuffles use a per-round RNG whose seed tests can fix; production randomizes it.

`AiTurnWorker` never touches the active scene tree or live poker state. `_show_menu()` and `_on_start_pressed()` invalidate the generation; completed stale results are discarded. Closing the scene joins the worker. Queued human input checks that the table is interactive and it is still the human turn before applying an action. Infinite portrait tweens bind to their sprite node, so redraws free the material and animation together.

The default UI font is the bundled Noto Sans SC with an explicit weight-400 `FontVariation`. Help explains the goal, betting and settlement, and leaving a match asks for confirmation. The game retains completed-hand replays and cumulative results, but does not resume unfinished matches.

`export_presets.cfg` explicitly lists script and asset roots, including global classes that selected-scene export does not reliably discover. `tools/bootstrap_godot.py` verifies the official Godot 4.7.2 standard editor/templates against SHA-512; `tools/build_release.py` builds versioned ZIPs, hashes them, and runs a native package self-test outside the source checkout. The self-test is a fixed internal diagnostic (`--headless -- --self-test`), not support for arbitrary external scripts. It uses a separate cache profile and does not run in a graphical game.

Release requirements live in [planning/release-plan.md](planning/release-plan.md); build logs, manifests, CI and actual packaged runs establish implementation and verification state. Update this document with changes to these mechanisms.

## Written Replay Review

Opening a replay starts the bounded local analysis queue automatically. `LocalReplayReview` immediately turns up to twelve allowlisted numerical decision summaries into at most three written observations in the selected language. It reports actual and alternative EV, their gap in BB and the shared sample count. Supported differences rank first by gap, followed by close estimates, then insufficient samples; original decision numbers are preserved. It uses the existing paired-error assessment instead of adding an arbitrary mistake threshold. Rules distinguish matching actions, raise sizes, alternative actions and negative returns; an all-in is not assumed to be a raise. Missing, non-finite, inconsistent or zero-sample facts produce no advice. No final outcome or hidden cards enter this layer.

`DeepSeekReview` optionally sends the same bounded summaries and language to the URL in `coach/service_url`. The local explanation remains readable while the request is pending, and validated cloud prose replaces it on success. The UI explicitly labels the local source. There are no player key fields or generation buttons. Seeking and omniscient-view changes preserve the request; leaving a replay cancels the client wait and invalidates stale callbacks. The client caches up to 64 results for an hour and failed requests for a minute. No service request is made when local analysis is unavailable.

Both services accept only versioned numerical summaries, construct a fixed prompt/model request, and keep credentials out of responses and logs. The Worker uses one fixed-name SQLite Durable Object for persistent global admission and bounded result caching. It reserves an attempted call before contacting DeepSeek, counts failures, and prevents concurrent requests or object eviction from resetting the rolling quota. Matching in-flight requests coalesce. The default budget is six new provider attempts per minute and one hundred per rolling twenty-four hours across all players; successful results cache for one hour and failures for one minute, with at most 128 entries. The Python development alternative uses per-process memory and resets its counters on restart.

The public Worker accepts native clients and exact configured browser origins. CORS is not authentication: this is a public anonymous endpoint whose fixed-purpose request schema and global provider-call cap bound expenditure. It does not establish that a caller is a legitimate player, and one caller can exhaust the shared allowance. No game accounts or client-side shared secret are introduced. Cloudflare and provider operational limits remain independent of the application quota.

Both service and client validate decision references and qualitative output before display. Provider text cannot replace local EV values or poker actions. Missing configuration, transport errors, rejected output or exhausted limits retain the local rule-based written review as well as the numerical analysis. The fallback does not enter the remote success cache, so the existing one-minute failure cooldown still permits recovery. These prose filters are conservative checks, not a proof that every natural-language statement is correct. See the [cloud service setup](runbook.md#cloudflare-文字复盘服务) and [local service setup](runbook.md#本机文字复盘服务).
