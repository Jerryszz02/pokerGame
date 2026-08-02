# 《深夜德州扑克》牌桌 HUD 补充资产

Create production-ready transparent PNG pixel-art HUD assets for the existing late-night underground poker game shown in the references. These assets extend the table UI that already uses the generated poker table, character sheets, card components, blind tokens, chip atlas, panel atlas, and button atlas.

Match the established style exactly: modern indie pixel art with crisp 1-2 pixel outlines, clipped corners, flat color regions, restrained single-step highlights, and a quiet tactical mood. Palette only: #050B0A, #0E110F, #0F2B21, #CBA14D, #EDDFB8, #32505D, #9E2E2A. No antialiasing, gradients, blur, glow, soft shadows, texture noise, painterly shading, or 3D rendering. Transparent background. No text, letters, numbers, symbols, watermark, grid lines, or overlapping assets anywhere in the output.

## Asset 1: action-tags atlas (priority)

Small speech-tag banners that float beside a seat's chips to show that seat's latest action, for example a raise or a call. The game draws its own Chinese text at runtime, so every tag must have an empty center.

Layout: a strict 3-row by 2-column grid with generous fully transparent gaps. Rows are the three poker emphasis colors: brass primary (#CBA14D), blue-gray standard (#32505D), muted dim state (desaturated #0E110F body with #32505D edge). Columns: tail pointing down, tail pointing up.

Each tag is a compact rounded-rectangle banner with clipped 2-3 pixel corners and a short centered triangular tail on one edge. Design for native display around 96x28 pixels including the tail. Keep an empty inner area of at least 72x16 pixels for runtime text. All 6 tags must share identical dimensions and alignment so they are interchangeable at runtime. State differences come only from palette swaps and a 1-pixel highlight.

## Asset 2: seat-nameplates atlas (optional)

Small nameplate frames pinned over a character's lower edge, showing that player's name and chip count as runtime text.

Layout: a single row of 3 identical-size plates with fully transparent gaps. States: normal dark (#0E110F body, thin #32505D edge), current-actor brass highlight (#0F2B21 body, #CBA14D edge, one brass corner diamond), all-in danger (#0E110F body, #9E2E2A edge).

Each plate is a wide low banner designed for native display around 128x26 pixels with clipped corners and an empty inner area of at least 104x16 pixels. Keep the silhouette consistent across states so the UI can swap them without relayout.

## Asset 3: table-light-overlay (optional)

A full-table atmosphere overlay for the 1619x971 poker table: a hard-edged pixel-art pool of warm lamplight concentrated on the felt center, with the outer rail and corners falling into deeper shadow. This is a lighting pass, not a glow effect: use stepped dither or flat concentric pixel bands only, stay inside the palette, and keep the center light subtle enough that white cards and brass chips remain fully readable underneath. The overlay will be drawn on top of the table texture with reduced opacity, so keep the shadow areas transparent-friendly.

## Production requirements

- Strict fixed grids, isolated cells, consistent cell sizes, and ample transparent spacing so each asset can be sliced into an atlas.
- Native-resolution pixels: treat output pixels as final UI pixels, like the existing button atlas, not enlarged sprite blocks.
- Prioritize production usability over presentation: clean transparency, sharp edges, and empty centers for runtime Chinese text.
