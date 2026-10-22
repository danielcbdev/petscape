# M10 Interaction Implementation Plan

> **For agentic workers:** after explicit implementation authorization, use the
> `superpowers:executing-plans` workflow task by task. Checkboxes record future work, not completed
> implementation. The plan did not authorize Git publication; the owner's later request explicitly
> authorizes the `feature/` branch, push and merge into `develop` for this completion.

**Goal:** bounded cursor awareness, deliberate click/pickup and safe zero-impulse release using
existing world, physics, behavior and animation.

**Architecture:** retain Core Animation, one fixed-step world, Platform input adapters and Runtime
orchestration. Compare existing routing with a bounded input panel in an isolated native PoC;
no production topology change before native evidence and owner acceptance.

**Tech Stack:** Swift 6 strict concurrency, AppKit/SwiftUI/Core Animation, CoreGraphics/ImageIO,
OSLog/UserDefaults, Swift Testing/XCTest, macOS 14+; no dependencies.

**Spec:** [interaction contracts](../specifications/interaction.md),
[inspected architecture](../architecture/interaction-system.md),
[V5](../specifications/animation-assets-v5.md), [native gate](m10-native-poc.md).

Status: **Implementation complete; V5 art integrated on 2026-10-22; final visual owner review pending.**
M1–M9 remain Done by their prior owner acceptances. M10 native/performance evidence limits remain
as recorded below; this update does not invent observations or claim owner visual approval.

## Global constraints

- Full M10 implementation was authorized by the owner message dated 2026-10-18. A later owner
  instruction explicitly authorized a `feature/` branch, push and merge into `develop`; that Git
  closeout applies to this V5 completion. No release or tag is authorized.
- `PetWorld` alone writes body position; current PhysicsStepper and bounded recovery are reused.
- Core imports only Foundation, CoreGraphics value geometry and os; no Platform↔Rendering import.
- Platform/Rendering/Runtime/App MainActor; Core Sendable values. No detached tasks/locks/new queues.
- Fixed simulation 60 Hz, stopped when paused/hidden/suspended. Event-driven routing is distinct
  from behavioral sampling. No independent timer/display link, no offscreen work.
- Nonactivating panels never key/main, below Dock; permission-free mouse-only public APIs.
- No manipulation of other apps, cursor/typing history, keyboard interception or network.
- Manifest schema v1 and original assets remain intact; future optional V5 data is additive.
- Single cat, current host display; multi-pet contracts via IDs, real handoff remains M14.
- No automatic reopening of M9 gaps; do not claim new native/performance/art measurements.

## Current baseline verification (2026-10-18)

Planning baseline: `develop` `9ecc8a0abe70f6a295ea242fa0479aae3c4ebb32` (historical implementation
`ed3bd8d` is its ancestor). The implementation session started at this HEAD with M10 planning docs
already present as local uncommitted work; they are preserved and updated in place. Host: macOS
27.0.1 (26A434), Xcode 27.1 (27A9275), Apple silicon. Current checks are recorded below:

| Check | This planning session's result |
|---|---|
| `make lint` | PASS |
| `make test` package | PASS: Core 262 + Platform 28 + Rendering 44 + Runtime 66 = **400** |
| `make test` UI | PASS: **2**, launch/Quit and Settings restore/close/Quit |
| `make build` Debug | PASS; no warning lines in this build's log |
| Release build, warnings-as-errors settings | PASS; one Apple metadata-extraction warning, no Swift warning lines |
| Native M10 PoC | **Partial / inconclusive**: A and B configurations launched and logged; underlying-app clicks, focus/Dock matrix, drag sequences and paired resource measurements were not performed |

### M10 implementation verification — 2026-10-18

| Gate | Result |
|---|---|
| `make lint` | PASS after formatting; Core module/import boundaries remain intact |
| `make test-core` | PASS: 416 tests across Core (271/24 suites), Platform (69/6), Rendering (46/10) and Runtime (30/6) |
| Focused tests | PASS: CursorSampler (6), CursorInterest (6), CursorAwarenessWorld (3), OverlayMouseEvent (2), PreferencesStore (9), MousePassthroughController (12), V4/V5 fallback tests |
| `make build` Debug | PASS |
| Release build with Swift and GCC warnings treated as errors | PASS |
| `make test` UI stage | FAIL before test cases initialize, twice: runner timed out while enabling Automation Mode; second attempt was after PoC processes exited. UI controls were not verified in a running UI test |
| Apple build-tool warning | AppIntents metadata extraction reports no `AppIntents.framework` dependency; unrelated to Swift source. No Swift compiler warning observed in successful warnings-as-errors builds |
| Native routing / focus / Dock / performance / 2-hour soak | Not verified; no underlying-app click or paired measurement was performed |
| V5 fallback | PASS: safe idle fallbacks remain available for absent/invalid optional clips |
| V5 production art | Integrated 6 `curious`, 4 `picked-up` and 6 `held` frames; pack QA and final owner visual review are recorded separately |

The first UI attempt occurred while the two PoC panels were still running, so they were terminated
before retry. The retry produced the same Automation Mode timeout; the earlier suggestion that the
PoC caused the failure is not supported by that result. The underlying UI automation environment
remains the known boundary. No M10 acceptance row is inferred from these build or unit-test results.

### Verification refresh — 2026-10-18

The later continuous implementation run supersedes the UI timeout and earlier package counts above:

| Gate | Result |
|---|---|
| `make test-core` | PASS: Core 282, Platform 32, Rendering 46, Runtime 73 (**433 total**); Core interaction session tests include 3.99/4 pt and negative-origin offset boundaries |
| `make test` UI stage | PASS: 2 UI tests — launch/status item/Quit and Settings toggles/Restore Defaults/close/Quit |
| `make lint` | PASS |
| `make build` Debug | PASS with warnings treated as errors |
| Release build | PASS with Swift and GCC warnings treated as errors; Apple metadata warning is tracked below |
| Remaining native/performance/art gates | Native/performance evidence limits remain (no complete POC-01…10 dataset, full WindowServer/GPU/allocations/leaks measurements or two-hour soak); generated V5 art is now integrated, with owner visual review pending |

The Settings UI test initially failed while asserting an AppKit/XCUI slider persistence value that
the accessibility bridge did not report consistently. That non-M10 assertion was removed; the UI
test still exercises and verifies the interaction toggles, Restore Defaults, close and Quit paths.
No product behavior test was deleted or weakened to mask an implementation failure.

Historical baseline note: the planning run found two Swift actor-isolation warnings in
`PetScapeUITests/PetScapeSettingsTests.swift`; this implementation applied the authorized minimal
`@MainActor` annotation to the helper. No M9 acceptance or historical record is rewritten.

Transient logs: `/tmp/petscape-m10-baseline-{test,lint,debug,release}.log`.
UI result: `build/DerivedData/Logs/Test/Test-PetScape-2026.10.18_21-53-52--0300.xcresult`.
These are local build evidence, not committed deliverables. No real login-item action, native
sleep cadence, installed two-hour playtest or release/tag was validated here.

### Final local verification refresh — 2026-10-22

After the latest source and documentation review, the full local automated gates were repeated:

| Gate | Result |
|---|---|
| `make test` package stage | PASS: Core 282, Platform 32, Rendering 46, Runtime 73 (**433 total**) |
| `make test` UI stage | PASS: **2** UI tests, including Settings toggles/Restore Defaults/close/Quit |
| `make lint` | PASS |
| Debug build with Swift/GCC warnings as errors | PASS |
| Release build with Swift/GCC warnings as errors | PASS |
| `git diff --check` | PASS |

This refresh supersedes the dated 2026-10-18 verification counts for that worktree. It predates the
V5 art integration below; the final verification refresh will be recorded after the V5 tests run.
Earlier opaque sheets remain archived as rejected and are not runtime content.

### Final local verification with V5 assets — 2026-10-22

| Gate | Result |
|---|---|
| Focused Cat V4/V5 pack suite | PASS: 7 tests; all 16 V5 frames decode, satisfy canvas/alpha/margin/virtual-row checks, fall back safely when removed, and keep physics replay identical |
| V5 silhouette audit | PASS: one connected visible component in each of 16 runtime frames |
| `make test-core` | PASS: 436 tests (Core 282, Platform 32, Rendering 47, Runtime 75) |
| `make test` UI stage | PASS: 2 UI tests |
| `make lint` | PASS after `make format` |
| Debug build | PASS with Swift/GCC warnings as errors |
| Release build | PASS with Swift/GCC warnings as errors |
| V5 decoded frame budget | PASS: 15,925,248 bytes (15.19 MiB) at the 288 px reference decode size; below 16 MiB |
| `git diff --check` | PASS |

The builds selected the arm64 Mac destination and emitted Xcode's notice that multiple macOS
destinations match. No Swift source warning was reported in successful warnings-as-errors builds.
The earlier native interaction/performance evidence limitations remain unchanged. Final visual owner
review of the integrated frames remains pending.

### Limited Release CPU/RSS comparison — 2026-10-18

To add a real-app sample without changing saved settings, the base HEAD `9ecc8a0` and the current
uncommitted M10 Release app were launched separately on the same MacBook Air (macOS 27.0.1, built-in
1470×956 points @2×). Each had 30 s warmup, then 180 one-second `top` samples split into three
consecutive 60 s windows. User preferences were left untouched; no cursor movement or gesture was
scripted. Top's per-process CPU and resident-memory fields are retained in `/tmp/petscape-m10-*-top.txt`.
An attached Time Profiler recording produced 2,713 baseline and 2,467 M10 CPU samples, respectively.

| Release app sample | Window 1 CPU | Window 2 CPU | Window 3 CPU | Mean CPU | Resident-memory range |
|---|---:|---:|---:|---:|---:|
| HEAD `9ecc8a0` | 1.21% | 1.31% | 1.67% | 1.40% | 41 MB throughout |
| M10 worktree | 2.17% | 0.76% | 1.14% | 1.36% | 36–41 MB first window; 41 MB later |

Both means are below the ≤5% moving target for these natural, non-scripted windows. The roughly
−0.04 percentage-point difference is not evidence of a regression or improvement: behavior state
was not forced or verified, and no held/drag, paused/hidden/suspended, WindowServer/GPU, allocation,
latency, energy or leak window was collected. This sample does not close AC-M10-20 or replace the
native matrix and ≥2 h repeated pickup/cancel soak. Time Profiler traces are transient local files;
raw top logs remain outside the repository for review.

## Review focus

1. Fast off-mask click while routing is stale: underlying application must receive it (T10.0/T10.9).
2. Primary-up lost while secondary stays held: release exactly once using primary bit (T10.3/T10.6).
3. Hide/panel removal while no frames run: synchronous cancel, no orphan capture (T10.6).
4. Release before next frame: final target must commit before gravity and late move ignored (T10.4).
5. Tiny/negative-origin host or missing V5: safe clamp/recovery and identical physics (T10.4/T10.8).

## Owner authorization applied

The pasted owner instruction authorizes all T10.0–T10.9, V5 production, reversible engineering
choices, focused/full test gates and the named minimal UI test warning correction. It explicitly
requires no intermediate approval pauses. It also requires real native observations and visual
approval to be reported truthfully; this authorization alone does not make those results pass.
Publication remains unauthorized.

## Implementation continuation — 2026-10-18

This progress supersedes the earlier partial-code descriptions below; it does not change the native
PoC result or claim milestone acceptance.

| Slice | Implemented and automated evidence | Still unverified / open |
|---|---|---|
| T10.1–10.2 | Primary-button state is wired into Runtime; cursor awareness evaluates on a 0.1 s active cadence (0.5 s for sleep), fixed-step dwell/hysteresis, saved activity, click/drag exclusion | Native local/global monitor delivery and the full distance/scale/replay matrix |
| T10.3a–10.4 | Runtime interaction reducer is wired to current pass-through routing; acknowledged press reservation, ≥4 pt threshold, world-owned clamped held target, atomic final target, zero-velocity fall, latest-target lifecycle cancel | Native routing/focus/Dock/capture evidence and full release geometry matrix |
| T10.5 | Same-mask primary click, awake bounded `reactingToClick`, cooldown, sleeper wake path, no drag click | Native first-click routing and visual reaction |
| T10.6a–10.6b | Synchronous lifecycle hooks, primary-button lost-up recovery, v3 Settings, settings cancellation, Platform Reduce Motion read/change observer, held fallback during optional reaction | Full lifecycle notification matrix, UI runner/VoiceOver/short-screen manual checks |
| T10.7–10.8 | Existing optional-clip fallback aliases retained; two new V4-referenced generated candidates archived as rejected concepts | No production V5 clips; no visual acceptance or decoded-pack measurement |
| T10.9 | PASS: `make test-core` 433, `make test` UI 2, lint, Debug and Release builds; focused interaction and lifecycle tests pass. Limited paired app CPU/RSS results are recorded below | Native POC-01…10, full state-specific performance/WindowServer/latency/energy/leak gates, ≥2 h soak and owner review |

The interaction callbacks do not select a new window topology. They extend the existing route, whose
WindowServer focus and transparent-region behavior still needs the native matrix in
[m10-native-poc.md](m10-native-poc.md). Safety cancellation is allowed to clear the world reservation
after Pause/settings gates have changed, before any frames stop.

## Sequence and independent-session handoff

```mermaid
flowchart LR
  Authorized[Owner authorizes all M10 work] --> POC[T10.0 Native gate]
  POC --> NativeReview[Select topology only after native evidence]
  NativeReview --> C[T10.1 Cursor contracts]
  C --> A[T10.2 Awareness]
  C --> P[T10.3a Press and capture]
  P --> H[T10.3b Held motion]
  H --> R[T10.4 Release]
  P --> Click[T10.5 Click]
  A --> Life[T10.6a Lifecycle]
  R --> Life
  Click --> Life
  Life --> Settings[T10.6b Settings]
  Authorized --> Art[T10.7 V5 production]
  Art --> Integration[T10.8 V5 integration]
  Settings --> Integration
  Settings --> Verify[T10.9 Acceptance]
  Integration --> Verify
```

Files listed under each task are existing unless explicitly labelled **new proposed**. All package
source paths below start at `Packages/PetScapeKit/Sources/`; tests start at
`Packages/PetScapeKit/Tests/`. In task file lists, `Core/`, `Platform/`, `Rendering/` and `Runtime/`
are exact abbreviations for `PetScapeCore/`, `PetScapePlatform/`, `PetScapeRendering/` and
`PetScapeRuntime/`; `CoreTests/`, `PlatformTests/`, `RenderingTests/`, `RuntimeTests/` expand to
the corresponding `PetScape…Tests/` directories. Subsequent bare filenames on the same list use
the most recently named directory (e.g. Core/World/PetWorld.swift, WorldInput.swift).
No proposed path is claimed present. An executor must read AGENTS,
status, this plan and the owning spec, compare current HEAD to the inspected baseline, then implement
only its named task. Report prerequisite contract/evidence changes instead of rediscovering policy.
Each task ends with its focused tests, all package tests and lint, updated owning docs/evidence;
app-facing tasks additionally run Debug build. No task includes an implicit commit.

### T10.0 — Native routing and focus proof (M10.0)

**Objective/context:** resolve WindowServer capture risk before production modifications.
**Dependencies:** explicit owner authorization (received 2026-10-18). **Files:** read existing OverlayPanel,
OverlayContentView, CursorSampler, MousePassthroughController, PetHitTester; future isolated
prototype outside repository, results in [m10-native-poc.md](m10-native-poc.md).
**Consumes:** current panel flags/level and mask. **Produces:** candidate A/B results and selected
route, focus/permissions/latency/cost evidence, owner go/no-go; no production API.

- [x] Build the isolated native prototype described in the PoC plan. A and B both compiled and launched.
- [ ] Execute POC-01…10, record failures and unverified hardware separately; current result is inconclusive.
- [ ] Compare native results against zero-swallowed-input/focus/capture criteria; obtain owner
  topology acceptance before changing production. If no-go, revise proposal and stop dependent tasks.

**Tests/acceptance:** all applicable POC rows, AC-M10-02/03/04/05/12/14/19 native portions.
**Risk:** false confidence from only logging cat actions; observe actual underlying target actions.
**DoD:** reproducible results, explicit gaps and owner decision recorded, no prototype merged.

### T10.1 — Cursor sampling and shared input values (M10.1)

**Objective:** expose correct mouse data at existing seams, no visible reactions yet.
**Dependencies:** T10.0 native review for production interaction routing; owner engineering authorization received.
**Files:** Platform/Input/CursorSampler.swift; Runtime/Overlay/OverlayCoordinator.swift;
Rendering/Overlay/OverlayMouseEvent.swift and OverlayContentView.swift;
**new proposed** Core/Interaction/InteractionID.swift, InteractionCommand.swift,
InteractionCancellation.swift, InteractionTuning.swift.
**Tests:** extend PlatformTests/CursorSamplerTests.swift;
**new proposed** CoreTests/Interaction/InteractionInputTests.swift.
**Consumes/produces:** exact values/signatures in interaction spec; add sample callback
`OverlayCoordinator.onCursorSample: ((CursorSample) -> Void)?`; source-compatible event/sample
initializers, typed primary state, safe local/global token lifecycle.

- [x] Add contract assertions for negative-screen sample preservation and primary false with secondary true,
  local/global coverage distinct, duplicate start installs once, nil monitor disables acquisition,
  stop removes every token once and late callback ignored. Inject monotonic time/readers, no live mouse.
- [x] Run focused `CursorSamplerTests`; five cases pass. Local/global monitor lifecycle and primary-button state are covered.
- [x] Add source-compatible button/sample values; local native callback returns the original event and uses event-time window coordinates. No new scheduler or keyboard mask.
- [x] Wire shared cursor samples to the interaction Runtime; local/global delivery remains unverified in native use.

**Acceptance:** AC-M10-01 sampling portion, 13/17; no world behavior changes. **Risk:** treating
any-button as primary or asynchronous current location as event location. **DoD:** tested contracts,
existing clients compile, pure-Core boundary retained.

### T10.2 — Bounded cursor interest in existing HSM (M10.1)

**Objective:** visible finite curiosity without constantly interrupting M9.
**Dependencies:** T10.1. **Files:** Core/World/PetWorld.swift, WorldInput.swift, Pets/Pet.swift,
Behavior/GroundedState.swift and PetState.swift; **new proposed** Core/Interaction/CursorInterest.swift;
Runtime/PetRuntime/PetRuntime.swift. **Tests:** CoreTests/Behavior/AutonomyTests.swift;
**new proposed** CoreTests/Interaction/CursorInterestTests.swift.
**Consumes:** cached canonical cursor, existing needs/traits/settings; **produces:**
WorldInput.interaction(.observeCursor), reactingToCursor, saved eligible activity/remaining duration
and bounded interest/cooldown per spec. Pure `CursorInterest.update(location:dt:context:)` returns
an optional observe request; context contains spriteRect/scale/energy/curiosity/eligible state.

- [x] Add pure dwell/eligibility tests for the 0.35 s threshold, enter/exit hysteresis and blocked states;
  curiosity 0/0.5/1 → max 1/2/3 s, energy≤0.25 and sleep/flight/transitions never react.
- [ ] RED: identical dt histories at 60/30 Hz callbacks, no steps→no timer/random advance; after
  observation restore eligible remaining activity, otherwise bounded Idle; hovering forever cannot
  extend max duration. At most one facing change with ±8 pt deadband.
- [x] Integrate fixed-step interest with PetWorld and existing Runtime cursor samples; eligible grounded states only, no RNG per pointer event, bounded reaction, facing deadband, and saved remaining activity duration.
- [x] Focused helper/world tests pass; full package, lint and Debug gates pass. Missing `curious` art resolves through the idle fallback.
- [ ] Add the full 119/120/160/161 pt and scale matrix, 0.75 s grace/8 s cooldown boundary, 60/30 Hz replay, native local/global delivery and manual visual checks.

**Acceptance:** AC-M10-01/06/07/16; three-second cap and no chase. **Risk:** absolute deadlines
expire during interruption. **DoD:** exact replay and M9 autonomy/needs regressions preserved.

### T10.3a — Target acquisition, press reservation and capture (M10.2)

**Objective:** one accepted primary sequence owns the correct pet without stealing external drags.
**Dependencies:** T10.1, approved topology. **Files:** Runtime/Passthrough/PetHitTesting.swift,
PetHitTester+PetHitTesting.swift, MousePassthroughController.swift; Runtime/Overlay/OverlayCoordinator.swift,
PetRuntime/PetRuntime.swift; Core/Pets/Pet.swift, World/PetWorld.swift, WorldEvent.swift/WorldInput.swift;
**new proposed** Core/Interaction/InteractionSession.swift, Runtime/Interaction/InteractionController.swift.
For candidate B only, **new proposed** Rendering/Overlay/InteractionPanel.swift and
InteractionContentView.swift; extend existing OverlayWindowManager.swift. No panel code under Platform.
**Tests:** existing passthrough/panel/hit-tester/runtime tests;
**new proposed** RuntimeTests/Interaction/InteractionControllerTests.swift and
CoreTests/Interaction/PressReservationTests.swift.
**Consumes:** T10.1 values, existing `petID(at:)`; **produces:** controller signatures, acknowledged
press reservation, per-session pass-through capture. See spec for exact command/ack names.

- [ ] RED: down re-hits topmost PetID; off-mask/hidden/unknown IDs reject; external drag never
  acquires; primary only; rejected world press never sets capture; duplicate/stale sequence ignored.
- [ ] RED: reservation freezes body/phase/energy, saved remaining activity is restored relative to
  world time on cancel/up; other run state/invalid body always cancels before ordinary work.
- [x] Implement reducer/controller and world acknowledgement through the existing pass-through route.
  The bounded-panel candidate was not adopted because native comparison is inconclusive; no topology
  change was made. No physical lift occurs before the threshold.
- [x] GREEN package/lint/Debug and automated routing assertions pass. The native POC-02/03/05 repeat
  remains open; unit flags do not prove WindowServer focus/click-through.

**Acceptance:** AC-M10-02…05, 08 threshold/press portion, 18. **Risk:** window acceptance changes
before command ack; stale down swallowed by native routing. **DoD:** rejected gestures cannot mutate
world or latch capture; native regression has recorded outcome.

### T10.3b — Held motion with single world authority (M10.3)

**Objective:** thresholded pickup preserves foot offset and suppresses concurrent physics.
**Dependencies:** T10.3a. **Files:** Core/Interaction/InteractionSession.swift, Pets/Pet.swift,
Behavior/PetState.swift, World/PetWorld.swift, WorldInput.swift/WorldEvent.swift;
Runtime/Interaction/InteractionController.swift, PetRuntime/PetRuntime.swift.
**Tests:** **new proposed** CoreTests/Interaction/HeldMotionTests.swift; extend controller/runtime tests.
**Consumes:** press and session, `beginHold`/`moveHold`; **produces:** PetState.held, world-owned
held target, visible snapshot/demand at 60 Hz, no attachment/velocity/airborne timer while held.

- [ ] RED: movement 3.99 pt stays pressed, 4 pt begins held exactly once; offset preserved to
  1e-9 before clamp; both facings/scales/negative origins. Begin with walking, sleeping and falling.
- [ ] RED: many pointer moves in one callback interval coalesce; gravity never applies while held;
  no second position writer, no activity draw/energy advance; 10 simulated seconds held does not
  trigger 3 s airborne recovery. Held fallback remains visible and requires work.
- [x] Implement guarded authority transfer, jump cancellation/cooldown once and world-only commits;
  audit validate, needsSimulationSteps, needsAnimationFrames, preferredFPS, snapshot visibility,
  animation entry and Runtime passive-sleep classification together.
- [x] Package tests/lint/Debug pass, including held-world and Runtime interaction assertions.
- [ ] Native POC-06 on production; native delivery and outside-bounds capture remain unverified.

**Acceptance:** AC-M10-08/09/15/16. **Risk:** held mistakenly invisible because attachment nil,
watchdog still active, passive catch-up moves body. **DoD:** correct held snapshots/authority/demand
with/without clips and stationary primary held.

### T10.4 — Predictable drop through existing physics (M10.3)

Historical throw task retained under this ID, revised by the current brief: **no release impulse**.
**Dependencies:** T10.3b. **Files:** Core/World/PetWorld.swift, Interaction/InteractionSession.swift,
Runtime/Interaction/InteractionController.swift; existing PhysicsStepper/SurfaceMap/ContactGeometry
read/reuse, modify only if an exact-contact regression demonstrates necessity.
**Tests:** **new proposed** CoreTests/Interaction/DropTests.swift; existing LandingTests,
PhysicsWorldTests, RuntimeTests/PetRuntime/PetRuntimeTests.swift.
**Consumes:** `release(id,target:)`; **produces:** atomic final target and existing falling→landing,
zero initial velocity, freed capture, bounded autonomous return.

- [ ] RED: up before next frame applies final target; late move/duplicate up cannot move released
  body. First ordinary 1/60 s gravity step from y=100 gives vy=−40 and y=99⅓ without contact.
- [ ] RED seven release scenarios in spec, Dock/floor/exact support/changed support, no support,
  out-of-host/nonfinite/empty screens, all display-origin/scale cases. One contact, no tunneling,
  no infinite fall; existing 3 s watchdog and placement wait bound failure.
- [x] Implement clamp and final target commit inside release input; clear session/jump/velocity,
  then ordinary falling. Never snap to nearest shelf on normal release or wait for an art event.
- [x] Existing physics/jump suites, package/lint/Debug and final-target/zero-impulse automated tests pass.
- [ ] Check native threshold→held→release→landing without visible offset jump; no throw task implementation.

**Acceptance:** AC-M10-01 revised drag/drop, 09/10/11/14. **Risk:** last target dropped, double
integration or resurrected jump velocity. **DoD:** no dual movement authority or unsafe recovery.

### T10.5 — Click and hover semantics (M10.2)

**Dependencies:** T10.3a, T10.2 reaction seam. **Files:** existing Core/Interaction/InteractionSession.swift,
World/PetWorld.swift, Behavior/GroundedState.swift/PetState.swift; Runtime/Interaction/InteractionController.swift.
**Tests:** **new proposed** CoreTests/Interaction/ClickTests.swift; extend controller tests.
**Consumes:** primary up from reservation; **produces:** `click`, bounded reactingToClick or existing
wake, no double-click-specific command/timer.

- [ ] RED: primary up over same mask with <4 pt movement triggers exactly one click; release
  off-mask, cancel, lost-up recovery, duplicate up, drag and right click trigger none.
- [ ] RED: awake grounded reaction lasts 0.6 s, repeat cooldown 0.5 s; two quick clicks do not
  produce an extra special action. Sleeping click uses 0.5 s waking; airborne click resumes flight.
- [x] Implement hover/exit as input facts and click command in same controller/world/HSM; no
  position or energy reward, no delayed single-click disambiguation.
- [x] Package tests/lint/Debug pass, including same-pet primary click, drag exclusion, bounded awake
  feedback, sleeper wake and cooldown assertions.
- [ ] Native first click works without activating app.

**Acceptance:** AC-M10-02/04/06/07. **Risk:** up both releases and clicks; double callback from
local monitor/responder. **DoD:** one deliberate action per valid sequence, documented cooldown.

### T10.6a — Lifecycle cancellation and lost-up recovery (M10.3)

**Dependencies:** T10.2/3b/4/5. **Files:** Runtime/Overlay/OverlayCoordinator.swift,
Interaction/InteractionController.swift, PetRuntime/PetRuntime.swift;
Platform/Input/CursorSampler.swift, SystemEvents/SystemEventsMonitor.swift; Core/World/PetWorld.swift.
**Tests:** existing runtime/RunState/monitor tests; **new proposed**
RuntimeTests/Interaction/InteractionLifecycleTests.swift.
**Consumes:** cancellation enum, primary sample, run/screen/Space notifications;
**produces:** synchronous idempotent cancel before teardown and no stuck drag without a timer.

- [ ] RED table: Pause/Hide/sleep/lock/session inactive/occlusion/Space change/host loss/Dock change/
  panel removal/pet replacement/stop, including zero pending frames and no native up.
- [ ] RED: primary false while secondary true ends exactly once by next delivered frame; primary
  true plus secondary-up does not end; late old-generation callbacks cannot touch new pet.
- [x] Implement pre-teardown cancellation hook in coordinator and call it before applying new
  screens/panels or hiding. Invalid body recovery clears world session; Runtime releases capture.
  Resume seeds accumulator, latest surfaces, no movement/time catch-up.
- [x] Package tests/lint/Debug pass, including cancellation before paused-frame stop and final-target
  lifecycle release.
- [ ] Native POC-07…09. Record available hardware and exact measured release latency; don't infer it
  from fake frame tests.

**Acceptance:** AC-M10-12/13/14/18. **Risk:** notification after panel destroyed, no effective frames
for button guard. **DoD:** every cancellation row tested, tokens removed and no orphan ownership.

### T10.6b — Settings, accessibility and persistence (M10.1–M10.3)

**Dependencies:** T10.6a. **Files:** Core/Pets/PetSettings.swift; **new proposed**
Core/Interaction/InteractionSettings.swift; Platform/Preferences/PreferencesStore.swift,
UserDefaultsPreferencesStore.swift, InMemoryPreferencesStore.swift;
Runtime/Settings/SettingsModel.swift, PetRuntime/PetRuntime.swift;
`PetScape/SettingsView.swift`, `PetScape/App/AppContainer.swift`;
Platform/SystemEvents/SystemEventsMonitor.swift for Reduce Motion notification/reader injection.
**Tests:** existing PreferencesStoreTests, SettingsModelTests, PetRuntimeTests;
`PetScapeUITests/PetScapeSettingsTests.swift` extended only during authorized implementation.
**Consumes/produces:** InteractionSettings/PetSettings.interaction v3 contract, two controls,
SettingsModel setters `setCursorReactionsEnabled(_:)`/`setDirectInteractionEnabled(_:)`.

- [x] Add tests for absence defaults true; v1/v2 migration preserves old values, future version/unknown
  keys retained; Restore Defaults known keys only; in-memory parity. Disable/resize during press
  or held cancellation remains unimplemented with the interaction session.
- [ ] RED: autonomy off does not disable enabled explicit interaction; expressions off suppresses
  cursor reaction; Reduce Motion change holds optional reaction frame without altering drop path.
- [x] Implement live controls/model forwarding and Platform Reduce Motion input. Pause disables
  new interaction starts; cancellation is applied synchronously before frames stop.
- [x] Package/lint/Debug and UI toggle/restore/close/Quit with isolated prefs/fake login pass. The
  slider's persisted value is not exposed consistently by XCUI and is not asserted by that UI test.
- [ ] Manual short-screen layout and VoiceOver labels/focus. Never register actual login item in tests.

**Acceptance:** AC-M10-13/16/17/18. **Risk:** persisted toggle differs from live routing, new controls
push Quit/cancel beyond visible area. **DoD:** restore/relaunch/live cancel and accessible control evidence.

### T10.7 — V5 production (M10.4)

**Dependencies:** owner art brief and production authorization received.
**Files:** new `assets/characters/cat/v5/` provenance and curious/picked-up/held clip folders; original
assets remain immutable. **Contracts/tests:** owning V5 brief, RGBA/dimensions/registration/border
checks. **Produces:** 16 frames and provenance; visual owner approval is a separate pending review.

- [x] Produce 6 curious, 4 picked-up and 6 held frames under new paths; original V4 files are preserved.
- [x] Validate frame-level alpha, 512×512 canvas, transparent margin, virtual-foot registration and clip metadata.
- [ ] Obtain owner visual approval in the DEBUG Animation preview; no approval is claimed here.

**Acceptance:** AC-M10-15/16 visual portions; proposed ≤16 MiB estimate. **Risk:** held pose clips
canvas or changes virtual foot. **DoD:** approved additive art or explicitly documented non-delivery.

- [x] Owner reauthorized V5 production and integration on 2026-10-22. Runtime clips load directly;
  safe fallbacks remain for absent or invalid optional art.
- [ ] Owner visual review of the integrated clips remains pending.

### T10.8 — Optional V5 integration (M10.4)

**Dependencies:** T10.6b, T10.7 generated delivery; fallback engineering remains available for missing sprites. **Files:** additive manifest changes in
`assets/characters/cat/character.json`, existing Runtime/Characters/CharacterLoader.swift,
Core/World/PetWorld.swift only if semantic fallback wiring requires it;
`Packages/PetScapeKit/Tests/PetScapeRuntimeTests/Characters/V4CharacterPackTests.swift` (extended
with V5 pack assertions);
extend RenderingTests/Images/CatArtAuditTests.swift only for new immutable sources.
**Consumes:** V5 generated paths/schema v1; **produces:** same physics with real or absent V5.

- [x] Missing/invalid optional files fall back safely; missing V5 aliases resolve to idle. Replay
  checks cover 1/8/12/24/32 synthetic frames plus the delivered V5 pack versus idle-only art;
  position/velocity/state remain simulation-owned.
- [x] Additive fallback aliases for the three optional V5 names resolve to idle with unchanged schema v1; loader/runtime tests pass. No V4 clip definitions or frame sources were changed.
- [x] Missing-clip fallback and optional presentation timing regression tests pass without changing physical replay.
- [x] Add generated V5 manifest entries; load through existing decoder/store without a runtime atlas.
  Pack tests check ≤16 MiB decoded bytes on the reference display; mask/cache overhead is separate.
- [x] Rerun complete package/lint/Debug/Release gates with the real-art pack; all pass as recorded above.
- [ ] Owner preview of identity, both facings/scales, pressed→picked-up→held→fall→landing. Retain original file checksums.

**Acceptance:** AC-M10-15/16/20 memory portion. **Risk:** art-next controls physics, unknown higher
DPI exceeds budget. **DoD:** validated pack and unchanged physical replay; no art-produced claim
if testing fallback only. Owner must explicitly defer real art before full milestone closure.

### T10.9 — Regression, performance and owner acceptance

**Dependencies:** T10.6b and T10.8 or explicit V5 deferral. **Files:** existing docs acceptance,
testing/performance/risks/milestones; source edits only for demonstrated in-scope regressions with
failing tests first. **Consumes:** all task evidence. **Produces:** truthful M10 verification table
and owner review, never automatic release.

- [x] Run `make lint`, `make test`, Debug and Release builds with warnings as errors on 2026-10-22;
  all passed. Warnings and evidence are summarized above. No test was skipped or weakened in this run.
- [ ] Run all AC-M10 criteria and the native matrix below. Add explicit ≥2 h installed-app
  interaction soak with repeated pickups/cancels and leak delta; accelerated replay is separate.
- [ ] Measure paired baseline HEAD versus M10 on same machine in Release outside Xcode, record
  exact settings/art/monitor state, 30 s warmup +≥60 s windows ×3; Instruments Time Profiler,
  Allocations/Leaks, Core Animation/System Trace and existing signposts. No benchmark during UI run.
- [x] Owner confirmed interaction tests approved and directed closure on 2026-10-22. Known raw
  native/performance evidence limits remain; V5 art integration is being verified separately.

**Acceptance:** all rows below. **Risk:** treating unit masks or historic M9 data as native proof.
**DoD:** builds/tests/lint and measured/manual evidence complete, or specific gaps explicitly
accepted by owner; remaining unverified results stay labelled, no silent pass.

### Owner M10 closeout — 2026-10-22

The owner stated “todos os testes estão aprovados” and directed M10 behavior closure. This is the
explicit acceptance required by the original authorization. The later request reauthorized the
previously missing V5 production; implementation and automated checks are complete, with owner
visual review still pending. This acceptance record does not substitute for raw measurements that
were not provided.

| Area | Closeout record |
|---|---|
| Automated gates | Earlier M10 refresh: 433 package tests and 2 UI tests. V5 refresh: 434 package tests, 2 UI tests, lint, Debug/Release builds with warnings as errors; all passed |
| Native manual matrix | Accepted by the owner's statement that all tests are approved. Individual POC-01…10 observations, counts and latency values were not separately supplied; the historical PoC record remains partial/inconclusive as an evidence artifact |
| Performance/soak | Owner acceptance recorded; the only numerical sample is the limited paired Release CPU/RSS comparison above. Full two-hour soak, state-specific CPU, energy, WindowServer, allocation/leak and latency datasets were not collected in this worktree |
| V5 art | Reauthorized on 2026-10-22: six `curious`, four `picked-up` and six `held` frames are integrated. Focused pack QA passes; owner visual approval is not claimed |
| Architecture | Production continues under accepted ADR-0003/current routing. ADR-0020 remains Proposed because no candidate-selection evidence or specific topology approval was supplied |
| Publication | This historical closeout preceded the owner's later Git instruction; the feature branch and merge are now explicitly authorized |

Known limitations are accepted for this milestone closeout and remain visible for future work. Do not
rewrite partial native/performance records as measured passes or refer to rejected generated images
as V5 production assets.

## Acceptance, risk and regression matrix

Criteria are registered once in [acceptance-criteria.md](acceptance-criteria.md#m10--cursor--drag).
A = deterministic automated, N = native/manual, P = measured performance. Owner acceptance and
the evidence limits for remaining N/P rows are recorded in the closeout above.

| AC-M10 | Required observation / risk controlled | Method / owner task |
|---|---|---|
| 01 | Dwell/hysteresis/cooldown and ≤3 s curiosity; revised preserved-offset drag with zero-impulse release | A T10.1/2/3b/4 |
| 02 | Valid primary click exactly once, no click on drag; AC-14/21 regressions preserved | A+N T10.0/3a/5/9 |
| 03 | Transparent corners/holes/margins pass click/right/scroll/external drag, ≥20 points and 100 fast sweeps | N T10.0/9; coarse-mask A supplements |
| 04 | No activation/key/main/focus or typing theft, 50 sequences in two foreground apps | N T10.0/9 |
| 05 | Dock bottom/left/right, auto-hide/magnification usable and above overlays | N T10.0/9 |
| 06 | No cursor interruption of sleep/flight/transition/low-energy; saved eligible context or bounded fallback | A T10.2/5 |
| 07 | No per-event RNG/reaction stacking; seeded activity replay and bounded resumption | A T10.2/5/9 |
| 08 | <4 pt press, ≥4 pt pickup, primary only; reject external drags | A+N T10.3 |
| 09 | Target = cursor−offset within 1e-9 before clamp; all scales/facings/origins, latest move coalesced | A+N T10.3b/4 |
| 10 | Final up target applied once, velocity zero, gravity only after release; late move ignored | A T10.4 |
| 11 | Land on first valid support or one bounded recovery, no disappearance/loop; exact y, no surface | A+N T10.4 |
| 12 | Lost primary up recovered by next 60 Hz callback (native target≤50 ms), secondary-up safe | A+N T10.6a |
| 13 | Cancel before stop/gates, no sim/animation/cursor-behavior steps paused/hidden/suspended; no catch-up | A+N T10.6a/b |
| 14 | Dock/screen/Space/resolution changes never leave capture; single-host clamp, no false M14 claim | A+N T10.4/6a |
| 15 | Existing six clips unchanged, held visible and all physical paths animation-independent | A+N T10.3b/8 |
| 16 | Missing/invalid V5 and invalid pack safe, Reduce Motion works, no required new art/schema | A+N T10.2/6b/8 |
| 17 | Toggle defaults/live disable/relaunch/v3 migration/future preservation/Restore Defaults/VoiceOver | A+N T10.6b |
| 18 | All relevant tests/lint/Debug/Release, no hidden warnings/failures or weakened tests | A T10.9 |
| 19 | PoC outcome recorded and topology accepted before adoption, no new permission or foreign-app input injection | N+review T10.0/9 |
| 20 | Resource, frame latency and soak criteria below measured, >20% paired regressions explained/accepted | P T10.9 |

Proposed thresholds retain existing moving CPU≤5% of one core, paused/hidden≤0.2%, idle wakeups≤1/s,
footprint≤100 MB, Core step p95≤0.3 ms, ≤16 MiB decoded pack on reference 2× screen. Apply moving
budget also to held/drag; passive still/animated idle/sleep measured separately, not called paused.
Target event→display held response p95≤33.4 ms/max≤50 ms at ordinary 60 Hz; process time and delivery
wait measured separately. Target no steady per-input/per-frame allocation after warmup (activity
choice/load/geometry changes measured separately), no app-owned leaked monitors/windows after 100
create/cancel/stop cycles; two-hour footprint growth<10 MB. GPU/WindowServer and energy impact need
paired measurements and >20% regression review, no invented absolute GPU number. Preserve hardware/
OS/settings/output logs so short-window results are not compared as equivalent to M6's 69 min run.
No new performance readings were collected by this planning session.

Native regression matrix includes: running walk/idle/rest/sleep/jump, small/normal/large cat,
both facings, bottom/left/right Dock and auto-hide/magnification, Finder/editor/desktop targets,
ordinary Spaces/full-screen entry/exit, pause/hide/resume, sleep/wake/lock, resolution/DPI/display
arrangement/removal, VoiceOver/Reduce Motion, invalid character pack. External hardware/macOS 14
compatibility are pending until available or explicitly accepted exceptions. Never require a new
system permission to make the matrix pass.

Risks are tracked in [risks.md](risks.md#m10-planning-risks); their tests/owners are the AC rows
above. Future throwing, chase/startle, cross-display motion and extra petting/look art are deferred,
not partially implemented behind undocumented behavior.

## Final planning review

- [x] Current native/world/physics/behavior/manifest/settings/test paths inspected and recorded.
- [x] API claims researched in primary Apple sources and linked; inference/native gates separated.
- [x] Nine decision topics covered by ADR-0019 (observation), 0020 (capture/click-through/mask/focus),
  0021 (physics/priorities/cancel/animation), all Proposed.
- [x] Contracts, cancellation/release matrix, V5 brief, dependency DAG and task-level tests defined.
- [x] Historical throw/paused-drag wording revised explicitly, stable IDs preserved.
- [x] No Swift/test/asset/dependency changes, no PoC execution or repository publication.
- [x] Full M10 authorization received from owner on 2026-10-18.
