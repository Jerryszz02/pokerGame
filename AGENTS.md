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

- UI probes (see `docs/planning/ui-acceptance.md` for the acceptance metrics they enforce):

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . -s tests/ui_layout_probe.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --path . -s tests/ui_playthrough_probe.gd
```

- Current local Godot binary is `/Applications/Godot_mono.app/Contents/MacOS/Godot`; .NET 8 is installed at `~/.dotnet` and wired through `~/.zshrc`.

## Documentation Map

- `README.md` is the quick start.
- `docs/architecture.md` explains the current implementation.
- `docs/runbook.md` covers local checks, testing, and export readiness.

## Devlog Requirements

- Write every devlog in English by default, unless the user requests another language.
- For each feature that can be shown visually, run the game and capture a screenshot that clearly demonstrates it. Upload the screenshot to the devlog draft and place it immediately before the corresponding feature section. For example, a section about Chinese/English language switching should be preceded by an in-game screenshot of the settings page showing the language control. Use actual game captures, not mockups or generated substitutes.
- Save all screenshots under `docs/media/<version>/` in the workspace, using the version covered by the devlog (for example, `docs/media/v1.2.0/settings-language.png`). Keep each update's images in its own version folder and use descriptive filenames.
- Create a cover image for every devlog from `docs/media/pokergame-banner.png`. Preserve the original banner and its composition, artwork, main PokerGame title, and pixel-art style. In a separate copy, replace the subtitle text in the plaque below the main title with the current version, following the user's supplied example (for example, `v1.2.0 out now!`). Use the actual release version, and only say `out now!` if that release is available. Save the cover as `docs/media/<version>/cover.png` and upload it as the devlog's cover image.
- End each devlog with a short, natural English invitation to leave comments or share feedback. Prefer a question tied to the update, such as `What do you think of the new language settings? Let me know in the comments!`; otherwise use a simple invitation such as `I'd love to hear what you think—share your feedback in the comments!`.
- Save the completed devlog as an unpublished draft, including its cover and section images, and verify that the draft was saved. Do not publish or schedule publication; the user handles publishing. If saving on the platform is unavailable, preserve the text and media locally and report that the platform draft still needs to be saved.
