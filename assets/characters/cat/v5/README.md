# Cat V5 interaction clips

This additive pack revision supplies the three M10 interaction clips while preserving the V4
sources. `character.json` stays at schema v1 and keeps the established 96×96 pt display size and
`(0.5, 0.074)` virtual foot anchor.

## Delivery

| Clip | Frames | Rate | Playback | Notes |
|---|---:|---:|---|---|
| `curious` | 6 | 6 fps | loop | Attention/gaze variations and one blink event; planted paw row registered at 474 |
| `picked-up` | 4 | 20 fps | once | Short lift response; art ends in a relaxed lifted pose |
| `held` | 6 | 6 fps | loop | Suspended relaxed pose, subtle breathing/blink; virtual foot row is registration only |

All 16 PNGs are RGBA 512×512. The generated source frames were placed on a transparent 512 canvas
and downsampled to 440×440 with AppKit high-quality interpolation, centered with 36 px padding.
Near-opaque body pixels (alpha ≥250) were normalized to fully opaque; softer silhouette edges were
preserved. Frames were then vertically registered so the solid-alpha virtual foot row is 474
(±0 px). No
original V4 frame, atlas, GIF, manifest or README was re-exported in place.

## Provenance and review

The image generation tool created each pose individually using the corresponding V4 idle frame as
the identity/style reference; the suspended held sequence used the generated lifted-paws pose as
its pose reference. Raw 1254×1254 outputs are preserved in
[`docs/assets/v5/production-source`](../../../../docs/assets/v5/production-source), with SHA-256
checksums in [`SHA256SUMS`](../../../../docs/assets/v5/production-source/SHA256SUMS). The sources
stay outside the app bundle; runtime PNGs are the normalized derivatives of those generated
sources. The pack is additive; physics, the 0.2 s pickup phase, and release behavior remain
simulation-owned.

Automated review covers schema loading, clip timing/counts, decoding budget, dimensions, transparent
border and registration. This record does not claim the owner's visual approval. The owner should
review the 16 runtime-size frames in the DEBUG Animation preview and confirm identity, transitions,
left-facing mirroring and motion quality before treating the art as visually accepted.
