# Cat V7 — M15 authored in-betweens

Production date: 2026-10-23. Supplements the immutable original/V4/V5/V6 cat art.
The active manifest references 43 new drawings interleaved with all 50 original keys.
No original image, atlas, GIF or original asset README was overwritten.

## Provenance

`sources/` contains 13 unmodified outputs from the built-in image generator. The model version
was not exposed. `production-prompts.json` records prompts and original reference paths;
`export-plan.json` maps sources to original key intervals. Sheets contain independently drawn
intermediates, not duplicated endpoints or automatically interpolated/warped poses.
`baseline-character.json` is the exact pre-M15 runtime manifest. `original-sha256.json` protects
tracked pre-existing assets; `sha256.json` inventories this delivery's sources and exported frames.
The existing project's art-rights/release decisions remain applicable; no new license is inferred.

## Reproduction

From the repository root, compile and export into a fresh directory:

```sh
swiftc -O -warnings-as-errors scripts/export-m15-sprites.swift -o /tmp/petscape-export-m15
/tmp/petscape-export-m15 assets/characters/cat/v7/sources build/m15-reproduced
python3 scripts/build-m15-preview.py
```

The exporter reads its plan/baseline beside `sources/`, extracts the connected silhouettes plus
soft alpha edges, applies one common resolution/scale conversion per source sheet and registers
anatomical landmarks. It uses ground contact, airborne ear tips or wall contact as appropriate.
Containment translations and scale are explicit in `export-report.json`; it refuses to overwrite
existing exported images. Resampling changes output resolution only, not pose anatomy.
Near-opaque alpha ≥248 becomes 255, matching the existing export convention; edges retain alpha.
All delivered frames are 512 × 512 RGBA with transparent margins and a coherent opaque body.
`qa-report.json` records measured opacity, border and solid bounds. Package tests independently
check the delivered pixels, manifest timing, old-key identity, source hashes and actual decoding.

## Timing and review

| Clip | Frames | Declared FPS | Duration before = after | Purpose, diagnosis and decision |
|---|---:|---:|---:|---|
| `walk` | 8 → 16 | 9 → 18 | 0.888889 s | Locomotion; smoother stride and tail counterbalance. Footsteps stay at 0.222222 / 0.666667 s; nominalSpeed stays 20. |
| `idle` | 6 → 12 | 4 → 8 | 1.500000 s | Standing breath/blink; subtle added chest, eyelid and tail poses. Blink stays at 0.750 s. |
| `jump-start` | 4 → 7 | 26.6667 → 53.3333 | 0.150000 s | Anticipation/push; three interior poses. Takeoff stays at 0.1125 s; physical launch remains independent at 0.15 s. |
| `jump` | 4 → 7 | 12 → 24 | 0.333333 s | Airborne tuck; three interior poses. Physics still selects fall at the apex and holds the final drawing when needed. |
| `fall` | 6 → 12 | 12 → 24 | 0.500000 s | Descent loop; six intermediate leg/tail poses. Physical contact still interrupts into landing. |
| `landing` | 4 → 4 | 40 → 40 | 0.100000 s | Retained: already 40 fps over 0.1 s (six simulation steps); four readable impact/settle keys. Extra frames would have little useful presentation time. Contact stays at 0 s, settled at 0.075 s. |
| `curious` | 6 → 12 | 6 → 12 | 1.000000 s | Attention/head turn; six intermediates reduce coarse 6 fps changes. Blink stays at 0.500 s. |
| `picked-up` | 4 → 7 | 20 → 40 | 0.200000 s | Lift reaction; three interior poses. The interaction phase stays 0.200 s. |
| `held` | 6 → 12 | 6 → 12 | 1.000000 s | Dangling breath/blink; six intermediates. Blink stays at 0.333333 s; release still interrupts immediately. |
| `climb` | 2 → 4 | 8 → 16 | 0.250000 s | Wall contact; two new alternations soften the two-key cycle. Right alignment and anchor (0.977, 0.5) are unchanged. |

The three seven-frame one-shot clips retain an explicit final original hold, so use the sum of
frame durations. displaySize stays 96 × 96 pt; all anchors, events, fallbacks and playback contracts
are preserved. Fully decoded storage is 29.43 MiB at the existing 288 px load size; families remain
lazy. No simulation change is needed.

See the [implementation record](../../../../docs/planning/m15-implementation.md),
[before/after viewer](../../../../docs/assets/v7/preview.html) and
[contact sheet](../../../../docs/assets/v7/contact-sheet.png).
The viewer's `color-normalized/` copies remove only legacy V5 gAMA metadata for browser display;
IDAT pixels and alpha are identical. They are review artifacts, never runtime assets or new poses.
Refresh them with the standard-library-only preview script above. Native ImageIO playback remains
the acceptance reference. The native preview wall-canvas crop fix is DEBUG-only.
