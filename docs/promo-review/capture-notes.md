# Capture provenance — PokerGame 1.4.0

Game source: `42e62f83f9b2c439eb636ac86195312e49604af0` (`42e62f8`). The nine accepted source recordings and all eighteen AVI/MP4 SHA-256 digests are listed in `capture-manifest.json`. Media paths in that manifest are relative to `export/promo/v1.4.0/production-2026-10-15/raw/`. The complete local manifest, frame/time event logs, screenshots, and completed-hand JSON records remain beside the raw files.

## What the footage proves

This is graphical Godot MovieMaker output using Metal, not a desktop screen recording. Visible UI controls were operated through their existing signals; no desktop mouse pointer was recorded. The edited video may add an operation indicator based on logged button rectangles. Such an indicator represents an automated UI operation, not a captured physical mouse movement.

The game rendered 1920 × 1080 at 30 fps using its 1280 × 720 UI design scale. Original AVI contains MJPEG video and 48 kHz stereo PCM audio. Editing copies use H.264 CRF 18 and AAC 192 kbit/s. Game sound effects remained enabled; game music volume was zero for later soundtrack mixing.

Ordinary practice and hard-AI footage uses the unmodified game engine and AI. The automation selects configuration and calls/checks through actual UI buttons. It does not assign cards, edit poker state, set AI decisions, or rewrite results. Every newly available player turn in the completed practice captures waits at least 90 frames (three seconds) before action. The hard-AI inserts show three hard opponents and a partial hand; they do not claim a completed hard-AI game or any particular result.

## Genuine outcomes and same-hand replay

| Recording | Real hand ID | Result |
| --- | --- | --- |
| `en-practice-take02` | `hand-6aaf93d1165167e45ccf5daf04a02d7c` | Player loses 1000 chips; the following table is a newly started match. |
| `zh-practice-take02` | `hand-ad81fba7f63ae4c8713825d9e0129b52` | Player gains 1010 chips; the later table is the next hand. |
| `zh-replay-pickup` | `hand-ad81fba7f63ae4c8713825d9e0129b52` | Additional read-only replay of the exact Chinese completed record above. |

Do not imply that the English and Chinese recordings show one continuous game, or change the English loss into a win. The English calls occur preflop and on the flop; the later board cards follow the game's all-in runout and must not be described as a river betting decision.

The Chinese replay pickup uses the production practice-store JSON reader to restore numeric card ranks correctly. It opens the previously recorded hand without dealing or recalculating a result. Default player perspective runs from 4.267 to 18.533 seconds; the actual omniscient toggle then stays enabled through 26.533 seconds. Its visible label restricts omniscience to the already completed hand, including folded cards. The pickup is a separate recording session of the same hand record, not continuous footage from the original table session.

## Tutorial and excluded takes

Both tutorial captures use the game's built-in G1 guided lesson, including its preset deck and opponent behavior. They demonstrate prompts, legal button operations, feedback, and completion. They must be labelled as tutorial footage and must not be presented as an unscripted ordinary practice hand. Their distinct completed-record IDs are retained in the manifest.

Only the nine sources enumerated in the manifest are accepted for editing. `take01/` contains superseded tests and recordings, including an initial replay pickup with blank card text caused by loading JSON without the production integer normalization. `en-test*` is a five-second technical check. Neither group is an accepted editorial source.

## Isolation and limits

Each recording creates a unique profile in the OS cache directory and derives a separate `.practice` store from that path. It does not load or write the normal player's profile or practice history. The remote review service URL is set to an empty string before the main scene starts. The complete local event logs retain these exact isolation paths; the repository manifest omits private absolute paths. No network packet trace was collected, so the evidence supports disabled cloud-review configuration rather than a blanket claim of measured network isolation.

The capture helpers are the only added execution code. The launcher creates an isolated temporary project configuration with the required viewport and symlinks existing source/assets. It does not change the repository's game configuration or logic. No capture processes remain running.

## Reuse

`tools/promo_capture_launcher.py` now accepts `--output`; its default is derived from the current project's version and the current local date. The destination is passed to the Godot capture script, so future runs do not use a fixed user path or the 2026-10-15 folder. This parameterization happened after capture and does not alter the existing media or their hashes. The replay-pickup mode expects the corresponding `zh-practice-take02-hand-record.json` inside the chosen output directory.

Example (run from the repository):

```sh
python3 tools/promo_capture_launcher.py --lang en --mode practice --output export/promo/v1.4.0/production-2026-10-15/raw
```

The example reproduces the capture procedure, not the random cards or results. Use a fresh destination to avoid overwriting an existing take. Verification after parameterization: Python compilation, launcher `--help`, and Godot `--check-only` passed; the game was not re-recorded.

## R1 configuration pickup supplement

`config-pickup-en` and `config-pickup-zh` are additional independent sessions. They repair the original configuration coverage: the original practice clips show the upper fields but do not expose Start below the scroll fold. They do not replace or alter any of the original seven sources.

For each pickup, the upper player-count/difficulty fields remain visible from 3.267 to 6.267 seconds. The real ScrollContainer vertical scrollbar then moves from its initial position to the bottom over one second. After settling, both Pause after each hand and Start are entirely inside the scroll viewport; this is asserted against their actual UI rectangles and verified in the lower-page PNG. The lower page stays stable from 7.767 to 10.767 seconds before Start is actually activated. A fresh practice table is visible from 11.033 through 14.033 seconds. These sessions end during an incomplete first hand and are not same-hand continuity footage for the earlier practice/replay sources.

The Start button rectangle is `[363, 550, 180, 42]` in the 1280 × 720 design coordinates, equivalent to `[544.5, 825, 270, 63]` in the 1920 × 1080 output. Logs also retain the Pause and scroll viewport rectangles. Scrolling is automated manipulation of the real UI scrollbar, not a recorded physical mouse wheel. Existing profile isolation, empty remote-review URL, sound effects, zero game music, and MovieMaker capture settings remain in effect. Both new MP4 files use the same CRF 18/AAC encoding as the original seven.
