# M15 — Animation quality: implementation and verification

Status: **Rework, visual-review stage.** On 2026-10-23 the owner **visually rejected** the V7
delivery described under "Historical V7 delivery" below. Its automated, UI and build results are
kept as history; they are not owner acceptance and do not count as visual-quality evidence. A V8
candidate for `walk` and `curious` only is integrated for owner review. All other clips are
unchanged V7 until that direction is accepted. M14 is untouched; M16–M20 remain planning only.

## Owner visual rejection (2026-10-23)

Reported: animations too fast even at the slowest Speed setting; legs seem to vanish during the
walk, with no continuous readable progression; head movements are small, short and too fast; adding
frames to the existing sequence did not produce fluency. Preserving the original durations is no
longer required.

## Diagnosis of the rejected V7 pack

1. **Displacement speed.** Walk ground speed is `nominalSpeed` 20 pt/s × Speed (0.5–2) × pet scale,
   so 10 pt/s at the slowest setting.
2. **Cadence.** Speed scales the walk's animation rate by the same factor, so displacement and paw
   cadence stay coupled. V7 walk: 0.889 s cycle (2.25 fore-paw steps/s at Speed 1). **Speed affects
   only the walk** (`PetWorld` sets `animation.rate = 1` for every other state), so idle, curious
   and all reactions play at full speed even at Speed 0.5. This is one reason "slowest" still
   looked fast.
3. **Action duration.** `curious` is a 1.0 s loop whose only head turn (toward the camera) is a
   single 83 ms drawing (key 2 of 6); the blink is one drawing. A click reaction holds `curious` for
   0.6 s (`PetWorld`, `reactingToClick`).
4. **Amplitude.** Key-to-key head height jitters by up to 57 canvas px (10.7 pt at 96 pt) in the walk
   with no motivation, while the intended curious gesture has no sustained pose to read.
5. **Pose continuity (root cause).** Every walk/curious drawing (V3 originals and V7 in-betweens) is
   an independent image generation. Measured contact band just above the floor: visible paw blobs per
   walk drawing go 2→3→3→3→…→4→2. Paw x positions jump forward and back by 30–70 px between
   consecutive drawings, where a planted paw should move back about 6 px. Leg identity is not
   preserved, so legs "vanish" and swap; doubling FPS (9→18) only made that flicker faster. More
   drawings of the same kind cannot fix this, so the rework changes the production method.

## V8 rework: method and provenance

- **Source:** one original authored key, `walk/frames/walk_01.png` (V3, read-only, unchanged).
- **Rig:** [`scripts/build-m15-rig.swift`](../../scripts/build-m15-rig.swift) cuts the key into head,
  tail, torso, near thigh/upper arm, shins and paws. It poses them with rigid rotation/translation
  only: no warping, no blending between frames, no frame copies. The far fore leg reuses the near fore
  shin/paw toned 0.9 at the far paw's key position (standard cut-out practice; the key hides that leg).
  Torso pixels under a moving near thigh/upper arm are pulled 12 px inside the silhouette, so no
  static ghost edge shows. Blinks are the only newly painted content: a lid inside the key's eye
  outline, fur colour sampled from the key, shaded, with a lash line.
- **Assets:** `assets/characters/cat/v8/{walk,curious}/frames/*.png` (66 new 512×512 RGBA files).
  `v8/rig-report.json` holds per-frame durations, events and paw contacts.
  `v8/rejected-v7-character.json` is the exact rejected manifest, for comparison and rollback.
  No existing file was overwritten.
- **Reproduction:** `swiftc -O -warnings-as-errors scripts/build-m15-rig.swift -o /tmp/m15-rig &&
  /tmp/m15-rig . <new-dir>` (refuses to overwrite). A rerun into a fresh directory was
  byte-identical to the delivered frames and report.
- **Review page:** [docs/assets/v8/review.html](../assets/v8/review.html). It shows current vs
  proposed on one clock at real 96 pt (1 CSS px = 1 pt) and 2×/3×, with 1×/½×/¼×/0.1× playback,
  frame stepping and keyboard arrows. The walk moves across a ticked floor or in place, and Speed
  presets 0.5/1/2 follow the app's rules. Serve the repository over HTTP to open it.

## V8 per-clip record (candidate)

| | `walk` | `curious` |
|---|---|---|
| Problem | Independent drawings: paws jump, legs vanish/swap, head bobs ~10 pt at random | Head turn lasts 83 ms; nothing readable; 0.6 s click cut |
| Drawings | 16 → **30** | 12 → **36** (holds use longer drawings) |
| FPS / timing | 18 fps → **30 fps** (every drawing = 2 simulation steps) | 12 fps → **per-frame durations**, whole 1/60 s steps, 17–367 ms |
| Duration | 0.889 s → **1.000 s** cycle | 1.000 s → **3.600 s** loop |
| Speed | `nominalSpeed` 20 → **13.5 pt/s**, derived from the drawn stride (72 px = 13.5 pt per cycle), so planted paws stay fixed on the ground | rate 1 (unchanged app rule) |
| Motion | Lateral-sequence gait (near hind 0, near fore 0.25, far hind 0.5, far fore 0.75), duty 0.62, minimum-jerk swing, lift 12–15 px, paw roll in swing; body bob 1.2 px, pitch ±0.6°; head counter-motion ≤0.6 px / 0.5°; tail sway ±3.5° | Anticipation dip 0.2 s (+3°); lift and tilt −15°, +7 px in 0.42 s with overshoot; settle and hold 0.78–1.30 s with blink (0.95–1.19 s); full return by 1.80 s; slower cock +8° (0.55 s), hold, settled return by 3.40 s; body lean ≤1.4°, tail rises ≤7° |
| Events | `footstep` on each fore-paw touchdown (frames 9 and 24, 0.267 s / 0.767 s); was 0.222 / 0.667 s | `blink` on the first closed drawing (1.017 s) |
| Behavior effect | Ground speed at Speed 1/0.5/2: 13.5 / 6.75 / 27 pt/s; cycle 1.0 / 2.0 / 0.5 s. No simulation, gravity or jump change | Click reaction still 0.6 s and cuts the gesture mid-lift. Proposed: 1.8 s (one complete look). **Not changed yet; owner decision.** Cursor observation (1–3 s) can still end mid-gesture |

## V8 verification so far

- **Contacts:** package test `reworkedClipsKeepPlantedPawsLockedToTheGroundSpeed` checks every
  planted paw moves back exactly `nominalSpeed / 30` pt per drawing, including the 30→1 seam. It also
  checks frame/event/duration agreement with the rig report.
- **Pixels:** 66 distinct drawings, 8 px margin, ground registration at row 474, one connected body.
  A new stricter seam check requires every interior pixel (4 px neighbourhood opaque) to be ≥ 235
  alpha, with at most 3 isolated exceptions ≥ 160 (the key's own far-eye outline notch under
  rotation). V8 does not use the V7 "95% of solid pixels at 255" rule, because the source key itself
  only reaches 93.5% (soft fur edge). The seam check found and drove fixes for a tail sign error
  (the tail lowered instead of rising) and a thigh-edge pinhole.
- **Native app:** the Debug `--animation-preview` window played the V8 walk at 30.00 measured frame
  changes/s, ground 13.5 pt/s, with the locomotion family at 14.6 MB decoded. Timed window captures
  showed consistent leg poses on the baseline. The native `curious` playback was **not** inspected:
  the agent could not operate the clip pop-up. Fluency at 96 pt is a subjective judgement that only
  the owner can accept.
- **Gates:** 482 package tests, `make lint`, Debug and Release (warnings as errors) builds pass; UI
  tests not rerun for V8.
- **Browser review page:** played and stepped at 96 pt and 3×, walk and curious, current vs proposed.
- **Memory:** full pack 131 frames × 288² × 4 = 41.45 MiB once all families are loaded (was 29.43
  MiB). The M15 full-pack test ceiling moved from 32 to 42 MiB with this owner-authorized increase;
  initial locomotion stays ≤ 16 MiB (14.55 MiB). This exceeds the performance spec's ≤ 10 MB
  frame-memory target (already exceeded by M8/M15). **Owner decision needed** before reworking all
  clips (options: accept a budget, trim transparent canvas at load, or hold more drawings).

## Open owner decisions

1. Accept or redirect the V8 cut-out rig direction (walk and head reaction) before any other clip.
2. Click-reaction hold 0.6 s → 1.8 s, so the gesture completes.
3. Whether Speed should also slow non-walk clips (a behavior contract change, not made).
4. Frame-memory budget for the full rework.

## Historical V7 delivery (visually rejected 2026-10-23; kept as history)

The text below is the original V7 record, unchanged except for this heading level. Its "In review"
claims are superseded by the rejection above.

### Inventory and delivered timing

The immutable [baseline manifest](../../assets/characters/cat/v7/baseline-character.json) records the
exact original paths, order, FPS, events and contracts. The active
[manifest](../../assets/characters/cat/character.json) preserves every original key in that order and
inserts a drawn midpoint after each eligible key. New paths are `v7/<clip>/frames/<clip>_NN.png`;
even numbers identify new positions. There are 50 original + 43 new = **93 unique frames** across
the same ten clips. No new behavior or clip identifier was introduced.

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

`jump-start`, `jump` and `picked-up` are one-shot clips: split only the first three original
intervals, preserving the final original hold with an explicit duration (0.0375, 1/12 and 0.05 s
respectively). Their seven frames therefore do not use the naive count/FPS duration formula.
Every original key/event entry time and total duration is asserted against the baseline. All other
loop intervals are halved; event-bearing original frames retain their events. Schema v1, fallbacks,
playback modes, interruption rules, anchors and 96 × 96 pt displaySize are unchanged.

### Production and integration

- Thirteen original built-in image-generator outputs and 43 distinct exported RGBA drawings live in
  [V7](../../assets/characters/cat/v7/README.md). Prompts, reference paths, export plan, registration
  report and alpha QA are included. The tool does not expose a model version; none is invented.
- Early candidates were initially misjudged at different source resolutions. Comparing them at
  equal display size showed usable identity; resolution normalization enabled production. Final
  exports were reviewed at equal scale. There is no missing art/artist handoff.
- The new [exporter](../../scripts/export-m15-sprites.swift) extracts authored silhouettes, retains
  soft edges, applies a common sheet scale and anatomical registration, removes detached specks
  and writes 512 × 512 PNGs. It does not create poses through interpolation, copying or deformation.
  Single-source walk images use an explicit source-resolution conversion. Tiny containment
  translations are recorded. Existing image files were never rewritten.
- DEBUG preview layout now contains the entire canvas when a wall anchor is used at enlarged sizes.
  A failing regression test first reproduced clipping at 144/192 pt; native inspection confirmed
  the fix at 192 pt. No production timing or renderer architecture changed.
- Historical V4 tests retain their exact old assertions against a temporary baseline-pack fixture.
  Current-pack tests exercise the delivered 93-frame manifest. No assertion was weakened to pass.

### Visual review performed on 2026-10-23

All ten clips were selected and played in the native DEBUG animation preview at 96 pt, facing right,
including the retained landing. Walk, climb and held were also checked enlarged and facing left.
The wall preview was checked again after fixing its enlarged-canvas crop. Review covered pose
progression, loop seams, blink/contact/takeoff keys, silhouette containment, transparent edges and
contact registration. No cropped silhouette, duplicated drawing or new root jump was observed at
96 pt. New poses preserve the blue-grey/amber-eyed identity; generated fur detail and head-angle
variation remain visible when enlarged. Owner aesthetic acceptance remains subjective and pending.
Existing key-to-key art variation and historical walk paw-slip are retained, not newly measured or
claimed eliminated. Native preview counters establish playback, not a performance benchmark.

The [offline before/after viewer](../assets/v7/preview.html) supports 1×/0.25×, scrubbing, 48/96/144 pt,
both facings and light/dark/checker backgrounds. It was played and inspected at quarter speed,
including the interaction clips and mirrored enlarged comparison. One-shot clips repeat after a
viewer-only 0.4 s hold. The native app remains authoritative for physics and transitions.
Legacy V5 PNG gAMA metadata brightens in browsers; review-only copies remove that metadata while
keeping pixel/alpha data identical. Originals and native loading are unchanged. The corrected
browser comparison was inspected. The [contact sheet](../assets/v7/contact-sheet.png) labels every
original/new position. Still images supplement, rather than replace, playback inspection.

### Automated evidence

- `make lint` and strict exporter formatting — passed.
- `make test` package phase — **481 tests passed**: Core 309, Runtime 88, Rendering 50,
  Platform 34 (54 suites total). Includes six M15 tests covering exact old key/event timing,
  unchanged source hashes, 43 distinct opaque/contained silhouettes, actual lazy loader budgets,
  unchanged seeded jump trajectory and enlarged wall-preview layout. Red tests preceded integration
  and the preview fix; final package results are in `build/m15-package-final.log`.
- `make build` — Debug passed; final Release build with warnings-as-errors passed
  (`build/m15-debug.log`, `build/m15-release-final.log`). Xcode's existing App Intents metadata warning
  and ambiguous macOS destination warning are build-tool notices; no Swift compiler warning passed.
- Export reproduction — all 43 regenerated PNGs match the delivered bytes; all 93 manifest image
  references resolve and decode. All tracked original asset files except the intentionally updated
  runtime manifest retain their recorded SHA-256; baseline manifest matches pre-M15 HEAD exactly.
- UI tests — **2 passed, zero failures**, 17.631 s, on the owner-requested retry at
  2026-10-23 16:33 local time. Command: `xcodebuild -project PetScape.xcodeproj -scheme PetScape
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES -configuration Debug test`.
  Log: `build/m15-ui-owner-retry.log`; result:
  `build/DerivedData/Logs/Test/Test-PetScape-2026.10.23_16-32-50--0300.xcresult`.
  The first three attempts timed out enabling macOS Automation Mode before test bodies; the unchanged
  fourth run initialized successfully and exercised both UI tests. No test, entitlement or privacy
  permission was changed to bypass the earlier timeouts. XCTest emitted DisplayManager diagnostics
  during interaction; both tests completed successfully.
- Loaded texture storage: 93 × 288 × 288 × 4 = **30,855,168 bytes / 29.43 MiB** for every family;
  initial locomotion family remains below 16 MiB. The M15 full-pack regression ceiling is 32 MiB;
  the baseline's historical 16 MiB full-pack ceiling remains tested against its unchanged 50 frames.
  Exploratory DEBUG preview process physical footprint was 92.7 MiB, peak 94.7 MiB after all families
  loaded (`build/m15-debug-memory.log`). This is not a Release CPU/power or M14 benchmark.

### Acceptance and remaining owner actions

AC-M15-01: inventory delivered. AC-M15-02: source/alpha/pose review performed; owner aesthetic
acceptance pending. AC-M15-03: exact timing/contracts/path/schema assertions pass. AC-M15-04:
package tests, original hashes, lint, Debug/Release and both UI tests pass.
AC-M15-05: native playback and offline slow review performed as described above. AC-M15-06:
provenance/evidence delivered; M16–M20 remain planning only, release moved to M20.

1. Open the offline viewer or run `open build/DerivedData/Build/Products/Debug/PetScape.app --args
   --animation-preview`; compare at 96 pt and confirm the visual identity/motion is acceptable.
   Mark M15 Done once visual acceptance is explicit. No Automation Mode action remains pending.

No repository implementation or generation work remains. No commit, push, tag, release, PR or merge
was performed. M16–M20 feature implementation remains outside this change.
