# Cat animation assets V4 — production revision 1

Produced and integrated on 2026-10-18 under the owner's explicit M8 V4 authorization.
This is an art revision; runtime `schemaVersion` remains **1**. Original `walk/` files are
unchanged. The owner approved the delivered V4 visual result on 2026-10-18 (“está aprovado”).
This records artistic approval; no additional desktop test results accompanied it.

## Delivery

| Clip | Frames | FPS | Playback / nominal duration |
|---|---|---|---|
| `idle` | 6 | 4 | loop / 1.50 s |
| `jump-start` | 4 | 26⅔ | once / 0.15 s |
| `jump` | 4 | 12 | once then hold / 0.333 s |
| `fall` | 6 | 12 | loop / 0.50 s |
| `landing` | 4 | 40 | once then hold / 0.10 s |

24 new frames plus 8 unchanged walk frames. Counts differ from the flexible 28-frame brief:
these selected poses preserve the intended phase durations without duplicating drawings.
All new frames are 512×512 RGBA8 sRGB, right facing, displaySize 96×96 pt and anchor (0.5, 0.074).
The manifest owns timing, events, frame paths and cycle-free fallbacks. `land → landing` and
`jump-air → jump` preserve legacy requests; missing optional clips still fall back to walk.
`blink` is on idle frame 4, `takeoff` on preparation frame 4 (entry at 0.1125 s), `contact` on
landing frame 1 and `settled` on frame 4 (entry at 0.075 s). Events never control physics:
launch occurs at the simulation's 0.15 s deadline and physical contact starts landing immediately.
No automatic `next` chain or tuning change was introduced.

## Provenance and reproducible export

Artwork: OpenAI built-in `image_gen`, transparent output, generated 2026-10-18. The tool did
not expose a model/version identifier. Full prompts, settings and original walk references are
in [production-prompts.json](production-prompts.json). Generated sheets are preserved unmodified
in [sources/](sources/). These development sources are bundled by the current folder-copy step
but are never decoded by CharacterLoader; selective packaging remains M14.

The dependency-free [exporter](../../../../scripts/export-v4-sprites.swift) uses macOS ImageIO /
CoreGraphics. From the repository root, export to a **new** directory:

```sh
swift scripts/export-v4-sprites.swift assets/characters/cat/v4/sources /tmp/petscape-v4-new-export
```

It refuses an existing destination. It isolates row-major connected bodies (alpha ≥128), retains
soft silhouette fringes, removes disconnected sheet noise, makes near-opaque interior alpha 255,
and resamples to the common canvas. Each clip uses one uniform scale, never per-frame auto-fit.
Grounded registration uses anatomical paw contacts at x=166.5 / 346.5, optional far paw x=246.5,
sole row 474. A monotonic offline ankle/paw adjustment removes generator drift while leaving
head/torso above row 375 unchanged. Airborne registration uses the common head/ear reference;
virtual foot position and runtime anchor never follow tucked paws. This processing applies only
to the new generated art. Original walk files are never rewritten.

[export-report.json](export-report.json) records source bounds, clip scale and registration.
[qa-report.json](qa-report.json) records every output's alpha/solid bounds, opacity and clip union;
coordinates are image y-down, maximum bounds exclusive. [sha256.json](sha256.json) identifies
all 32 runtime PNGs, 5 source sheets, manifest and production/QA reports.
Code uses the repository license. **Asset redistribution license remains owner decision D-08**;
no new art license is asserted by this delivery. Resolve it before public distribution.

## Validation and review

Actual CharacterLoader: 6 clips, no placeholder/load issues; **10,616,832 decoded bytes
(10.125 MiB)**, below the owner-approved 16 MiB V4 budget. Walk alone retains its original
2,654,208 bytes and ≤3 MiB gate. Source dimensions do not change layer bounds or collision geometry.

V4CharacterPackTests check actual clip loading, all-frame containment including alpha-1 fringe,
opaque body, baseline and individual planted-paw drift ≤1 source px. They also compare actual
production art with a walk-only pack through every physical phase: identical position, velocity
and state. Independent review found planted-paw drift and soft border overflow; both were
reproduced with failing assertions and corrected before the full 361-test suite passed.

[Scale/identity comparison](../../../../docs/assets/v4/scale-and-identity.png) places unchanged walk
beside each phase at 0.5/1/1.5 scale, both facings, on light/dark/checkerboard backgrounds.
These are offline previews; subsequent owner test confirmation closed the native review gate.
[Contact sheet](../../../../docs/assets/v4/contact-sheet.png) rows: idle, preparation, rising,
falling, landing. Light/dark backgrounds and the green virtual foot baseline are inspection aids.
[Clip preview](../../../../docs/assets/v4/animation-preview.gif) loops each clip independently at
96/144 pt in opposite facings; it does not represent domain transitions.
[Jump cycle](../../../../docs/assets/v4/jump-cycle.gif) draws actual PetWorld snapshots at explicit
1/60 s on light/dark backgrounds, both facings, with an Idle → vertical jump → Idle sequence.
It is an offline simulation preview, not a desktop capture. Owner visual approval is recorded above.

The owner subsequently reported all remaining M7/M8 tests complete and explicitly requested closure
(2026-10-18). The delivered visual/native result is accepted for M8 completion. No per-scale
recording, interaction-point count or numeric performance proof is inferred; see the
[owner closeout](../../../../docs/planning/m7-m8-technical-review.md#owner-m7m8-closeout-2026-10-18).
The existing DEBUG Animation preview and jump controls expose the integrated clips. Performance
and broader M7/M8 acceptance limits remain in [performance.md](../../../../docs/specifications/performance.md)
and [testing.md](../../../../docs/development/testing.md). No M9 autonomy or release is included.
