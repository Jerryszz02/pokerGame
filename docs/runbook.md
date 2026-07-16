# PokerGame Runbook

## Local Environment

Verified local state on 2026-07-16:

- Godot app: `/Applications/Godot_mono.app`
- Godot version: `4.7.stable.mono.official.5b4e0cb0f`
- `dotnet`: `8.0.422`, installed at `~/.dotnet`
- Xcode developer directory: `/Applications/Xcode.app/Contents/Developer`
- Godot export templates: no matching installed templates were found

The project uses GDScript only. The installed editor is the Mono app, so .NET must remain available for editor and headless startup even though the project does not use C# scripts.

In a fresh shell, configure the local .NET runtime if necessary:

```sh
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
```

## Run The Game

From the Godot Project Manager, import:

```text
/Users/jerryszz/Desktop/Projects/pokerGame/project.godot
```

Then run `res://scenes/main.tscn`, or launch from the repository root:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path .
```

## Fast Verification

Run the rules, AI, localization, event-log, and local-profile test suite:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/test_runner.gd
```

Expected output:

```text
All poker tests passed.
```

Run the menu, settings popup, generated-art integration, and responsive table probes:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/ui_layout_probe.gd
```

Expected output:

```text
All UI layout probes passed.
```

The current probe can also print `WARNING: 1 ObjectDB instance was leaked at exit` after the success line. With exit code 0 and the expected success line, this is a known cleanup warning rather than a failed layout assertion. Reinvestigate if the count grows, the success line disappears, or the command exits non-zero.

Check that the main scene and all referenced resources load:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path . --quit-after 2
```

If a fresh shell fails with `dotnet: command not found`, verify `DOTNET_ROOT` and `PATH` using the commands in the environment section.

## Manual Smoke Check

- Confirm the main menu shows the generated background, title, notice board, table preview, textured selection controls, and pixel-art buttons without blurred filtering.
- Open settings, toggle local sound/music settings, close and reopen the popup, and confirm the state persists.
- Click `重置统计` once and confirm the popup stays open with `再次点击确认`; click again only when intentionally testing reset.
- Start games with 1, 3, and 5 AI and try simple, medium, and hard difficulty.
- Confirm the table shows seats, character art, cards, chips, durable SB/BB markers, public information, and real event-log entries.
- Confirm the player can fold, check, call, raise, and all-in only when legal.
- Play until an uncontested result or showdown and confirm Chinese winner, payout, and hand-rank text.
- Confirm the next hand/restart flow works and completed-hand statistics update only once.
- On hard difficulty, confirm seats show personality labels and AI actions are staggered rather than applied in one burst.

## Local Data

Godot writes the local profile to:

```text
user://poker_profile.cfg
```

It contains only local AI-count/difficulty preferences, sound/music switches, and aggregate hand statistics. Use the in-game two-step reset control for statistics. Do not delete or edit the file as part of routine UI testing unless the test explicitly targets profile recovery.

## Art Asset Maintenance

- Runtime assets and source renders live under `assets/art/generated/`.
- Read `docs/art-direction.md` before creating or replacing visible art.
- Read `assets/art/generated/README.md` for source/final filename conventions and known cleanup requirements.
- Keep card ranks, suits, action labels, amounts, and other dynamic values out of bitmap assets.
- Preserve nearest-neighbor filtering and verify atlas cell sizes after replacing sprites or button skins.

## Export Readiness

Desktop export:

- Install Godot export templates matching the editor version.
- Add export presets for macOS, Windows, and Linux.
- Validate a local exported build before preparing a Steam package.

iOS export:

- Full Xcode is installed, but Godot export templates and an iOS export preset are still required.
- Add Apple signing settings only when iOS becomes a confirmed target.
- Recheck touch layout and safe-area behavior before TestFlight.

Steam:

- Steam upload can start with desktop builds only after an export target is confirmed.
- Do not add GodotSteam unless achievements, overlay, cloud saves, or other Steam-specific APIs are explicitly required.
