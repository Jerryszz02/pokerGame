# Promotional video editing tools

Checked on 2026-10-15. The production choice is local Remotion editing with
recorded gameplay and an explicit timeline. AI agents prepare and revise the
edit; a separate reviewer evaluates the exported videos. Tool availability is
separate from account entitlement, which was not tested for Adobe or Descript.

## Options considered

- **Remotion:** supports coding agents, local preview and rendering, frame-based
  timing, configurable canvas dimensions, and subtitle import/export. These
  controls suit fixed 60/60/80/30-second outputs, bilingual captions, separate
  portrait framing, and changes tied to reviewer timestamps. This suitability
  is our assessment, based on the documented controls.
  Sources: [agent workflow](https://www.remotion.dev/docs/your-first-video),
  [timing](https://www.remotion.dev/docs/sequence),
  [composition](https://www.remotion.dev/docs/composition),
  [subtitle import](https://www.remotion.dev/docs/captions/importing),
  [subtitle export](https://www.remotion.dev/docs/captions/exporting).
- **Adobe Quick Cut:** automatically selects and assembles uploaded footage into
  a first draft. The available connector exposes automatic highlight selection;
  its local skill identifies target duration as approximate and requires
  Creative Cloud ingestion. This is useful for exploring a rough cut, but we
  cannot assume it will preserve a specific poker hand's decision, result, and
  replay. It was not used to upload or process footage.
  Source: [Adobe Quick Cut overview](https://helpx.adobe.com/firefly/web/firefly-video-editor/create-quick-cut/quick-cut-overview.html).
- **Descript:** offers transcript-based editing, captioning, automatic clips,
  translation, and reformatting. We assessed it as a stronger fit for narrated
  recordings than these gameplay-led, non-narrated trailers. It was not used.
  Source: [Descript features](https://www.descript.com/features).

Automatic highlight selection lets a model choose moments. Programmable editing
lets an agent specify source paths, source in/out points, order, text, and framing
in a reviewable timeline. The latter is the chosen workflow here. Gameplay must
remain recorded evidence; generated replacement gameplay is not part of the edit.

## Objective evidence

`tools/promo-edit/verify_media.py` measures exported files with local FFmpeg and
FFprobe. It records stream metadata, full-file decode diagnostics, original
integrated loudness/true peak/LRA, black intervals, silence intervals, sampled
frames, and contact sheets. Its loudnorm reference is -16 LUFS / -1 dBTP / 11 LU;
measurement discards the filtered audio and never changes the source file.
Detected intervals do not automatically mean an editorial defect. Independent
review must still assess continuity, readability, timing, factual claims, and
audio balance against the agreed rubric.
