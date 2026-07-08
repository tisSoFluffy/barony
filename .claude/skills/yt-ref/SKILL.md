---
name: yt-ref
description: >
  Analyze a YouTube video to extract a structured visual/design reference brief for
  any concept: art styles, environments, character design, UI/UX, lighting, animation,
  game mechanics, or anything visually definable. Extracts frames, reads them with
  vision, then outputs a concept brief tailored to whatever the user is trying to
  understand or replicate. Invoke with a YouTube URL and an optional concept label.
---

# YouTube Reference Analyzer

Pull structured design intelligence from any YouTube video.

## Invocation

```
/yt-ref <youtube-url> [concept]
```

- `<youtube-url>` — required
- `[concept]` — optional label for what to analyze (e.g. "HD 2D art style",
  "enemy AI behavior", "UI layout", "lighting", "environment design").
  If omitted, infer the most useful concept from the video content.
- `--frames N` (default 12) — frames to sample
- `--start SS` — start offset in seconds
- `--duration SS` (default 60) — seconds to sample

## What this produces

Adapt the output structure to the concept, but always include:

- **Concept summary** — one paragraph describing what was observed
- **Key visual/design elements** — bulleted breakdown of the defining
  characteristics relevant to the concept
- **Technical notes** — how it might be implemented (shader approach, layer
  setup, animation rig, etc.)
- **Reference frames** — call out specific frame indices that best exemplify
  the concept
- **Application prompts** — 3–5 actionable prompts for image generation,
  shader writing, or implementation, tuned to this exact reference

For art-style concepts (HD 2D, pixel art, painterly, etc.) also include a color palette table:

| Role     | Hex   | Description |
|----------|-------|-------------|
| Primary  | #...  | ...         |

## Workflow

1. **Extract frames**:

```bash
python3 tools/yt-ref/extract_frames.py "<url>" [--frames N] [--start SS] [--duration SS]
```

Parse frame paths from lines after `FRAMES:` (two-space prefix).

2. **Read all frames** with the Read tool before analyzing — load them all first
   for accurate color and pattern recognition across the full sample.

3. **Produce the brief** using the structure above, tailored to the concept.

4. **Save** (if user asks): `tools/yt-ref/briefs/<concept-slug>.md`

## Notes

- Keep duration ≤60s unless the user asks for more.
- For gameplay clips, prefer sections showing the mechanic/environment of interest.
- yt-dlp and ffmpeg required: `pip3 install yt-dlp` and `brew install ffmpeg`
