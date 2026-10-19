# Animation Assets V4

Status: **Produced and integrated 2026-10-18 under explicit owner authorization; Owner visual/test closure accepted 2026-10-18; M8 Done by owner direction.**
V4 is the art batch name, **not manifest schemaVersion 4**. Runtime schema remains
[v1](animation-schema.md). Original walk source art is unchanged. The runtime manifest has additive V4 clips; schema v1 is unchanged.
Delivery details, provenance, checksums and previews: [V4 production record](../../assets/characters/cat/v4/README.md).

## Delivered revision 1

24 new frames: idle 6 @4 fps, jump-start 4 @26⅔ fps, jump 4 @12 fps, fall 6 @12 fps,
landing 4 @40 fps. Preparation and landing retain 0.15/0.10 s nominal durations; frame counts
in the approved brief below are recommendations. All five clips load without fallback; the
legacy walk clip and source files are preserved. No physics/tuning change was needed.
Actual preload is **10,616,832 bytes (10.125 MiB)**, within the approved ≤16 MiB V4 budget.
The ≤3 MiB original walk gate remains independent. Actual PNG tests enforce the shared baseline,
individual planted contacts within 1 source px and ≥8 px transparent border including soft alpha.
The full 361 package tests, UI launch/Quit, lint and Debug/Release builds passed.

The exporter uses one scale per clip and anatomical root registration, with an offline ankle/paw
correction for generator drift; no per-frame bbox centering. Original generated sheets are retained.
Per-frame/union bounds and opaque-body statistics are recorded in the production record.
Scale/identity comparison includes unchanged walk and every phase at 0.5/1/1.5 in both facings
on light/dark/checkerboard. The phase preview draws actual PetWorld snapshots on light/dark backgrounds;
the owner subsequently approved the delivered V4 visual result (“está aprovado”, 2026-10-18).
The owner subsequently reported all remaining M7/M8 tests complete and explicitly requested closure.
M8 is Done by owner acceptance; no per-point counts, instrumented readings or soak duration are
inferred from that report. See the [owner closeout](../planning/m7-m8-technical-review.md#owner-m7m8-closeout-2026-10-18).
Asset redistribution license D-08 remains a separate distribution decision.

## Approved production brief
Use [asset-format.md](asset-format.md) for file/alpha rules and the existing walk audit.

## Identity, dimensions and compatibility

Preserve the blue-grey coat, light chest/muzzle, amber eyes, pink inner ears, expressive tail,
soft top-left light and Cartoon 2.5D proportions. Use the existing walk as identity/size reference,
not a new character redesign. Source canvas 512×512 RGBA8 sRGB, right facing; mirror around anchor
for left. Keep displaySize 96×96 pt at scale 1. Anchor `(0.5, 0.074)` normalized bottom-left
corresponds to virtual foot baseline near image row 474 from top (±1 px). Do not move the body
registration to center the opaque bounding box independently per frame.

Grounded feet touch that baseline. Airborne poses lift/tuck paws **relative to the same virtual foot
reference**, never change anchor to follow the lifted pixels. No baked trajectory translation or
camera motion. Logical box remains M7's stable 48×60 pt; tail never changes contact. Sprite screen
bounds use stable walk visual guard. All V4 silhouettes must remain inside canvas with ≥8 px
transparent margin; document alpha bounding box per frame and union. Avoid body registration changes
at cuts: compare pelvis/chest/eye landmarks, allowing deliberate squash/tuck, no camera zoom.

| Requested name | Runtime clip ID | Compatibility contract |
|---|---|---|
| idle | `idle` | Revision 1 real clip; missing optional art still falls back |
| jump_start | `jump-start` | Underscore forbidden by current validator; no schema change |
| jump | `jump` | Prefer new clip; if absent use legacy `jump-air` when valid, else ordinary default fallback |
| fall | `fall` | Existing missing-clip fallback to walk remains safe |
| landing | `landing` | Prefer new clip; if absent use legacy `land`, else ordinary default fallback |
| walk | `walk` | Existing 8 frames / 9 fps / nominalSpeed 20 unchanged |

All new names/events already fit `^[a-z0-9][a-z0-9-]*$`. Actual clip frame lists/FPS/anchors/events
belong in character.json. Recommendations below are flexible, not counts embedded in code. Do not
rename legacy original folders or edit their PNG/GIF/atlas/README/source manifest. Revision 1 adds new clip
folders under the explicit production/integration authorization. The compatible manifest update
adds fallback aliases (`jump-air → jump`, `land → landing`) without cycles; do not add aliases
back in both directions. Normal CharacterDefinition resolution supports current walk-only packs.

## Per-clip delivery brief

Common to every row: right facing, mirrorable, fixed canvas/anchor/displaySize, alpha union inside
8 px margin, virtual foot reference stable. Per-frame alpha bbox is inspection metadata, not a
collision shape or new runtime field. No automatic `next` chains for physics-driven clips.

| Clip | Objective and start → end pose | Main / secondary motion | Recommended timing | Foot contact / bbox requirement | Optional presentation events | Start / end / transitions | Quality gates |
|---|---|---|---|---|---|---|---|
| `idle` | Alert neutral stand → identical neutral stand | Subtle breathing; blink/ear twitch and small tail sway, no root translation | 12 frames, 8 fps, loop (1.5 s), variable counts accepted | Grounded paws fixed baseline; union leaves tail/ears margin | `blink` only when eyes close; no footsteps or physical commands | Grounded Idle enters; simulation activity/safety exits to walk, preparation or fall | First/last cut seamless; no foot drift >1 px; one consistent cat, calm rather than frozen |
| `jump-start` | Neutral stand → compressed anticipation then extended push pose | Squash and leg push; ears/tail lag, chest preserves volume | 3 frames, 20 fps, once (0.15 s nominal) | Paws planted until final push reference; no upward root travel; bbox contains compression and extension | `takeoff` on last pose for inspection; its frame entry (nominal ~0.10 s) does NOT apply impulse | PreparingJump enters; simulation deadline 0.15 s cuts to jump even if clip length differs; support loss cuts to fall | Contact feels planted; last extension matches first jump at launch; marker offset documented, body timing never gates launch |
| `jump` | Extended takeoff → compact raised-paw pose | Fold legs and stretch torso modestly; tail trails with upward momentum | 4 frames, 12 fps, once then hold final frame (not `next`) | No physical foot contact; virtual anchor unchanged; lifted paws above baseline, torso/ears not clipped | Optional `airborne`; do not author a mandatory physical apex | Rising enters; physics apex cuts to fall, possibly before clip completes | No walking cycle in air; body stays registered; held pose plausible across variable flight durations |
| `fall` | Raised-paw apex pose → reaching down / balanced descent | Legs extend toward ground; tail/ears counterbalance | 6 frames, 12 fps, loop (0.5 s) | No contact until physics says so; paws may approach baseline, cannot shift virtual foot; full reach fits bbox | None required; optional `airborne` has no physics authority | Falling enters at vy crossing or surface loss; swept contact cuts to landing; recovery can interrupt | First fall frame matches jump endpoint/apex; loop has no pulsing scale; suitable for short Dock fall and long drop |
| `landing` | First paw contact → compressed impact → neutral stand | Absorb impact then settle; tail/chest/ears follow through | 3 frames, 30 fps, once (0.10 s nominal), hold final | First grounded contact at baseline; grounded paws fixed through squash; no below-baseline shelf penetration | `contact` on frame 0; optional `settled` on final | Physics landed enters immediately; 0.10 s simulation hold ends in saved Idle/Walking; support loss interrupts to fall | No pop/slide at impact, return pose matches idle and walk; impact visible but does not move logical contact |

At 60 Hz preparation/landing defaults are 9/6 ticks. Renderer may show fewer art frames than authored
on a busy display; physical events still happen exactly once. Clips of different length can be
cut/held at simulation phase boundaries. Quality assessment must include minimum-height jumps and
Dock falls shorter than a full loop, not just isolated GIF playback. For a fully absent clip, M7/M8
hold a safe default frame during flight/preparation/landing/idle; walking remains animated.

## Production and integration pipeline

1. **Produce** new original frames in separate V4 clip folders, preserve provenance/tool/version and
   owner art license decision D-08. Revision 1 sources/prompts are retained; D-08 remains open before distribution.
2. **Transparency QA:** PNG RGBA8, alpha 0 background, opaque body 255, soft silhouette only;
   reject halo/matte, floating islands ≥ hit threshold, clipped tail/ears. View on light/dark/checkerboard.
   Existing translucent walk is an unchanged baseline, not silently corrected.
3. **Dimension QA:** every cell 512×512, same color space; ≥8 px transparent margin; record per-frame
   alpha bbox and union. Reject registration drift, reject per-frame auto-crops.
4. **Identity QA:** contact sheet against current walk at same displaySize, compare coat/eyes/muzzle,
   proportions/lighting, frontal thickness and tail volume; owner approves consistent identity.
5. **Alignment QA:** ground line row 474±1 px, anchor overlay and stable torso landmarks; fixed size
   preview in both facings and scale 0.5/1/1.5. Grounded foot jitter ≤1 source px (≈0.19 pt at 96 pt).
6. **Atlas generation (optional):** new file, row-major equal cells, untrimmed and unrotated, per-clip
   columns/rows recorded; compare every atlas tile pixel-for-pixel with delivered PNG. Prefer runtime
   individual PNGs initially; atlas is preview/delivery convenience, no new packing dependency.
7. **Manifest authoring:** authorized additive v1 character.json edit; explicit frame array,
   recommended/approved FPS or per-frame durations, common anchor, playback/fallbacks, optional visual
   events. Validate regex, next/fallback cycles and all referenced files; no physics tuning in frame data.
8. **Preview:** existing DEBUG AnimationPreviewController for each clip, ground ticks, light/dark,
   mirroring and scale; pair adjacent clips and actual simulation jumps. Revision 1 includes offline previews; native test closure was accepted by subsequent owner report.
9. **Integrate:** CharacterLoader/FrameImageStore existing async decode/downsample; preload new clips,
   measure bytes; apply only simulation-selected AnimationFrameRef. No decode/atlas creation per frame.
10. **Test/review:** validator/loader bad-manifest/missing-frame/missing-clip/fallback/variable-count
    tests, PetLayer anchor/mask tests and identical trajectories with different art. Owner approves
    transition recording and absence of foot sliding/scale pops, then record pack revision/checksums,
    environment and performance. A new build/measurement result is required, not assumed from M6.

The recommended 28 new frames plus 8 walk frames occupy about 11.4 MiB at 288² RGBA before cache/
mask overhead. This exceeds the **MVP** 10 MB image target and M4 walk-only 3 MiB criterion; it is
not evidence that V4 fits. M8 V4 decoded-frame budget ≤16 MiB and total process footprint
≤100 MB were approved as design limits on 2026-10-18; revision 1 decoded frames are measured above; runtime measurements are in [performance.md](performance.md). If exceeded, reduce decoded size to match actual
scale or revise frame counts with artistic approval; do not add lazy loading speculatively (M14).
Atlas backing storage must not be counted once per cropped cell or hide actual retained bytes.

## Schema evolution assessment

No schema change is necessary for these five clips, events, FPS, once/loop/hold, sheets or anchors.
No decoder or validator change was needed; revision 1 adds clips to character.json. If future per-character
physics dimensions are needed, propose optional `physics` values with defaults (additive v1,
older readers ignore; test old pack unchanged) in a separate ADR. If clip IDs/event meanings are
renamed as serialized data, use schema v2 with a tested v1→v2 migrator; current loader supports
only v1, so do not emit a v2 pack now. The D8 change is an engine-consumption rule, not a frame
JSON structure change: there is no implemented v1 takeoff-to-impulse consumer to migrate.
