# 《深夜德州扑克》像素美术资产 Prompt Pack

适用：GPT Image 2、ChatGPT 图像生成及类似图形模型。以下每个代码块都是一条可独立使用的完整 Prompt。

## 使用说明

- 每次只生成一个代码块对应的资产，不要把整份文档一次性投喂。
- 统一风格：原创深夜地下牌局，现代独立像素游戏的清晰剪影与夸张反馈；不复刻任何现有游戏角色、图标或场景。
- 统一色板：夜黑 `#050B0A`、暗面板 `#0E110F`、墨绿 `#0F2B21`、黄铜 `#CBA14D`、米白 `#EDDFB8`、蓝灰 `#32505D`、暗红 `#9E2E2A`。
- 最终项目基准为 1280×720。背景按 16:9 生成；小型资产按逻辑像素绘制后以 nearest-neighbor 放大。
- 图像模型生成的图集仍需人工切片、去底、像素对齐和色板归一。中文文字、扑克牌点数与花色必须人工复核。

---

## 01. 像素美术风格规范板

```text
Create a professional pixel-art visual style guide board for an original single-player Texas Hold'em game titled “深夜德州扑克”. The world is a mysterious underground card room at midnight: tactical, playful, slightly adventurous, warm brass light over dark green felt. Use a strict seven-color core palette: #050B0A, #0E110F, #0F2B21, #CBA14D, #EDDFB8, #32505D, #9E2E2A. Show clearly separated reference modules: color swatches, 1-pixel and 2-pixel outline examples, panel corners, button depth, card material, brass token material, green felt texture, character silhouette examples, icon examples, light and shadow direction, and three levels of UI emphasis. True crisp pixel art, chunky readable shapes, hard edges, no anti-aliasing, no gradients, no soft blur, no photorealism, no 3D render. Original visual identity, not copying any existing game. Clean 16:9 design board, generous spacing, no decorative paragraph text, no watermark.
```

## 02. 中文像素字体风格母版

> 这只能生成字形视觉参考，不能替代真正的字体文件。

```text
Create a pixel-font design reference sheet for a Chinese poker game UI. Show a consistent square gothic pixel type style with strong legibility at small sizes, hard orthogonal strokes, slightly condensed proportions, 1-pixel counters where possible, and no anti-aliasing. Include the exact Chinese sample glyphs: 深夜德州扑克、本地单机牌局、开始牌局、设置、简单、中等、困难、弃牌、让牌、跟注、加注、全下、底池、筹码、胜利、失败、下一手、重新开始. Include digits 0–9, uppercase A K Q J, and the four suit symbols ♠ ♥ ♣ ♦. Use #EDDFB8 glyphs on #050B0A and #0E110F backgrounds, with #CBA14D emphasis examples and #9E2E2A red-suit examples. Arrange as a clean typographic specimen sheet. Exact text only, no invented characters, no calligraphy, no rounded mobile-app font, no gradients, no blur, no watermark. Treat this as reference art for a human font designer, not as a finished installable font.
```

## 03. 通用面板九宫格图集

```text
Create a production-ready transparent PNG pixel-art UI atlas for an original midnight underground poker game. Arrange six isolated resizable panel frames in a strict 3-column by 2-row grid: main menu frame, dark utility panel, green felt table frame, modal dialog frame, event-log frame, player-seat frame. Each frame must have an empty center suitable for nine-slice scaling, straight edges, consistent 2-pixel near-black outline, clipped 1–2 pixel corners, restrained brass rivets, and subtle single-step pixel highlights. Palette only: #050B0A, #0E110F, #0F2B21, #CBA14D, #EDDFB8, #32505D, #9E2E2A. True pixel art, transparent background, equal cell size, wide empty spacing, no labels, no text, no icons inside panels, no antialiasing, no gradients, no soft shadows, no perspective, no overlapping assets, no watermark.
```

## 04. 按钮状态图集

```text
Create a production-ready transparent PNG pixel-art button skin atlas for an original midnight poker game. Strict grid: 3 rows by 5 columns. Rows are brass primary buttons, blue-gray standard buttons, dark-red danger buttons. Columns are normal, hover, pressed, disabled, keyboard-focus. Every button is the same wide rectangular shape with clipped pixel corners, 2-pixel dark outline, empty center for dynamic Chinese text, and clear state differences through one-step highlights, depth shift, desaturation, and a thin focus outline. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. Flat true pixel art, transparent background, no words, no symbols, no gradients, no rounded mobile UI, no glow blur, no 3D rendering, no overlapping, no watermark.
```

## 05. 表单控件图集

```text
Create a transparent PNG pixel-art UI control atlas for an original dark-green poker game. Use a strict evenly spaced grid containing: dropdown closed arrow and open arrow; numeric spinner up and down buttons in normal, hover and pressed states; checkbox empty, checked and disabled; horizontal slider track, filled track and brass grabber in normal, hover and pressed states; vertical scrollbar track and thumb; small plus and minus controls; sound on, sound off, music on, music off. Chunky 16-bit style with hard 1–2 pixel outlines and excellent readability at 16x16 to 32x32 logical pixels. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. Transparent background, no text, no labels, no extra icons, no antialiasing, no gradients, no soft shadows, no mismatched sizes, no watermark.
```

## 06. 主菜单背景

```text
Create a 16:9 pixel-art background for an original game called “深夜德州扑克”. Scene: an underground midnight card room viewed straight-on with a slight top-down feeling, dark wooden walls, deep green felt tables in shadow, a single brass hanging lamp, faint card and chip silhouettes, subtle haze made from hard pixel clusters. The center 560x560-equivalent area must stay calm, dark and low-detail for a large menu panel; the lower-right corner must remain clear for a settings button. Use #050B0A and #0E110F as dominant colors, #0F2B21 felt, sparse #CBA14D light, tiny #EDDFB8 highlights, very limited #32505D and #9E2E2A accents. Original modern indie pixel art, chunky shapes, atmospheric but readable, no characters in foreground, no UI, no logo, no text, no gradients, no blur, no photorealism, no watermark.
```

## 07. 游戏标题 Logo

```text
Create an original transparent pixel-art title logo containing exactly the Chinese text “深夜德州扑克”. Large readable Chinese characters, compact horizontal lockup, cream #EDDFB8 face, dark #050B0A two-pixel outline, restrained brass #CBA14D inline accents. Add a small original emblem combining a poker chip, crescent moon and two crossed playing cards, but keep the title dominant. Mood: midnight underground club, tactical and playful, not luxurious casino neon. True pixel typography, hard edges, no antialiasing, no gradients, no 3D bevel, no Latin subtitle, no additional Chinese text, no spelling changes, no copying existing game logos, transparent background, no watermark. Produce one primary wide logo and one compact emblem-only variant separated with generous transparent spacing.
```

## 08. 主菜单微缩牌桌预览

```text
Create a wide transparent pixel-art vignette for the main menu of an original Texas Hold'em game. Show a miniature dark-green card table from a shallow top-down angle, five empty community-card slots in the center, two face-down player cards at the bottom, three small original gambler silhouettes around the table, a few brass chips and one warm overhead lamp. The composition must fit a wide 480x140-equivalent frame, with strong readable silhouettes and a clean center. Palette strictly #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. Chunky modern pixel-game style, fully original, no text, no HUD, no real card ranks, no crowded props, no gradients, no antialiasing, no soft blur, transparent outside the vignette, no watermark.
```

## 09. 设置入口与弹窗装饰包

```text
Create a transparent PNG pixel-art settings UI decoration pack for an original midnight poker game. Strict grid with isolated assets: brass-and-blue-gray gear icon; close X icon; speaker-on, speaker-off, music-note-on, music-note-off; small statistics chart icon; reset icon; warning-confirm icon; four decorative modal corners; one short brass divider; one dark-green title plaque with an empty center. Style: compact 16-bit pixel art, 1–2 pixel dark outline, brass hardware, green felt accents, excellent legibility at 16–32 logical pixels. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. Transparent background, no words, no labels, no gradients, no antialiasing, no glow, no overlapping, no watermark.
```

## 10. 实体牌桌组件

```text
Create a production-ready top-down pixel-art poker table asset for an original midnight underground card game. Wide rectangular tactical table with subtly clipped corners, thick dark wooden rail, brass corner caps, deep green felt center, a darker rectangular central pot area, faint stitched boundary, and empty safe zones for five AI seats around the top and sides plus one player seat at the bottom. Almost orthographic top-down view, no strong perspective. The table must remain uncluttered because cards and UI will be overlaid dynamically. Use #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. True crisp pixel art, 16:9 wide composition, transparent outside table, no characters, no cards, no chips, no text, no HUD, no gradients, no antialiasing, no photorealism, no watermark.
```

## 11A. 扑克牌底板、牌背与空槽

```text
Create a transparent PNG pixel-art playing-card component sheet for a dark midnight poker game. Strict 4-column grid containing: blank cream card face, blank red-suit card face, navy card back with an original brass diamond-and-moon pattern, empty community-card slot. Add a second row showing the same four assets in hover/highlight state. All cards have identical 52x68-equivalent proportions, clipped 1-pixel corners, 2-pixel dark outline, flat colors, and enough empty face area for dynamic rank and suit glyphs. Palette #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. No ranks, no letters, no suit symbols, no text, no gradients, no antialiasing, no perspective, no overlapping, transparent background, no watermark.
```

## 11B. 扑克牌点数与花色字形

```text
Create a precise transparent pixel-art glyph sheet for modular playing cards. Strict grid with equal cells. First row: A, 2, 3, 4, 5, 6, 7; second row: 8, 9, 10, J, Q, K plus one blank cell; third row: large ♠, ♥, ♣, ♦ and small ♠, ♥, ♣, ♦. Black suits use #050B0A, red suits use #9E2E2A; optional one-pixel #EDDFB8 highlight only when needed. All glyphs must share one bold, condensed, highly legible pixel-font system and fit a 52x68 playing card. Exact glyphs only, correct order, no duplicates, no invented symbols, no decorative borders, no card backgrounds, no gradients, no antialiasing, no blur, transparent background, no watermark. This is a production reference sheet; preserve strict alignment and consistent scale.
```

## 11C. J/Q/K 宫廷牌人物图集

```text
Create a transparent pixel-art court-card illustration sheet for an original midnight underground poker deck. Strict 4-column by 3-row grid: columns are spades, hearts, clubs, diamonds; rows are Jack, Queen, King. Each cell contains one compact mirrored court-card character illustration only, with consistent proportions and the same visual system. Spades: masked night guards; hearts: charismatic performers; clubs: underground mechanics; diamonds: brass merchants. Use only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. Original chunky 16-bit pixel characters, readable at small card size, no letters, no numbers, no suit symbols, no frames, no backgrounds, no gradients, no antialiasing, no duplicated faces, no existing copyrighted characters, transparent background, no watermark.
```

## 12. 玩家座位框状态图集

```text
Create a transparent PNG pixel-art seat-frame atlas for an original Texas Hold'em game. Strict 2-row by 5-column grid. Top row: compact AI seat frames; bottom row: wide human-player seat frames. Columns: normal, current turn, folded, all-in, eliminated. Every frame has an empty left area for a portrait, empty center for dynamic Chinese information, and an open right area for two cards. Current-turn uses a strong brass outline; folded is dark and desaturated; all-in has a restrained dark-red warning edge; eliminated is nearly black with a broken brass corner. Consistent clipped corners and 2-pixel outlines. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. No text, no portraits, no cards, no icons, no gradients, no antialiasing, transparent background, no watermark.
```

## 13. 庄家、小盲、大盲标记

```text
Create a transparent pixel-art token sheet for an original midnight poker game. Three large isolated tokens in one row: dealer button, small-blind token, big-blind token; second row shows their highlighted/current variants. Dealer token is warm brass with a crescent-and-card emblem; small blind is cream and brass; big blind is dark red with brass rim. Use simple original symbols rather than text so they remain language-independent. Circular chunky poker-chip silhouettes, hard 2-pixel dark outline, readable at 24x24 and 32x32 logical pixels. Palette #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. No letters, no words, no gradients, no antialiasing, no 3D realism, no overlapping, transparent background, no watermark.
```

## 14. 牌局阶段标签

```text
Create a transparent PNG pixel-art stage-indicator atlas for a Texas Hold'em UI. Strict 5-column by 2-row grid. Five concepts in order: preflop represented by two face-down cards; flop represented by three revealed card silhouettes; turn represented by a fourth card; river represented by a fifth card plus a small wave mark; showdown represented by two opposing revealed hands. Top row inactive dark-green versions, bottom row active brass versions. Each item sits inside the same compact clipped-corner tab with empty space beneath or beside it for dynamic Chinese text. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. No words, no ranks, no gradients, no blur, no antialiasing, transparent background, no watermark.
```

## 15. 行动按钮图标与加注控件

```text
Create a transparent pixel-art poker action control atlas. Strict grid of isolated assets: fold icon as cards sliding away; check icon as a calm open hand; call icon as matching two chip stacks; raise icon as an upward chip stack; all-in icon as every chip pushed forward; minus button; plus button; slider track; brass slider fill; brass grabber. Include normal and highlighted variants for the five action icons. Strong silhouettes, 1–2 pixel near-black outline, readable at 20x20 to 32x32 logical pixels. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. Original symbols, no words, no card ranks, no gradients, no antialiasing, no soft shadows, no overlap, transparent background, no watermark.
```

## 16A. 玩家角色状态表

```text
Create a transparent pixel-art portrait state sheet for the human player in an original underground poker game. Character: gender-neutral young night courier, short dark hair under a deep-green hood, cream scarf, blue-gray jacket, one brass card clip, calm observant eyes. Strict 4-column grid with identical bust framing: neutral waiting; focused thinking with one hand near chin; decisive action pushing one chip forward; folded/out state with lowered gaze and hood shadow. Strong original silhouette, friendly but tactical, chunky modern 16-bit pixel art, 2-pixel near-black outline. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. Same face and clothing in all cells, no text, no cards with ranks, no extra hands, no gradients, no antialiasing, transparent background, no watermark.
```

## 16B. AI 1 狐狸赌客状态表

```text
Create a transparent pixel-art portrait state sheet for an original AI poker opponent. Character: clever red fox gambler in a worn dark-green waistcoat, cream shirt, small brass ear ring, red scarf, expressive sharp eyes; playful loose-aggressive personality. Strict 4-column grid with identical bust framing: confident idle grin; impatient thinking while tapping a chip; aggressive raise with scarf flicking; folded state with ears lowered and annoyed side glance. Original character, not based on any existing game mascot. Chunky modern 16-bit pixel art, strong silhouette, 2-pixel dark outline. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. Same design in every cell, no text, no card ranks, no extra limbs, no gradients, no antialiasing, transparent background, no watermark.
```

## 16C. AI 2 黄铜机械荷官状态表

```text
Create a transparent pixel-art portrait state sheet for an original AI poker opponent. Character: compact brass mechanical croupier, square blue-gray metal head, one cream glowing eye, dark-green vest, precise clockwork fingers, disciplined tight-aggressive personality. Strict 4-column grid with identical bust framing: perfectly still idle; calculating state with a tiny rotating brass dial; controlled raise placing one exact chip; folded state with eye dimmed and head tilted down. Original design, readable at 48x48 logical pixels, chunky modern 16-bit pixel art, hard 2-pixel dark outline. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. No text, no numbers, no gradients, no antialiasing, no photorealistic metal, no extra arms, transparent background, no watermark.
```

## 16D. AI 3 熊酒馆老板状态表

```text
Create a transparent pixel-art portrait state sheet for an original AI poker opponent. Character: broad friendly brown bear tavern keeper, rolled cream sleeves, dark-green apron, brass key ring, warm smile, patient calling-station personality. Strict 4-column grid with identical bust framing: relaxed idle holding a mug below frame; slow cheerful thinking; casual call placing matching chips; folded state with a good-natured shrug. Original character with a large round silhouette, playful but not childish, chunky modern 16-bit pixel art, hard 2-pixel dark outline. Use only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A, approximating fur with the dark and brass tones. No text, no alcohol branding, no extra limbs, no gradients, no antialiasing, transparent background, no watermark.
```

## 16E. AI 4 石面老兵状态表

```text
Create a transparent pixel-art portrait state sheet for an original AI poker opponent. Character: elderly stone-faced underground card veteran, angular gray-blue skin, short cream beard, dark-green military coat, one brass monocle, extremely patient rock-tight personality. Strict 4-column grid with identical bust framing: immovable neutral stare; long silent thinking with monocle glint; rare decisive action placing a heavy chip; folded state calmly crossing arms. Original character, powerful simple silhouette, chunky modern 16-bit pixel art, hard 2-pixel dark outline. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. Same face and clothing in every cell, no text, no weapons, no gradients, no antialiasing, no extra hands, transparent background, no watermark.
```

## 16F. AI 5 乌鸦魔术师状态表

```text
Create a transparent pixel-art portrait state sheet for an original AI poker opponent. Character: slim black-feathered crow illusionist, blue-gray cape, dark-green high collar, cream gloves, brass half-moon monocle, unpredictable balanced personality. Strict 4-column grid with identical bust framing: mysterious neutral pose; thinking while one brass chip floats above a gloved finger; sly action sweeping chips forward; folded state with cape closed and eye hidden. Original character, elegant angular silhouette, chunky modern 16-bit pixel art, hard 2-pixel dark outline. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. No text, no playing-card ranks, no magic glow gradients, no extra fingers, no antialiasing, transparent background, no watermark.
```

## 17. 筹码与筹码堆图集

```text
Create a transparent PNG pixel-art poker-chip atlas for an original midnight card game. Strict 5-column by 4-row grid. Columns are five denominations represented only by color and edge patterns: cream, brass, blue-gray, dark-green, dark-red. Rows are single chip, stack of three, stack of five, large irregular pot pile. Orthographic three-quarter top view, identical scale, hard 1–2 pixel outlines, simple stripe patterns, strong silhouette at 16x16 and 24x24 logical pixels. Use only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. No numbers, no currency symbols, no text, no gradients, no antialiasing, no realistic casino branding, no overlapping between grid cells, transparent background, no watermark.
```

## 18. 顶部 HUD 图标集

```text
Create a transparent pixel-art HUD icon set for an original Texas Hold'em game. Strict 3-column by 3-row grid with nine isolated icons: hand number as two stacked cards; street stage as a branching card path; pot as a bowl of chips; current bet as one chip entering a ring; amount to call as two equal chip stacks; player stack as a vertical chip tower; active turn as a brass pointer; game log as a small ledger; settings as a gear with card-suit cutout. Each icon has normal muted and optional brass-highlight details within the same cell. Readable at 16x16–20x20 logical pixels, hard 1–2 pixel outline. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. No text, no numbers, no gradients, no antialiasing, no mixed styles, transparent background, no watermark.
```

## 19. 玩家状态提示图集

```text
Create a transparent pixel-art status badge atlas for an original poker game. Strict 3-column by 2-row grid with six isolated badges: your turn as a brass pointing marker; thinking as three square dots over a small head silhouette; folded as two cards sliding into shadow; all-in as a full chip pile with dark-red edge; winner as a brass laurel around one chip; eliminated as a cracked empty seat. Each badge uses the same clipped-corner dark plaque and leaves a small empty area for dynamic Chinese text. Strong readable silhouettes at 24x24–32x32 logical pixels. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. No words, no letters, no gradients, no antialiasing, transparent background, no watermark.
```

## 20. 牌局日志图标集

```text
Create a transparent pixel-art event-log icon set for an original Texas Hold'em game. Strict 4-column by 2-row grid with eight isolated icons: blind posted, check, call, raise, fold, all-in, new street dealt, pot won. Use minimal object-based symbols: small chips, hand gestures and card silhouettes, all sharing the same 12x12–16x16 logical pixel footprint and 1-pixel dark outline. Ensure every concept is distinguishable without text. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. Flat true pixel art, no labels, no numbers, no ranks, no gradients, no antialiasing, no soft shadows, no overlapping cells, transparent background, no watermark.
```

## 21. 结算横幅图集

```text
Create a transparent pixel-art result-banner atlas for an original midnight poker game. Four wide isolated banners in a vertical stack: hand victory, hand loss, showdown, match over. Victory uses brass chips and restrained spark accents; loss uses dark-red folded cards; showdown uses two opposing card fans and a central brass eye; match over uses an empty table under a crescent lamp. Every banner has a large empty center for dynamic Chinese result text and a smaller empty lower area for statistics. Consistent clipped-corner dark frame, strong 2-pixel outline, dramatic but compact. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. No words, no card ranks, no gradients, no antialiasing, no confetti clutter, transparent background, no watermark.
```

## 22. 发牌、下注与胜利特效 SpriteSheet

```text
Create a transparent pixel-art VFX sprite sheet for an original poker game. Strict 5-row by 6-column grid; each row is a six-frame animation progressing left to right. Row 1: card-deal speed streak ending with a card silhouette. Row 2: chip sliding trail ending in a small impact. Row 3: current-turn brass border pulse expanding then fading. Row 4: winner sparkle burst using small square stars and chip glints. Row 5: folded-card shadow puff collapsing inward. Every cell has identical dimensions and clean transparent margins. True hard-edged pixel animation, limited palette #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. No text, no gradients, no blur, no particles crossing cell boundaries, no antialiasing, no watermark.
```

## 23. 环境装饰道具图集

```text
Create a transparent pixel-art prop atlas for an original underground midnight poker room. Strict 4-column by 3-row grid with twelve isolated props: brass hanging lamp, small desk lamp, empty cream mug, chip case, folded green cloth, two loose face-down cards, old wall clock, crescent wall sign, wooden crate, ash-free decorative smoke wisp, brass bell, small locked ledger. Chunky original 16-bit pixel art, consistent shallow top-down perspective, 2-pixel dark outline, readable silhouettes. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. No text, no logos, no playing-card ranks, no gradients, no antialiasing, no soft blur, no overlapping cells, transparent background, no watermark.
```

## 24. 像素鼠标与交互反馈

```text
Create a transparent pixel-art cursor and interaction feedback atlas for an original poker game. Strict grid containing: default arrow cursor shaped like a tiny cream card corner; hover hand cursor with brass cuff; pressed hand cursor; disabled cursor with dark-red slash; card-select corner brackets; chip-select ring; small click spark with four animation frames; keyboard-focus corner markers. Each cursor must remain readable at 16x16 or 24x24 logical pixels with a 1-pixel #050B0A outline. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. Original shapes, no words, no numbers, no gradients, no antialiasing, no glow blur, no overlapping, transparent background, no watermark.
```

## 25. 游戏应用图标

```text
Create a square pixel-art application icon for an original game titled “深夜德州扑克”. Central emblem: one cream playing card corner emerging from a dark-green poker chip, framed by a brass crescent moon; tiny dark-red heart accent and blue-gray shadow. Bold centered silhouette that remains recognizable at 16x16, 32x32, 64x64 and 512x512. Background is near-black #050B0A with a clipped-square dark panel #0E110F, strong 2-pixel brass rim, no rounded mobile-app gloss. Palette only #050B0A #0E110F #0F2B21 #CBA14D #EDDFB8 #32505D #9E2E2A. True crisp pixel art, no text, no letters, no gradients, no antialiasing, no photorealism, no existing game icon resemblance, no watermark. Center all elements with generous safe margins.
```

---

## 建议生成顺序

1. 先生成 01，确认整体语言与色板。
2. 生成 03–05，确定 UI 基础组件。
3. 生成 10、11A–11C、12–15，完成可玩的牌桌核心资产。
4. 生成 16A–16F、17–22，补角色和动作反馈。
5. 最后生成 06–09、23–25，补主菜单和环境包装。

## 生产注意事项

- Logo 与中文字体：模型出图后必须人工检查文字，推荐保留图形徽章，文字由游戏字体渲染。
- 扑克牌：不要直接依赖模型一次生成完整 52 张。使用 11A、11B、11C 的模块组合，由程序或美术工具批量拼出 52 张，正确率更高。
- 图集：建议先要求透明背景；若模型未正确输出 Alpha，可改为纯洋红 `#FF00FF` 背景后统一抠图。
- 像素清理：最终统一关闭抗锯齿、量化到项目色板，并检查每个 SpriteSheet 单元格尺寸完全一致。
