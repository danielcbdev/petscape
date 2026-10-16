# Asset Format

Defines how character art is organized and what the images must look like.
The manifest format is in [animation-schema.md](animation-schema.md).
Decision: [ADR-0007](../decisions/0007-character-packs.md).

## Source art vs character packs

| Kind | Location | Rules |
|---|---|---|
| **Original source art** (as delivered) | `assets/characters/<id>/<clip>/` (`frames/`, atlas, GIF preview, `README.md`, `manifest.json`) | **Read-only.** Never edited, renamed or re-exported in place. Replacements arrive as new files/versions. |
| **Character pack manifest** | `assets/characters/<id>/character.json` | New file authored by the team; references source frames by relative path. Edits allowed. |
| **Bundled pack** (in the app) | `PetScape.app/Contents/Resources/Characters/<id>/` | Built from the pack; only the manifest and the frames it references are shipped (previews, atlases not referenced, READMEs and `.DS_Store` are excluded). Mechanism chosen in task T4.9. |

The original `manifest.json` next to the frames is an art-pipeline note, not the runtime manifest.
It is kept unchanged.

## Pack layout

```text
assets/characters/cat/
├── character.json                  # runtime manifest (schema v1) — added in M4
└── walk/
    ├── README.md                   # source notes (original)
    ├── manifest.json               # source notes (original)
    ├── walk_atlas.png              # original, not used at runtime
    ├── walk_preview.gif            # original, not used at runtime
    └── frames/
        ├── walk_01.png … walk_08.png
```

Future clips follow the same shape: `assets/characters/cat/<clip>/frames/<clip>_NN.png`.

## Image rules (for new art)

| Rule | Requirement | Why |
|---|---|---|
| Format | PNG, 8-bit per channel RGBA, sRGB | Universal decode; predictable color |
| Alpha | Straight (non-premultiplied); background fully transparent (alpha 0); **character body fully opaque (alpha 255)**; soft edges only on the silhouette | Avoids see-through bodies; clean hit masks |
| Canvas | Same canvas size for all frames of a clip (may differ between clips) | Stable anchor |
| Contact point | Same pixel position across all frames of a clip (e.g. paws on the same baseline row) | No vertical jitter when walking |
| Margin | ≥ 8 px transparent margin on every side; enough room for the clip's full pose range | No clipping of tails/ears |
| Facing | Right-facing by default (declare otherwise in the manifest) | Mirroring rule |
| Naming | `<clip>_NN.png`, 1-based, zero-padded to 2 digits (3 if > 99 frames) | Sorted listings, readable manifests |
| Resolution | Author at ≥ 2× the largest on-screen size (e.g. ≥ 288 px tall for a 96 pt pet at 1.5× user scale); 512 px canvases are fine — they are downsampled at load | Retina sharpness without waste |
| Lighting | Light source consistent with the existing cat (top-left soft key) | Mirroring stays believable |
| Previews | GIFs/atlases optional; never referenced at runtime unless declared as a sheet | Keep bundle small |

## Hit masks (derived, not authored)

At load, each frame produces a `HitMask`: a 1-bit grid at ¼ of the decoded texture resolution,
cell = 1 when any covered pixel has alpha ≥ 128, then dilated by 1 cell to make grabbing easier.
Hit testing maps the cursor into the current frame's mask (respecting mirroring and scale).
Threshold must not require alpha 255 (see audit finding F6).

## Current asset audit (2026-10-16)

Inspected `assets/characters/cat/walk/` with `sips`, `file` and a Python/Pillow script
(alpha histograms, bounding boxes, atlas tile comparison). Files were only read.

| # | Finding | Impact | Action |
|---|---|---|---|
| F1 | 8 frames `walk_01…walk_08.png`, each 512 × 512, RGBA 8-bit, RGB color model, ~173–203 KB | Matches README | — |
| F2 | `walk_atlas.png` is 2048 × 1024 = 4 columns × 2 rows of 512 px tiles; every tile is **pixel-identical** to the corresponding frame (row-major) | Redundant; no slicing metadata | Not used at runtime; can be declared as a `sheet` if ever needed |
| F3 | `walk_preview.gif`: 512 × 512, 8 frames, 110 ms each (≈ 9.09 fps), infinite loop | Preview only | Not shipped |
| F4 | `manifest.json` has `animation`, `frames: 8`, `canvas: [512, 512]`, `fps: 9`, `source` — no frame list, anchor, facing, character id or schema version | Insufficient for runtime | New `character.json` (schema v1) supersedes it at runtime; original kept |
| F5 | README: "V3", AI-generated sheet, automated isolation; "may contain generation artifacts; animation needs artistic review" | Prototype quality | Visual QA in PoC; replace later |
| F6 | **Body alpha is 250–254, not 255**: per frame only ~176–236 pixels are fully opaque while ~79k–93k pixels sit at 250–254 | Body is ~1–2% translucent; desktop content may faintly show through; a "alpha == 255" hit test would fail | Hit mask threshold 128; request re-export with opaque body; consider clamping alpha ≥ 250 → 255 at load (decide in M4, logged) |
| F7 | Soft fringe: ~2.0–2.7k pixels with alpha 1–15 and ~1.2–1.4k with alpha 16–63 per frame | Possible faint halo on dark/light backgrounds | Check against dark and light wallpapers in PoC |
| F8 | One connected component (alpha > 32) in frames 01 and 05 — no stray islands found (other frames not checked) | Good isolation in sampled frames | Check all frames in T4.1 fixture test |
| F9 | Lowest solid row (alpha > 128) is y = 473–474 (from top) in all 8 frames; 38 px transparent below | Stable ground contact | Anchor y ≈ 38 / 512 = 0.074 (from bottom) |
| F10 | Solid horizontal extent x ≈ 19–490 in all frames (~92% of the canvas width; ~20 px side margins); center ≈ 254–255 | Tight canvas; future poses may not fit 512 | Anchor x = 0.5; allow per-clip canvas |
| F11 | Solid vertical extent varies 352–409 px (head bob, tail) | Expected motion | — |
| F12 | Character faces **right** | — | `defaultFacing: "right"`; mirror for left |
| F13 | No idle, turn, sit, sleep, jump, fall or land clips | MVP turn is an instant flip; post-MVP needs art | See art dependencies in [roadmap.md](../product/roadmap.md) |
| F14 | Ground speed of the walk cycle is unknown | Foot sliding if speed is guessed | Measure stride in M5 (T5.3) and record `nominalSpeed` |
| F15 | `.DS_Store` files are tracked in git under `assets/` and at the root | Noise in the repo/bundle | Untrack and ignore (T0.2) |

Sizes on disk: frames ≈ 1.5 MB total, atlas ≈ 1.48 MB, GIF ≈ 0.30 MB.
