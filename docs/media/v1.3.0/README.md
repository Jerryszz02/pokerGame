# v1.3.0 devlog media

Prepared on 2026-09-18. **The user resumed preparation of the unpublished draft.** These assets do not indicate a released build. The source project still declares version `1.2.0`.

## Draft materials

- [English Devlog](../../releases/1.3.0-devlog.md)
- [HTML body](../../releases/1.3.0-devlog.html), currently using local image paths
- [Local themed preview](../../releases/1.3.0-devlog-preview.html)
- Title: `PokerGame 1.3.0 — Know your play, choose your challenge`
- itch.io type: Major Update or Launch; language: English; tag: `v1.3.0`
- The title pattern, short introduction, level-three feature headings, images immediately before their sections, and closing feedback invitation follow the previous Devlogs. The preview reuses `poker-room-background.png` and the established dark green, ivory, and brass palette. The game page's existing theme and banner should be retained.
- Saved itch.io draft: [1668455](https://itch.io/dashboard/post/1668455/edit). The owner preview displayed **DRAFT**, all six feature sections and eight images. No post was published or scheduled.
- Native Chrome uploads are blocked by a disabled Open button in the macOS file picker; browser control also reports a request-header policy error. The body therefore embeds original screenshots from immutable public GitHub commit `8e10c4b5c92c7a349c1d1eae31c29abf77697277`. All nine hosted image responses, including the cover, were verified byte-for-byte against local SHA-256. The custom cover upload is still pending.
- [Copy-ready platform HTML](../../releases/1.3.0-devlog-itch.html) includes these hosted image URLs. The themed local preview uses local image paths.
- Before publication: confirm v1.3.0 packages have been built and uploaded. The user handles publication. The cover intentionally does not say “out now”.

## Difference from v1.2.0

Baseline: tag `v1.2.0` (`bd02862`). Captured source: `6a69c5f02ded81d7d042abe8733a608d1798d0e2`, including the opponent selector, coach/radar, cloud-service client and offline written-review changes.

| Feature | v1.2.0 | Captured source for v1.3.0 |
| --- | --- | --- |
| Opponent styles | Existing AI personalities without a setup selector | Default, random, or one of five named styles; a named choice applies to the whole table |
| Difficulty | Easy, Medium, Hard | Adds Hell with bounded searches on every betting street |
| Live hints | Unavailable placeholder | Local sampled win/split probability, equity, and call-price estimates |
| Hand replay | Step-by-step playback and all-cards view | Automatic action-value comparisons based on decision-time snapshots |
| Player style | Radar placeholder | Six data-derived axes with sample thresholds and supporting counts |
| Written review | Unavailable | Local rule-based prose works offline; cloud coaching can replace it when available. Cloud response quality was not part of this offline capture run |

Tutorials, achievements, browser play, languages, and audio were already included in v1.2.0 and are not presented as new features here. The previous post is [PokerGame 1.2.0 — Play in your browser, with music and two languages](https://jerryszz02.itch.io/poker-game/devlog/1659779/pokergame-120-play-in-your-browser-with-music-and-two-languages).

## Real game captures

All eight screenshots are unchanged 1600 × 1000 PNG viewport captures from the running Godot 4.7 Mono game with the Metal Mobile renderer. They were not generated, composited, translated, or retouched. The capture script, isolated demonstration profile and execution logs were kept only in the authoring worktree's ignored `export/devlog-v1.3.0/` directory. They are not distributed in this repository; a clean checkout contains the resulting screenshots and checksum manifest, not a reproducible capture harness.

| File | Evidence |
| --- | --- |
| `opponent-personalities.png` | Real setup dropdown showing the five named styles, Default, and Random |
| `hell-difficulty.png` | Real difficulty dropdown with Hell selected |
| `hell-table.png` | Three-opponent Hell table after a real `AiDecision.decide()` action applied through `PokerRound.apply_action()` |
| `live-coach.png` | Local Coach result during an actual practice hand, computed from 96 sampled worlds |
| `replay-overview.png` | A completed demonstration hand reopened with its actual replay and automatic review summary |
| `replay-analysis.png` | Four actual decision comparisons, computed locally from the saved hand |
| `offline-review.png` | Actual local rule-based prose generated from the replay analysis, with the cloud service unavailable |
| `player-radar.png` | Six axes calculated from 48 completed demonstration hands; 168 hero decisions and eight qualifying all-in samples |

The demonstration hands used freshly shuffled deals and scripted legal actions, with every action validated by `PokerRound.apply_action()`. The game calculated all results, histories, style counts, and estimates through its existing code. No card states or statistics were injected, no written-response fixture was used, and the user's normal saves were untouched. The coach service URL was disabled only in the capture instance; external review requests were zero. The radar illustrates this controlled sample, not the player's personal history or an AI-strength benchmark.

`capture.gd` finished with `Devlog captures passed.` and zero failures. The normal rules test finished with `All poker tests passed.`. All eight captures were refreshed on the recorded source commit; `tests/local_replay_review_test.gd` also passed. Game code, assets, settings, and release packages were not changed.

## Cover

`cover.png` is the promotional cover, distinct from gameplay evidence. It was created with the built-in `imagegen` tool from `../pokergame-banner.png`, using `../v1.2.0/cover.png` as a typography reference. The original artwork remains untouched. The subtitle is `v1.3.0`; it does not claim the release is available.

Final edit prompt:

> Use case: text-localization. Edit target: Image 1 is the original PokerGame banner. Image 2 is the prior v1.2.0 cover, provided ONLY as a reference for subtitle typography and placement. Create a matching v1.3.0 devlog cover by changing only the words inside the small gold-bordered subtitle plaque below the main PokerGame title. Replace the original 'OFFLINE TEXAS HOLD’EM' with the exact text 'v1.3.0'. Use the same gold cream pixel lettering, dark shadow, centered placement, and plaque seen in Image 2. Do NOT include 'out now' or any additional words. Keep original Image 1 composition, PokerGame main title, spade, ornate frames, green poker table, chips, cards, hanging lamp, safe, dark room, lighting, colors, textures and pixel-art style unchanged. Retain the original wide 2:1 aspect ratio and original dimensions if possible. This is a minimal text edit, not a redesign. Deliver a single clean PNG cover.

The generated original remains under the task's `.codex/generated_images` directory. The workspace copy is the deliverable.
