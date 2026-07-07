# PokerGame

Godot 4 + GDScript single-player Texas Hold'em prototype.

This project is intentionally local-only: no external APIs, no LLM opponents, no Steamworks integration, and no third-party poker library in v1.

## Current Features

- Human player versus 1-5 AI opponents.
- Simple, medium, and hard AI difficulties.
- Hard AI uses a preflop starting-hand score, postflop Monte Carlo equity, pot odds, and random personality profiles.
- Standard Texas Hold'em flow: blinds, preflop, flop, turn, river, showdown, fold/check/call/raise/all-in, side pots, split pots.
- Hand event log, explicit match-over results, local settings/stat tracking, and Chinese action/result text.
- Programmatic Godot `Control` UI for the menu, table, player seats, action controls, event log, and result panel.

## Requirements

- Godot 4.7 or compatible Godot 4 version.
- Use GDScript only. The installed `/Applications/Godot_mono.app` can open the project, but the project does not use C#.
- This Mac has .NET 8 installed at `~/.dotnet` so `Godot_mono.app` can run headless checks.

## Run

From the Godot Project Manager, choose **Import**, select this folder, and open `project.godot`:

```text
/Users/jerryszz/Desktop/Projects/pokerGame/project.godot
```

Then run the main scene:

```text
res://scenes/main.tscn
```

The project entrypoint is configured in [project.godot](project.godot).

Command-line run:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path .
```

## Test

Run:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/test_runner.gd
```

Expected output includes `All poker tests passed.` The test runner covers deck uniqueness, hand ranking, kicker comparison, action validation, side pots, split pots, hard-AI personality assignment, and Monte Carlo equity bounds.

UI layout probe:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/ui_layout_probe.gd
```

Expected output includes `All UI layout probes passed.` The layout probe checks the main table at common desktop viewport sizes.

## Documentation

- [Architecture](docs/architecture.md) explains the game engine, AI, UI, and data flow.
- [Runbook](docs/runbook.md) lists local commands, environment notes, and future export steps.
