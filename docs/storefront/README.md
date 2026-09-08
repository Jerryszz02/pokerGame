# Player-facing storefront

English copy and original PokerGame media for GitHub and itch.io. The game itself remains Simplified Chinese. No gameplay or release binary changes are part of this update.

## Design direction

The audience is a player looking for a small offline poker game. The page’s job is to show what playing looks like and lead to the correct desktop download.

- Palette: room `#07120F`, felt `#10251F`, brass `#D3AC59`, ivory `#F2E7CD`, muted text `#C4CDBF`.
- Type: Georgia headings, Arial body; the title artwork supplies the pixel lettering. Body text stays readable instead of using a pixel font throughout.
- Layout: title banner → short hook and download link → language disclosure → actual gameplay → opponent/pacing features → practical download details and feedback.
- Signature: the game’s lamp-lit room continues into the page background, while the gameplay table stays the main evidence.
- GitHub has its own layout and does not support a custom README page background; the banner and screenshots carry the same identity there.

## Reference research — 2026-09-08

These are high-engagement references, selected from itch.io’s [top-rated card-game list](https://itch.io/games/top-rated/tag-card-game). Public view/download totals were not available; ratings are an engagement proxy, not download counts or proof that page design caused success.

| Reference | Public evidence at lookup | What to borrow |
| --- | --- | --- |
| [Dungeons & Degenerate Gamblers](https://purplemosscollectors.itch.io/dndg) | 1,201 ratings on the product page | Lead with the distinctive card-play hook and immediately explain what version the visitor can play. |
| [Die in the Dungeon CLASSIC](https://alarts.itch.io/die-in-the-dungeon) | 2,706 ratings on the category listing | Describe the central interaction in one sentence and put playable/gameplay content before development detail. |
| [High Stakes](https://krystman.itch.io/high-stakes) | 507 ratings on the category listing | Give a familiar card mechanic a clear thematic identity. |

Reference descriptions and public engagement were inspected through web retrieval. Native browser attempts to inspect their visual layouts were interrupted by loading/connection problems; do not treat this as a completed screenshot audit of those pages. No competitor artwork or text was copied.

The implementation also follows itch.io’s [page design guidance](https://itch.io/docs/creators/design): match the game’s theme, use a banner/background, keep gameplay images visible, and explain controls and requirements.

## Assets

All files are in `../media/`. Screenshots were captured on 2026-09-08 from commit `c452b68e2ee0b90ff7062de099d082f5aeea43dd`, the refreshed `origin/main` checkout used for this change. They show actual game rendering at 1280 × 720, without retouching or translated UI.

| File | Source / use |
| --- | --- |
| `pokergame-banner.png` | AI-generated English title artwork, using the existing menu background and title logo as visual references; use for the itch.io banner and README header. |
| `pokergame-cover.png` | AI-generated compact catalog composition based on the banner; use for the itch.io cover. |
| `poker-room-background.png` | Unmodified copy of `assets/art/generated/misc/menu-background.png`; use as the page background. |
| `river-decision.png` | UI probe: `1280x720_05_human4_river.png`; primary gameplay image. |
| `action-log.png` | UI probe: `1280x720_03b_log_drawer.png`; current-hand action history. Replaces the near-duplicate river capture formerly named `raise-the-stakes.png`. |
| `showdown.png` | UI probe: `1280x720_09_result.png`; cards revealed and pot awarded. |
| `choose-your-table.png` | UI probe: `1280x720_01_menu.png`; opponents and difficulty. |

Reproduce fresh captures with the pinned engine:

```sh
GODOT_BIN="$(python3 tools/bootstrap_godot.py)"
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --path . -s tests/ui_playthrough_probe.gd
```

The probe writes to `/tmp/poker_audit/`; inspect timestamps before choosing captures because old files may remain. Do not use forced win/bust fixture images as ordinary gameplay marketing screenshots. The media directory has `.gdignore`, and release presets already exclude `docs/*`.

## itch.io publishing fields

- Project: https://jerryszz02.itch.io/poker-game
- Edit: https://itch.io/game/edit/4983610
- Title: `PokerGame`
- Tagline: `Offline Texas Hold’em in a late-night pixel poker room. Face 1–5 AI opponents. Chinese interface.`
- Description: `description.html`.
- Download instructions: `install.html`.
- Genre: Card Game.
- Suggested relevant tags: `poker`, `singleplayer`, `pixel-art`, `strategy`, `2d`.
- Language metadata: Chinese (Simplified); English describes the page copy only.
- Preserve current price, release files, visibility, and AI-art disclosure.

Upload the four screenshots, cover and banner to itch.io itself. `description.html` now contains the uploaded itch.io CDN URLs and can be pasted directly into the HTML editor. When replacing screenshots, update these absolute URLs after uploading. After saving, verify the public HTML retains all image `src` attributes and each image URL returns an image response. Do not publish relative local image paths. Keep a single content column with embedded gameplay screenshots if supported; otherwise keep the screenshots sidebar visible.

Theme editor values: background `#07120F`, content background `#10251F`, text `#F2E7CD`, links/buttons `#D3AC59`. Background image: centered, cover, no repeat. Use readable, opaque content backing. Banner: `pokergame-banner.png`. Check desktop and narrow viewport rendering before saving.

The existing download entries were external GitHub ZIP links when inspected. Native itch.io-hosted builds should be evaluated separately for indexing/discovery; this copy update does not move or replace the release files. See [itch.io indexing guidance](https://itch.io/docs/creators/getting-indexed).

## Local preview

`preview.html` is a standalone approximation for reviewing the copy, images, palette, and narrow layouts. It does not replicate itch.io’s generated download/metadata controls and is not a separate deployed website.

Open `preview.html` directly, or serve the repository:

```sh
python3 -m http.server 8765 --bind 127.0.0.1
```

Then visit http://127.0.0.1:8765/docs/storefront/preview.html.
