# Cat V6 climbing clip

M11 adds one two-frame `climb` loop. The source poses were generated with the built-in image
generation tool on 2026-10-22, using the immutable V4 `idle_01.png` as the identity/style reference.
Each output frame is a separate 1254×1254 transparent PNG saved unchanged under `sources/`.
The runtime derivatives are 512×512 PNGs under `climb/frames/`; `climb/export-report.json` records
source bounds, shared scale, and paw registration. `scripts/export-climb-sprites.swift` reproduces
the export into a new directory and refuses to overwrite an existing export.

The poses show the kitten reaching and bracing up the right wall. Prompts required a single isolated cat,
transparent background, the V4 blue-grey kitten identity and lighting, no wall/floor/background,
and no canvas clipping. Follow-up prompts referenced both the V4 identity frame and the first
climb pose to keep identity and camera composition stable.

The clip uses `alignment: "right"`, anchor `(0.977, 0.5)`, 8 fps and loop playback. Right-side paws
are registered to the anchor within 3 pt at the 96 pt display size. Export places the content 30 px
lower in the 512 px canvas to preserve the full ear silhouette; the runtime alpha bounds are
`(135,11)-(501,470)` and `(125,15)-(503,459)`, leaving at least 11 px of canvas margin. Facing left
mirrors the same authored right-side contact around the anchor, so the wall contact stays fixed on
the left edge.
Layer bounds remain the existing manifest `displaySize` (96×96 pt); source pixel dimensions never
set runtime bounds. Missing/invalid `climb` frames resolve through the existing `idle` fallback.

The pack tests validate both frames' decoded dimensions and right-side paw registration. The two-frame
loop keeps the pack within its existing decoded-image memory budget. Original V3/V4/V5 files were not changed. Generated
climbing art has not received owner visual approval; native visual review remains part of M11
acceptance.

## SHA-256

```text
a6b209f025ed6f367cd4d4cb148dc07dede55f8ff1b04ea55553b4cdb3494c00  sources/climb_01-source.png
f6d9cf2fac9fa50e95d90188717f070b56c905153fc7217a876c9b6e5b155ebc  sources/climb_02-source.png
d840188a9ed0796a4bb31bcc7447fbd5a97af6ad662acc73b51dd822eef2722a  climb/frames/climb_01.png
e9971ec42904c4fd28105342d649f05b370b33b251dd80cf6e14cdf1173a2d8e  climb/frames/climb_02.png
```
