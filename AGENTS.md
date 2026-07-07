# AGENTS.md

## Project Rules

- This is a Godot 4 + GDScript project. Do not introduce C#, external APIs, LLM calls, telemetry, or third-party plugins without an explicit user request.
- Keep game rules, AI decisions, and UI separate:
  - `scripts/game/` owns cards, deck, hand evaluation, betting, side pots, and hand progression.
  - `scripts/ai/` owns starting-hand scoring, Monte Carlo equity, personalities, and AI action selection.
  - `scripts/ui/` owns Godot `Control` scene behavior and must call the rules engine instead of mutating poker state directly.
- All player and AI actions must go through `PokerRound.apply_action()` so legality is checked in one place.
- Do not bypass `HandEvaluator.evaluate()` for showdown comparisons.
- Hard AI must remain deterministic in shape but stochastic in choice: preflop uses `StartingHandTable`, postflop uses `MonteCarlo`, and personality parameters come from `PersonalityProfiles`.

## Commands

- Import the project in Godot by selecting `/Users/jerryszz/Desktop/Projects/pokerGame/project.godot`.
- Run the project from Godot with `res://scenes/main.tscn`, or from the shell:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path .
```

- Test command:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/test_runner.gd
```

- Current local Godot binary is `/Applications/Godot_mono.app/Contents/MacOS/Godot`; .NET 8 is installed at `~/.dotnet` and wired through `~/.zshrc`.

## Documentation Map

- `README.md` is the quick start.
- `docs/architecture.md` explains the current implementation.
- `docs/runbook.md` covers local checks, testing, and export readiness.
