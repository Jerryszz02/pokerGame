# PokerGame Runbook

## Local Environment

Known local state on 2026-07-01:

- Godot app: `/Applications/Godot_mono.app`
- Godot version: `4.7.stable.mono.official.5b4e0cb0f`
- `dotnet`: `8.0.422`, installed at `~/.dotnet`
- Export templates: not installed
- Full Xcode: not installed

The project uses GDScript only. In this local setup the installed editor is the Mono app, so .NET must remain available for editor and headless startup even though the project does not use C# scripts.

## Run The Game

From the Godot Project Manager, import:

```text
/Users/jerryszz/Desktop/Projects/pokerGame/project.godot
```

Then run:

```text
res://scenes/main.tscn
```

Command-line run:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path .
```

Manual smoke check:

- Start a game with 1 AI, then with 3 AI, then with 5 AI.
- Try simple, medium, and hard difficulty.
- Confirm the player can fold, check, call, raise, and all-in when legal.
- Play until showdown and confirm the result panel appears.
- Confirm hard AI seats show personality labels.

## Run Tests

Intended command:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/test_runner.gd
```

Expected output:

```text
All poker tests passed.
```

If a fresh shell fails with `dotnet: command not found`, confirm `~/.zshrc` still exports `DOTNET_ROOT="$HOME/.dotnet"` and prepends `~/.dotnet` to `PATH`.

Main-scene startup check:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path . --quit-after 2
```

## Export Readiness

Desktop export:

- Install Godot export templates matching the editor version.
- Add export presets for macOS, Windows, and Linux.
- Validate a local exported build before preparing a Steam package.

iOS export:

- Install full Xcode.
- Install Godot export templates.
- Add iOS export preset and Apple signing settings.
- Recheck touch layout and safe-area behavior before TestFlight.

Steam:

- Steam upload can start with desktop builds only.
- Do not add GodotSteam unless Steam achievements, overlay, cloud saves, or Steam-specific APIs are explicitly required.
