# M7/M8 Technical Planning Review

Date: 2026-10-18. Status: **M7/M8 Done by explicit owner acceptance.** The closeout below
records the then-current M9 deferral; the owner subsequently reauthorized M9 under its
[implementation plan](m9-implementation.md).
Baseline: `develop`, HEAD `2f7f33f6bb2c66462cc95ed6cfb80d178670b5e4` (Dock-side recovery fix),
preceded by M6 merge `6bb5ca4`. Working tree was clean before this documentation change.

## Owner M7/M8 closeout (2026-10-18)

The owner instructed: “cancela o M9 por enquanto, vamos finalizar o M7/M8 completamente antes.
Se tiver faltando apenas testes pode finalizar, pois eu testei tudo deles.”

No remaining M7/M8 product-code delivery was found: T7.1–T7.8 physics/recovery/runtime and
T8.1–T8.6 jumps/presentation/V4 are implemented. The outstanding items were validation/evidence
and owner acceptance. **M7 and M8 are Done by this explicit owner-directed closure**, combining
existing automated/measurement evidence, visual approval and the owner's report of completing
all remaining tests. At this historical checkpoint M9 was deferred and no M9 product code existed;
the owner later reauthorized it. Current delivery and verification limits are in
[m9-implementation.md](m9-implementation.md#execution-record-2026-10-18).

Evidence boundaries are preserved: this report supplies no per-point interaction count, external
hardware details, new numeric energy/frame-pacing/wakeup readings, measured two-hour duration or
leak-growth report. Those fields are **not independently recorded**, not marked as newly measured
passes. Existing paused CPU variability (0.08–0.63%, including a sample above target) remains in
performance.md; owner acceptance closes the milestone without asserting that every quantitative
criterion was independently demonstrated. This instruction supersedes the earlier pending
acceptance statements in the chronological records below.

The asset redistribution license D-08, historical M5/M6 evidence/CI decisions and release process
remain separate project/distribution matters; no license was chosen, release/tag created or commit
made. M9 must not resume without a new owner instruction.

Final closeout checks: 361 package tests passed (Core 240, Runtime 52, Rendering 44, Platform 25),
strict lint and Debug/Release builds passed with compiler warnings treated as errors. The latest
UI rerun stopped before its test body with an Automation Mode timeout; the earlier UI success and
owner test confirmation are retained. No compiler/test assertion failure was hidden or weakened.
Original walk asset hashes and all 41 production checksums remain valid; no M9 product files added.

## Approval and implementation continuation

Owner approved the design (“aprovado”), accepting ADRs 0016–0018, retaining Core Animation and
approving the proposed V4 budget subject to measurement. After isolated T7.1, the owner explicitly
authorized continuous execution of all tasks without per-task stops. This permits M7/M8 runtime
engineering before predecessor manual sign-off; it does not accept missing M5/M6 evidence or
waive release/visual/performance gates. M9 was still architecture only at this historical checkpoint. The first engineering batch used walk-only fallbacks; V4 continuation follows below.

Implemented T7.1–T7.7 physics/world/demand/recovery, T7.8 presentation fallback engineering and
T8.1–T8.4 solver/execution/target/animation integration. T8.5 initially had synthetic loader coverage;
subsequent production integration is recorded below. T8.6 has automated regression and partial performance evidence. Both
milestones are **In review**, not Done. Per-task evidence: [task breakdown](task-breakdown.md#execution-evidence-2026-10-18).

### Subsequent owner test confirmation

The owner subsequently reported that the tests passed and authorized continuing. This records
owner confirmation separately from the automated results below. No new measurements, V4 files or
specific real-time soak results accompanied that report; existing evidence remains preserved.
The next workstream must distinguish V4 production/integration from M9 behavior implementation,
which have different scopes and design prerequisites.

### Verification of the first engineering batch

- `make test`: **358 package tests** (Core 240, Runtime 49, Rendering 44, Platform 25), plus the
  app/UI launch/status-item/Quit test: **TEST SUCCEEDED**. Real idle loops at 15/30 Hz and held-idle
  stop/wake, both Dock-side falls, pause/resume, launch cancellation and variable art are covered.
- `make lint` and Debug/Release builds passed with warnings treated as errors. Only the known Xcode
  AppIntents metadata extraction warning remains; no Swift compiler warning. `git diff --check` clean.
- Independent read-only review found Idle wake liveness, stale launch environment and epsilon tie
  order. All reproduced with failing tests and corrected. Follow-up found unrelated reprojection
  rounding; a failing test now preserves exact body/launch continuity, and unchanged supports do not reproject.
- Optimized Core stress harness: 432,000 fixed steps (two **simulated** hours), 2,384 launches,
  2,385 contacts, zero recoveries/invalid bodies. This is not a two-hour real-time application soak.
  Costs and Release measurement limits are in [performance.md](../specifications/performance.md).
  Walking measured 0.83% CPU, hidden 0.00%; paused varied 0.08–0.63%, so its complete energy gate
  remains open rather than silently passing the 0.2% limit.

One intermediate UI attempt failed while XCTest was activating external InstantView; subsequent
full UI runs passed without weakening/editing the test. Native UI inspection through Computer Use
timed out, so it supplies no visual evidence. Manual flight/landing click-through, typing/VoiceOver,
Dock alignment, complete environment/hardware matrix, frame pacing/energy/wakeups and real-time
soak remain open. Existing owner M5/M6 evidence is not silently passed by this revision.

In that first batch no original asset, manifest/schema, preferences key or dependency changed. No M9 runtime,
commit/push/PR/tag/release. The working tree remains on develop over the baseline below.

## V4 production continuation

Owner explicitly selected “M8: produção e integração das animações V4” and renewed continuous
execution authorization. Revision 1 produces/integrates 24 frames across idle, jump-start, jump,
fall and landing with additive schema v1 clips/legacy aliases; original walk sources and walk
metadata are unchanged. No engine/tuning, preference, dependency or M9 implementation change.
Generated sheets, full prompts/tool provenance, deterministic offline exporter, final hashes,
per-frame QA and light/dark/both-facing previews are in the [production record](../../assets/characters/cat/v4/README.md).

All **361 package tests** (Core 240, Runtime 52, Rendering 44, Platform 25), UI launch/Quit, lint
and Debug/Release builds passed. Earlier Automation Mode timeout was resolved by an unchanged
retry. Independent reviewer found planted-paw drift and faint transparent-border overflow;
new assertions failed before registration/margin correction and now pass. Actual-art trajectory
comparison preserves exact state/position/velocity against the walk-only baseline. Decoded images:
**10,616,832 bytes / 10.125 MiB**, below 16 MiB; original walk ≤3 MiB gate retained.
Full-app same-binary resource control: walk-only 1.80% CPU / 23 MB, V4 repeat 1.85% / 33 MB;
runtime harness walk/animated Idle/repeated jump: 1.28/0.63/1.23%. Fresh export reproduced all
24 PNGs byte-for-byte. See performance.md for protocol and limits.

The owner subsequently approved the delivered V4 visual result (“está aprovado”, 2026-10-18).
This closes artistic review of the delivered result. The PetWorld preview remains offline evidence;
no additional native test results accompanied approval. Desktop scale/Dock calibration, complete non-interference/hardware matrix,
real-time soak and unresolved energy gates remain open. D-08 asset redistribution license remains
required before public distribution. M7/M8 stay In review; no commit/push/PR/tag/release.

## Historical planning snapshot

Everything below records the pre-implementation inspection and planning verification. Its current/
proposed inventory and “no code changed” statements refer to that snapshot; the continuation above
and owning architecture/task documents describe the implemented working tree.

## Brief and boundaries

Plan M7 physics first, M8 jumps second, Animation Assets V4 production separately, and only the
contracts for M9. Preserve desktop non-interference, energy savings, existing walk art and recovery.
Documentation is English; owner discussion is Portuguese. No Swift/test/manifest/art edits,
dependencies, commits, pushes, tags or releases are part of this change. All future behavior below
is **[validate]**, not a claim that physics or jumps exist today.

Owning documents:

- [Physics Engine](../architecture/physics-engine.md): M7 model, integration, collisions and recovery.
- [Jump System](../architecture/jump-system.md): M8 solver, transitions and interruptions.
- [Assets V4](../specifications/animation-assets-v4.md): art delivery and schema compatibility.
- [Behavior Engine](../architecture/behavior-engine.md): M9 boundaries and weighted selection.
- [Task Breakdown](task-breakdown.md): task plans and exact existing/proposed file map.
- [Acceptance Criteria](acceptance-criteria.md): testable M7/M8 gates.
- [MVP closeout](m5-m6-closeout.md): remaining evidence and release decisions.
- [Testing](../development/testing.md#m7m8-regression-matrix): regression causes, prevention and recovery.

## Inspection record

Read root AGENTS/CLAUDE/CODEX, all Cursor rules, README, architecture overview/modules/data flow,
pet/physics/animation/behavior/macOS integration, surface/coordinate/state/asset/schema/performance
specs, testing/conventions/setup, existing ADRs 0001–0015 and the milestone/task/acceptance/risk/roadmap
plans. Inspected the actual Core world/model/animation/surfaces/accumulator, Runtime/frame driver,
Dock/screen/full-screen adapters, renderer/loader and their relevant tests. No knowledge graph was
present; no graph rebuild or installation was needed. File paths in the inventory below exist at HEAD.

## Current implementation inventory

All paths below are relative to `Packages/PetScapeKit/`. Core values are nonisolated/Sendable;
their actual owner mutates them synchronously on MainActor. Platform, Rendering and Runtime use
package default MainActor isolation. There is no background simulation or independent scheduler.

| Real file(s) | Responsibility / dependencies | Mutable state and owner | Contract / extension point |
|---|---|---|---|
| `Sources/PetScapeCore/Pets/Pet.swift` | Pet identity, position, attachment, facing, state, animation, scale; Core AnimationController | Position is `CGPoint`, no velocity today; only PetWorld changes pet fields | Keep `position` as canonical foot contact; add velocity here, no parallel body position |
| `Sources/PetScapeCore/Pets/SurfaceAttachment.swift` | SurfaceID + normalized parameter | Pet-owned value | Reuse as sole contact reference; nil must also support airborne |
| `Sources/PetScapeCore/World/PetWorld.swift` | Spawn, environment, walk, transitions, recovery, snapshots; SurfaceMap, RandomSource, animation | Ordered `[Pet]`, screens, surfaces, Double time, random source, reusable animation buffer | `apply(_:)`, `step(dt:into:)`, `writeSnapshot(into:)`; private walk/setPosition/place/reproject/resettle are current writers in one owner |
| `Sources/PetScapeCore/Behavior/PetState.swift`, `BehaviorTuning.swift` | Flat spawning/walking/turning/recovering machine; nominal-speed motion, 0.15 s hold | Pet stateElapsed, injected tuning | Refine into grounded/airborne cases in this machine; no second FSM |
| `Sources/PetScapeCore/Time/FixedStepAccumulator.swift` | Display timestamps → steps | lastTimestamp, accumulated; owned by PetRuntime | 1/60 s, max 5, 0.25 s clamp, whole backlog discarded; reset; interpolation currently unused |
| `Sources/PetScapeCore/World/WorldInput.swift`, `WorldEvent.swift`, `RenderSnapshot.swift` | Environment commands, typed output, render data | Snapshot reusable buffer in runtime | Screens/surfaces only today; isVisible = attachment != nil, isAnimating = any visible pet; both require M7 refinement |
| `Sources/PetScapeCore/Surfaces/Surface.swift`, `SurfaceID.swift`, `SurfaceKind.swift`, `SurfaceMap.swift` | Horizontal segments, identity, diff/lookup/spawn/highest-below | SurfaceMap value in world, stable insertion order | No swept query yet; no orientation/source fields. Existing `walkableRange(margin:)` has midpoint fallback for narrow surfaces |
| `Sources/PetScapeCore/Surfaces/DockGeometryEstimator.swift` | Pure visibleFrame heuristic, offset clamping, walkway | None (functions); input descriptors | Keep estimate and stable IDs; Dock width remains full-screen by ADR-0009 |
| `Sources/PetScapePlatform/Dock/DockSurfaceProvider.swift` | Estimate + preferred walkway + host screen | screens, estimate, surface, offset on MainActor | `surfaces` currently contains at most ONE surface. Do not assume floor coexists with Dock |
| `Sources/PetScapePlatform/Screens/ScreenProvider.swift` | NSScreen → ScreenDescriptor; public change notification | Observer lifecycle on MainActor | `currentScreens`, `start(onChange:)`, `stop`; no injected screen reader yet |
| `Sources/PetScapeRuntime/Overlay/OverlayCoordinator.swift` | Environment/run-state/overlay/driver/pass-through composition | converter, screen/host IDs, frameDriver, needsFrames; MainActor | Callbacks apply synchronously between steps; resume refreshes screens; new frame-demand policy must honor RunStatus |
| `Sources/PetScapeRuntime/PetRuntime/PetRuntime.swift` | Owns PetWorld/accumulator/renderer/snapshot/hit tester, preferences | Sole MainActor simulation owner | frame → N world steps → renderNow → mask. `hasPendingPlacement` fixes 2f7f33f; preserve its liveness invariant |
| `Sources/PetScapeRuntime/FrameDriver/FrameDriver.swift`, `DisplayLinkFrameDriver.swift` | CADisplayLink timestamps from overlay NSView, .main/.common | link lifecycle, weak proxy, fps on MainActor | pause/invalidate; 60 preferred, minimum half; no second clock needed |
| `Sources/PetScapeRuntime/RunState/RunStateController.swift`, `Sources/PetScapeCore/RunState/RunState.swift` | User intent × system reasons → independent visibility and frame permission | intent/reasons/status in controller | Reuse paused/hidden/suspended; recovery is not a new RunState |
| `Sources/PetScapePlatform/SystemEvents/SystemEventsMonitor.swift`, `FullScreenSpaceDetector.swift` | Sleep/lock/session/display and two-read Dock-window Space rule | Observer tokens, cancellation Task, latest Space decision; MainActor | No window titles/contents; ~0.4 s launch exposure known; do not alter as part of physics |
| `Sources/PetScapeCore/Animation/AnimationController.swift`, `AnimationPlayer.swift`, `AnimationEvent.swift`, `AnimationClip.swift` | Time-based variable-frame playback, priority, fallbacks, variants, next chains | Pet-owned controller/player elapsed/frame/rate | Frame events are strings wrapped in typed AnimationEvent; no existing takeoff consumer; max 8 next hops, 16 cycles |
| `Sources/PetScapeCore/Characters/CharacterManifest.swift`, `ManifestValidator.swift`, `CharacterDefinition.swift` | Schema v1 decode, validation, immutable resolved clips/fallbacks | Definition value, resolver tables | Names allow lowercase/digits/hyphens, NOT underscores. No physics geometry field. Personality DTO exists, no live needs |
| `Sources/PetScapeRuntime/Characters/CharacterLoader.swift`, `LoadedCharacter.swift` | Decode/validate/preload/revalidate, fallback/placeholder | MainActor store/result assembly; file read off-main | Async loader always returns usable result; invalid optional clips dropped; no schema migration implementation yet |
| `Sources/PetScapeRendering/Images/FrameImageStore.swift`, `ImageDecoder.swift`, `HitMask.swift` | Cache/downsample/sheet slicing + mask creation | Store MainActor; immutable decode outputs off-main | FrameImageStore target size, preload, eviction/accounting; masks use delivered alpha |
| `Sources/PetScapeRendering/Layers/PetRenderer.swift`, `PetLayer.swift` | Snapshot → CALayer, global → overlay via CoordinateConverter | Layer/cache state only, MainActor | bounds = displaySize × scale; disable implicit actions; no trajectory/timing ownership |
| `Sources/PetScapeRendering/HitTesting/PetHitTester.swift`, `Sources/PetScapeRuntime/Passthrough/MousePassthroughController.swift` | Same snapshot/mask as image; interactive only over pet | Snapshot/mask cache and pointer mode, MainActor | Keep render/mask state atomic; never derive contact shape from hit masks |
| `Tests/PetScapeCoreTests/World/PetWorldTests.swift`, `Tests/PetScapeRuntimeTests/PetRuntime/PetRuntimeTests.swift` | Walk/resettle/run-state integration | Explicit step time; fake frame driver | Existing left/right regression is parameterized; runtime Harness still uses real NSScreen (not fully environment-independent) |

App composition is in the real `PetScape/App/AppContainer.swift`; no domain code belongs there.
The runtime already owns the necessary clocks and injection seams. M7 adds small Core systems,
not modules or infrastructure.

## D1–D10 compatibility assessment

“Compatible” means compatible with inspected architecture, **not validated by new runtime tests**.

| Direction | Assessment | Evidence / minimum adaptation | Record |
|---|---|---|---|
| D1 custom kinematics | Compatible | ADR-0005 already specifies it; no Physics directory implementation yet | ADR-0016 |
| D2 one position owner | Compatible with adaptations | PetWorld owns Pet.position today; move walk displacement to pure stepper, apply result only in world; runtime commands recovery through world | ADR-0016 |
| D3 fixed step without permanent activity | Compatible with adaptations | Reuse accumulator/driver; add physical/timed-work demand independent of visibility and reset on demand stop/driver replacement | ADR-0016 |
| D4 decoupled rendering principle | Compatible | Snapshot-only CALayer renderer already does this | ADR-0015, ADR-0016 |
| D4 literal SpriteKit responsibility | **Incompatible; Blocked for owner review** | ADR-0015 superseded SpriteKit after measured PoC costs; Makefile bans imports. Smallest correction: interpret D1/D4 renderer references as Core Animation, preserving all decoupling. No migration proposed | ADR-0016 blocked clause |
| D5 swept horizontal contact | Compatible with adaptations | Surface is horizontal already; swept query absent; compute x at crossing, stable ties, no allocation | ADR-0016 |
| D6 foot contact + logical dimensions | Compatible with adaptations | Pet.position is foot anchor; edgeMargin currently depends on current clip and visual tail; introduce logical geometry + stable visual screen guard, no schema change | ADR-0016 |
| D7 separate locomotion/activity/runtime | Compatible with adaptations | Refine existing PetState; RunState remains independent; M8 stores return intent rather than duplicate position/state machine | ADR-0017 |
| D8 animation follows simulation | Compatible with adaptations | Runtime has no takeoff implementation, but old specs/T8.4/AC-M8-02 say frame applies impulse. Replace planned causal direction explicitly; preserve history | ADR-0017 |
| D9 reuse recovery | Compatible with adaptations | resettle/place and hasPendingPlacement already exist; physical fall replaces ordinary lost-surface resettle, exceptional safe placement remains in same pipeline | ADR-0016 |
| D10 HSM + simple weighted selection | Compatible with adaptations | ADR-0006/behavior docs currently prescribe utility/top-k scoring; narrow future selection, keep injected RandomSource; no M9 code | ADR-0018 |

## Documentation divergences and resolutions

- Root AGENTS current-phase paragraph predates the milestone table: M4 is Done, M6 merged, UI
  launch test has passed. Preserve instructions; use dated milestone evidence and HEAD for facts.
- Architecture overview's “pending PoC” banner, `pet-engine`'s KinematicBody/dictionary/registry,
  surface spec's rich queries/fields, and old data-flow's queue diagram describe target design,
  not existing implementations. Updated topic documents label current versus proposed explicitly.
- No actual KinematicBody, MotionController, ScreenEdgeSurfaceProvider, JumpSolver, Needs or
  ActivitySelector exists. Paths for these in task plans are marked **Create**, never baseline facts.
- v1 manifest supports sheets and arbitrary frame counts now; a version bump is unnecessary for
  V4 clip additions. `jump_start` maps to `jump-start`; `jump` and `landing` are valid new semantic
  requests, with legacy `jump-air`/`land` handled by request resolution, not file renaming.
- Original T7.5 proposed random drops at Dock ends. Full-width Dock geometry has no known shelf
  ends; keep turn behavior at screen bounds. T7.5 is refined explicitly, random selection deferred
  to M9 and any finite-surface walk-off until supported geometry exists.
- Several existing world tests use `step(dt: 0.5)`. Tightening the fixed-step contract requires
  equivalent assertions after 30 × 1/60 calls, plus rejection tests; no coverage removal or weakening.
- Resolution owner acceptance and missing log evidence are distinct. External-display and full
  AC-14 evidence remain absent; [closeout](m5-m6-closeout.md) does not mark them passed.

## Approval boundary and order

Approve ADR-0016–0018 and specifications, including retaining Core Animation, simulation-timed
launch/landing, stable clip names, timestep API tightening, and floor/return semantics. These are
proposed details under D1–D10, not evidence of completed milestones. At this original planning checkpoint, M5/M6 remained In review and M7/M8/M9 implementation had not started; later owner closeouts and execution are recorded below and in the milestone/task evidence.

First implementation: **T7.1**, bounded physics values/stepper with deterministic tests, after
explicit owner instruction and predecessor gate in [implementation-plan.md](implementation-plan.md).
Then T7.2 → T7.3 → T7.4 → T7.5 → T7.6 → T7.7 → T7.8 → M7 owner gate;
M8 T8.1 → T8.2 → T8.3 → T8.4 → T8.5 → T8.6. V4 production can proceed independently
when separately authorized; M7 requires no new art. M9 was still a later planning/implementation request at this historical checkpoint.


## Final consistency review and verification

This checks the **planning**, not future feature correctness:

| Review item | Planning result / evidence |
|---|---|
| Existing architecture and one position owner | Pet.position/PetWorld retained; physics candidates have no independent stored body |
| Walking cannot double-integrate | T7.4 removes old displacement; T7.5 preserves measured walk reference and turns |
| Existing frame loop and energy | Same CADisplayLink/accumulator, explicit physical/timed/animation demand; 30 fps real Idle, held Idle stops; no new scheduler |
| Recovery and Dock-side correction | Existing pipeline retained; left/right 2f7f33f liveness test strengthened for physical falls |
| Fixed timestep and abnormal delay | Existing 5-step/0.25 s/remainder/reset policy; world dt contract tightened with test migration |
| M7 without art and M8 reuse | Default held fall/landing pose; JumpSolver replays same PhysicsStepper/contact conventions |
| Animation never controls trajectory | Timers/velocity/contact produce phases; markers are optional visual observations |
| M9 not prematurely implemented | Only HSM/weighted/action/environment contracts documented; no source/test/manifest changes |
| ADR history and owner decisions | New IDs 0016–0018 Proposed; original decisions/status preserved, literal D4 explicitly Blocked |
| Dependencies/tasks/acceptance | T7.1–8, T8.1–6 and AC-M7-01–15 / AC-M8-01–18 mapped; manual/measurement checks separate |
| Code/doc divergences | Current inventory vs proposed types/queries/queue clearly labelled; stale schema takeoff prose identified without schema edits |
| Unresolved risks and review | D-15 planning/renderer/API details, D-16 V4 budget, D-17 MVP closeout; no implicit acceptance |

Fresh baseline verification on 2026-10-18: `make test-core` passed **283 tests** (Core 174,
Runtime 40, Rendering 44, Platform 25), `make lint` passed, `make build` succeeded with no
compiler warnings. These checks ran on the unchanged M6 source; they do not validate M7/M8.
`make test` UI suite was **not rerun** for this documentation-only change. Historical owner UI
success is retained separately. No new visual/platform/asset/performance measurement was made.
Relative Markdown links/heading anchors and `git diff --check` were checked; all changed tracked
and new files are Markdown. No Swift, tests, manifest/schema, original assets or dependencies were
modified. No commit, push, PR, tag or implementation action occurred.

## Document change inventory

Owning-topic specifications are updated in place; the new documents below cover distinct missing
topics (jump system, V4 delivery, diagnosis, separate MVP closeout and new ADRs).

| Document | Change |
|---|---|
| [README.md](../../README.md) | Updated |
| [docs/README.md](../README.md) | Updated |
| [docs/architecture/animation-system.md](../architecture/animation-system.md) | Updated |
| [docs/architecture/behavior-engine.md](../architecture/behavior-engine.md) | Updated |
| [docs/architecture/data-flow.md](../architecture/data-flow.md) | Updated |
| [docs/architecture/jump-system.md](../architecture/jump-system.md) | Created |
| [docs/architecture/modules.md](../architecture/modules.md) | Updated |
| [docs/architecture/overview.md](../architecture/overview.md) | Updated |
| [docs/architecture/pet-engine.md](../architecture/pet-engine.md) | Updated |
| [docs/architecture/physics-engine.md](../architecture/physics-engine.md) | Updated |
| [docs/decisions/0016-physics-state-and-recovery.md](../decisions/0016-physics-state-and-recovery.md) | Created |
| [docs/decisions/0017-simulation-driven-jumps.md](../decisions/0017-simulation-driven-jumps.md) | Created |
| [docs/decisions/0018-simple-weighted-behaviors.md](../decisions/0018-simple-weighted-behaviors.md) | Created |
| [docs/decisions/README.md](../decisions/README.md) | Updated |
| [docs/development/testing.md](../development/testing.md) | Updated |
| [docs/planning/acceptance-criteria.md](acceptance-criteria.md) | Updated |
| [docs/planning/implementation-plan.md](implementation-plan.md) | Updated |
| [docs/planning/m5-m6-closeout.md](m5-m6-closeout.md) | Created |
| [docs/planning/m7-m8-technical-review.md](m7-m8-technical-review.md) | Created |
| [docs/planning/milestones.md](milestones.md) | Updated |
| [docs/planning/risks.md](risks.md) | Updated |
| [docs/planning/task-breakdown.md](task-breakdown.md) | Updated |
| [docs/product/roadmap.md](../product/roadmap.md) | Updated |
| [docs/specifications/animation-assets-v4.md](../specifications/animation-assets-v4.md) | Created |
| [docs/specifications/state-machines.md](../specifications/state-machines.md) | Updated |
| [docs/specifications/surface-detection.md](../specifications/surface-detection.md) | Updated |
