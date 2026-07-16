# 《深夜德州扑克》原生分辨率按钮图集

Create a replacement production-ready transparent PNG button skin atlas for the existing pixel-art poker game shown in the references.

The first reference is the old button atlas: keep its brass primary, blue-gray standard, and dark-red danger color families, but do not copy its coarse fake-pixel rendering. The second reference is the actual 1280x720 game screen and defines the final visual scale.

Layout: a strict 3-row by 5-column grid with generous fully transparent gaps. Rows: brass primary, blue-gray standard, dark-red danger. Columns: normal, hover, pressed, disabled, keyboard-focus. All 15 buttons must have identical dimensions and alignment.

Design every button for native display around 118x42 pixels, with the primary button also suitable for nine-slice extension to 360x48. Use a wide rectangular silhouette with short straight left and right sides, only 2-3 pixel clipped corners, and an empty center for dynamic Chinese text. No pointed or hexagonal ends.

Native-resolution pixel requirements: treat output pixels as real final UI pixels. Use crisp 1-pixel and 2-pixel outlines, small precise corner steps, restrained 1-pixel highlights, and clean flat color regions. Do not imitate a tiny sprite enlarged with 4x or 8x square pixel blocks. Do not use chunky pixels, antialiasing, gradients, blur, glow, soft shadows, subpixel edges, texture noise, painterly shading, or 3D rendering.

Palette only: #050B0A, #0E110F, #0F2B21, #CBA14D, #EDDFB8, #32505D, #9E2E2A. State differences must come only from palette swaps, a 1-pixel highlight, a 1-2 pixel pressed offset, desaturation, or a thin focus outline. Transparent background. No text, letters, symbols, icons, labels, grid lines, watermark, or overlapping assets.

Prioritize production usability over presentation: exact grid, isolated skins, consistent sizes, clean transparency, sharp edges, and ample empty center area for nine-slice scaling.
