# M15 — Animation quality: implementation and verification

Status: **Done by explicit owner acceptance, 2026-10-23.** The owner reported that the revised
animations are better and fluid, then requested the pacing/speed refinements below. After those
changes, the owner stated that testing was complete and explicitly authorized M15 closeout and
merge into `develop`. The rejected V7 and intermediate V8 records remain historical evidence.
M14 is unchanged; M16–M20 remain planning only.

## Owner M15 closeout — 2026-10-23

Owner confirmation: “já realizei os testes, pode fazer o fechamento do M15, atualizando o git e
mergeando para a develop.” This closes the subjective animation/pacing acceptance for the current
delivery. No additional click-point counts, session duration or quantitative native measurements
are inferred from that statement.

The delivered manifest contains **134 frames across ten existing clips**. V8 replaces the rejected
independent-pose sequences with the approved rig-based drawings; the retained landing stays at four
original keys. Existing source files remain immutable. Speed is configurable through 0.5–4; the
new default is 2 for absent/nonfinite preferences, while existing finite settings are preserved.
At 96 pt, walking is 27 pt/s by default and 54 pt/s at maximum; cadence scales with displacement.
Autonomous stationary states share a five-second ceiling and an eight-second walking interval
follows the ceiling or walking-intent autonomous landing. User pause/holding/disabled autonomy and
physical phases remain explicit exceptions.

| Delivered clip | Frames | Declared FPS | Total duration at rate 1 | Events |
|---|---:|---:|---:|---|
| `walk` | 30 | 30 | 1.0000 s | footstep @ 0.2667 s; footstep @ 0.7667 s |
| `idle` | 11 | per frame | 3.2000 s | blink @ 1.9500 s |
| `jump-start` | 5 | per frame | 0.1500 s | takeoff @ 0.1167 s |
| `jump` | 7 | per frame | 0.3333 s | — |
| `fall` | 12 | per frame | 0.8000 s | — |
| `landing` | 4 | per frame | 0.1000 s | contact @ 0.0000 s; settled @ 0.0833 s |
| `curious` | 36 | per frame | 3.6000 s | blink @ 1.0167 s |
| `picked-up` | 6 | per frame | 0.2000 s | — |
| `held` | 15 | per frame | 2.4000 s | blink @ 1.1500 s |
| `climb` | 8 | 30 | 0.2667 s | — |

Per-frame durations take precedence over declared FPS. Final key timing intentionally differs from
the rejected pack, under the owner's rework authorization. The approved manifest keeps schema v1,
96 pt displaySize, anchors and fallbacks; physics still owns flight/contact.

### Retained verification exception

Before requesting closeout the owner was informed that one V8 pixel-QA test reports 48
margin/seam issues, reproduced independently in a clean HEAD archive before the pacing changes.
The milestone is closed by owner acceptance **with that documented exception**; it is not a claim
that the entire package suite is green or that the pixel issues were repaired. No failing test was
skipped, removed or weakened. These findings remain a technical follow-up outside the accepted
pacing delivery; preserve them when working on later assets.

Fully decoded frame storage is 44,457,984 bytes (42.40 MiB), with a 43 MiB regression
ceiling and initial locomotion ≤16 MiB. This is the accepted delivered pack, not compliance with the
historical ≤10 MB frame-memory target or a new CPU/power benchmark. Existing measurements and
evidence limits remain in their original records.

314 Core, 34 Platform and 50 Rendering tests pass; 88 of 89 Runtime tests pass, with the pixel test
above remaining red. Both UI tests, strict lint and Debug/Release builds pass. Fresh closeout checks
are recorded in `build/m15-closeout-tests.log`, `build/m15-closeout-lint.log` and
`build/m15-closeout-debug.log`; the full package gate retains the known exception. The fresh closeout run also had a transient
Dock-side runtime regression failure (paused fake frame driver); the unchanged isolated retry
passed for both left and right Dock positions (`build/m15-closeout-dock-retry.log`). This is recorded
as a flaky/environment-sensitive result, not a repaired defect. Native subjective
acceptance comes from the owner. M15 integration is authorized; release, tags and M16 implementation
are not part of this closeout.

## Active pacing refinement — owner follow-up

- Root cause: default policy spent only 47.09% of a deterministic ten-minute supported-floor scenario
  Walking; sit lasted 8–15 s and sleep 30–60 s, with extra fallback idle and possible chained rests.
  The improved walk's 13.5 pt stride and Speed ceiling 2 limited maximum travel to 27 pt/s.
- Changes: shared five-second autonomous stationary budget; eight-second forced walking interval
  after the budget or a walking-intent autonomous landing; automatic jumps return to Walking.
  Sit/sleep ranges become 2–4.4 / 2–4.2 s to reserve entry/exit time. Rest/expression choice weights
  are reduced; critical-energy sleep now honors the existing cooldown. Explicit user pause, holding,
  disabled autonomy and flight/climb are preserved.
- Speed: shared Settings/Core range 0.5–4; missing or nonfinite preference defaults to 2. Finite saved
  values and preference keys are preserved. Current stride yields 27 pt/s by default, 54 pt/s at maximum
  at 96 pt, with animation and ground motion scaled together. No asset, anchor or timing metadata
  was changed; the owner-approved drawings remain byte-identical.
- Regression tests: new ActivePacingTests reproduced the original failures first, then passed the
  five-second limit for idle/sit/sleep/observe/stretch, ≥80% Walking time under the default policy,
  automatic-jump/landing recovery and 54 pt/s at Speed 4 with matching animation rate.
- Existing tests explicitly pin Speed 1 when testing the old 20 pt/s fixture; settings assertions
  reflect the authorized range/default. Passive-sleep timing tests sample inside the new brief sleep
  interval and wait for the next sleep state rather than assuming a fixed 25-second phase.
- Full test gate detected 48 issues in the existing V8 pixel QA (margin/seam assertions). A clean
  archive of HEAD before these edits reproduced the identical 48 issues in the same test. Evidence:
  `build/active-pacing-baseline-assets.log` and `build/active-pacing-baseline-path.txt`. No asset or
  assertion was weakened to hide them. This refinement does not claim a completely passing suite.
- Final verification: 314 Core tests (30 suites) passed, including three seeded ten-minute active
  pacing scenarios and critical-energy sleep cooldown; 34 Platform tests and 50 Rendering tests
  passed. Runtime ran 89 tests: 88 passed and the pre-existing V8 pixel-QA test failed with the
  same 48 issues reproduced from HEAD. Full `make test` therefore did not reach its UI phase;
  the separate unchanged Xcode UI run passed both tests, zero failures (19.308 s). Strict lint,
  Debug, Release and `git diff --check` passed; Xcode emitted its existing App Intents metadata
  notice, no Swift compiler warning. Logs: `build/active-pacing-core-final.log`,
  `build/active-pacing-tests-final.log`, `build/active-pacing-ui.log`,
  `build/active-pacing-lint.log`, `build/active-pacing-debug-final.log`,
  `build/active-pacing-release.log`. The full-package run before the final test-only correction
  also had a stale long-sleep assertion; the fresh complete Core run verifies its corrected
  activity-bounded interval without removing or skipping any test.
- Native UI tests exercised launch/settings/quit. Real desktop idle proportions and subjective
  speed were not measured manually; the timing/distance figures above are deterministic simulation
  results. No new animation-quality acceptance or performance benchmark is claimed.
- At pacing verification time: no PNG/manifest diff, dependency, permission change, commit, push, tag or merge. The subsequent owner closeout authorizes integration.

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

## Historical candidate decisions (superseded by owner closeout)

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
