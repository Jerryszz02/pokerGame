# Generated Poker Art Assets

Generated with the built-in GPT Image 2 host workflow on 2026-07-10, 2026-07-16, and 2026-07-24.

Prompt source:

- `garden-gpt-image-2/prompt/poker-game-art-assets-20260710-144336.md`
- `garden-gpt-image-2/prompt/poker-button-atlas-crisp-20260716-142035.md`
- `garden-gpt-image-2/prompt/poker-table-hud-assets-20260724-215144.md`

## Final assets

### Style

- `style/style-guide.png`
- `style/font-specimen.png`

### Menu and branding

- `misc/menu-background.png`
- `misc/title-logo.png`
- `misc/menu-table-preview.png`
- `misc/app-icon.png`
- `misc/cursor-atlas.png`
- `misc/environment-props.png`

### Table and cards

- `table/poker-table.png`
- `table/table-light-overlay.png`
- `cards/card-components.png`
- `cards/card-glyphs.png`
- `cards/court-cards.png`

### UI

- `ui/panel-atlas.png`
- `ui/button-atlas.png`
- `ui/button-atlas-native.png`
- `ui/form-controls-atlas.png`
- `ui/settings-decor.png`
- `ui/seat-frames.png`
- `ui/blind-tokens.png`
- `ui/stage-action-controls.png`
- `ui/chip-atlas.png`
- `ui/hud-icons.png`
- `ui/status-log-icons.png`
- `ui/result-banners.png`
- `ui/action-tags.png`
- `ui/seat-nameplates.png`

### Characters

- `characters/player.png`
- `characters/ai-fox.png`
- `characters/ai-croupier.png`
- `characters/ai-bear.png`
- `characters/ai-veteran.png`
- `characters/ai-crow.png`

### Effects

- `fx/poker-vfx.png`

## File conventions

- Files without `-source` are the final selected assets.
- `*-source.png` files preserve the original flat-magenta generation before local background removal.
- Transparent deliverables were converted to RGBA with transparent corners and retained beside their source images.
- `ui/button-atlas-native-source.png` preserves the 2026-07-16 GPT Image 2 render; `ui/button-atlas-native.png` is its transparent, limited-palette, runtime-sized atlas.
- `ui/action-tags-source.png`, `ui/seat-nameplates-source.png`, and `table/table-light-overlay-source.png` preserve the 2026-07-24 renders with baked checkerboard backgrounds. The final `ui/action-tags.png` (2x3 grid of 96x24 cells with 4px padding), `ui/seat-nameplates.png` (3 cells of 110x26), and `table/table-light-overlay.png` were produced locally: near-gray bright pixels were keyed to transparency, then cells were cropped to content bounds and resized with nearest-neighbor to native display size.
- The menu background and app icon are intentionally opaque RGB images.

## Required production cleanup

- Slice each atlas into fixed cells before importing it into the runtime UI.
- Normalize logical sprite sizes and use nearest-neighbor filtering in Godot.
- Manually verify card ranks, suits, court-card ordering, and Chinese text before shipping.
- The font specimen is visual direction only. It is not an installable font and contains an incorrect generated sample for `开始牌局`; use a licensed Chinese pixel font for runtime text.
- Keep dynamic labels, values, and action text out of bitmap assets.

## Runtime integration

The main menu and table use the generated background, logo, table preview, table surface, character states, card frames, card backs, blind tokens, and chip stacks through `scripts/ui/main.gd`. The table stage also integrates the panel atlas (header/action bar/event log nine-slice frames), HUD icons (header metrics and log title), result banners (showdown title), action tags (seat action labels beside bet chips), seat nameplates (name/stack plates, with current-actor and all-in states), and the table light overlay (lamplight pool over the felt at reduced opacity).

Card ranks and suits remain runtime text so poker values stay exact. Runtime buttons use the normalized native-resolution atlas with nearest-neighbor filtering; the remaining form-control atlas stays as source material for later normalization.
