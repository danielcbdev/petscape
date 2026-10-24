# Asset Format

Defines how character art is organized and what the images must look like.
The manifest format is in [animation-schema.md](animation-schema.md).
Decision: [ADR-0007](../decisions/0007-character-packs.md).

## Source art vs character packs

| Kind | Location | Rules |
|---|---|---|
| **Original source art** (as delivered) | `assets/characters/<id>/<clip>/` (`frames/`, atlas, GIF preview, `README.md`, `manifest.json`) | **Read-only.** Never edited, renamed or re-exported in place. Replacements arrive as new files/versions. |
| **Character pack manifest** | `assets/characters/<id>/character.json` | New file authored by the team; references source frames by relative path. Edits allowed. |
| **Bundled pack** (in the app) | `PetScape.app/Contents/Resources/characters/<id>/` | The Xcode build phase runs `scripts/copy-referenced-character-assets.swift`, retaining `character.json` and only image paths referenced by its schema-v1 manifest. It preserves relative paths and fails the build for unsafe or missing references. Original sources remain untouched. |

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

Additional clips follow the same shape: `assets/characters/cat/<clip>/frames/<clip>_NN.png`.
V4 revision 1 adds `idle`, `jump-start`, `jump`, `fall`, `landing` (24 new frames), with immutable
generated sources/provenance under `v4/`. See the [production record](../../assets/characters/cat/v4/README.md)
for final checksums, all-frame QA and previews. The runtime manifest stays schema v1; the historical
walk audit below remains unchanged. The bundle includes only manifest-referenced files. The runtime
checks image metadata at startup, decodes the default behavior family before display, and loads other
families asynchronously on first use. M14 selective bundling omits the original README, pipeline
metadata, atlas and GIF when no runtime manifest references them.

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
| F6 | **Body alpha is 250–254, not 255**: per frame only ~176–236 pixels are fully opaque while ~79k–93k pixels sit at 250–254 | Body is ~1–2% translucent; desktop content may faintly show through; a "alpha == 255" hit test would fail | Hit mask threshold 128 (`HitMask`, tested with alpha 250). **M4 decision:** no alpha clamping at load — pixels are shown as delivered (the PoC showed no visible see-through) and clamping would mean rewriting decoded pixels; request a re-export with an opaque body instead |
| F7 | Soft fringe: ~2.0–2.7k pixels with alpha 1–15 and ~1.2–1.4k with alpha 16–63 per frame | Possible faint halo on dark/light backgrounds | Check against dark and light wallpapers in PoC |
| F8 | All 8 frames checked by `CatArtAuditTests` (M4): one body per frame (alpha > 32, 8-connected), except **frame 03, which has a 4 px speck at x 493, y 248–251 (max alpha 41)** — a generation artifact, below the hit-mask threshold | Barely visible; no effect on hit testing | Tolerated by the test only while specks stay ≤ 16 px and below alpha 128; ask for removal in the next re-export (originals are read-only) |
| F9 | Lowest solid row (alpha > 128) is y = 473–474 (from top) in all 8 frames; 38 px transparent below | Stable ground contact | Anchor y ≈ 38 / 512 = 0.074 (from bottom) |
| F10 | Solid horizontal extent x ≈ 19–490 in all frames (~92% of the canvas width; ~20 px side margins); center ≈ 254–255 | Tight canvas; future poses may not fit 512 | Anchor x = 0.5; allow per-clip canvas |
| F11 | Solid vertical extent varies 352–409 px (head bob, tail) | Expected motion | — |
| F12 | Character faces **right** | — | `defaultFacing: "right"`; mirror for left |
| F13 | No idle, turn, sit, sleep, jump, fall or land clips | MVP turn is an instant flip; post-MVP needs art | See art dependencies in [roadmap.md](../product/roadmap.md) |
| F14 | Ground speed of the walk cycle (T5.3, 2026-10-17): the art is not a physically consistent in-place cycle. Planted front paws travel ≈ 78 px per stance (≈ 33 pt/s at 96 pt, 9 fps), planted rear paws ≈ 4–5 px/frame (≈ 8 pt/s), and the best frame-to-frame alignment of the whole ground-contact band gives 60–92 px per cycle (≈ 13–19 pt/s). New paw contacts appear in frames 3 (front) and 7 (rear) | Some foot sliding is unavoidable at any single speed | `nominalSpeed: 20` (minimizes the worst slip, ≈ 13 pt/s on either pair); `footstep` on frames 3 and 7. The DEBUG Animation Preview scrolls ground ticks at an adjustable speed for the owner's visual check (AC-07); re-measure if the art is re-exported |
| F15 | `.DS_Store` files were tracked in git under `assets/` and at the root | Noise in the repo/bundle | Done: untracked and ignored (T0.2); never copied into the app bundle (checked in T4.9) |

Sizes on disk: frames ≈ 1.5 MB total, atlas ≈ 1.48 MB, GIF ≈ 0.30 MB.

## M15 / V7 delivery

The runtime cat pack now contains 93 unique frame references (50 original keys + 43 authored
in-betweens), still schema v1, 512 px canvases and 96 pt displaySize. Original files remain immutable.
[V7 production record](../../assets/characters/cat/v7/README.md) documents new source art, exporter,
registration, hashes and QA; [M15](../planning/m15-implementation.md) records exact duration/event
preservation and review. Fully loaded texture storage is 29.43 MiB at 288 px; initial families remain
lazy and below 16 MiB. Historical audits and budgets describe their original pack versions.
