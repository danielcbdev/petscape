# Task Breakdown

Conventions: IDs `T<milestone>.<n>` are stable. Size: **S** ≤ ½ day, **M** ≤ 1 day, **L** ≤ 2 days.
"Verify" says how completion is proven (U = unit tests, I = integration tests, UI = UI tests,
Man = manual check recorded in the PR). Modules: Core, Plat (Platform), Rend (Rendering), Run
(Runtime), App, Docs. Acceptance criteria per milestone: [acceptance-criteria.md](acceptance-criteria.md).

## M0 — Repository preparation & planning

| ID | Task | Mod | Deps | Size | Verify | Status |
|---|---|---|---|---|---|---|
| T0.1 | Inspect repository, assets and toolchain; record asset audit | Docs | — | S | Audit in asset-format.md | Done |
| T0.2 | Add `.gitignore`; untrack committed `.DS_Store` files (`git rm --cached` on the 5 tracked files) | Repo | — | S | `git ls-files | grep DS_Store` empty | Done (staged, not committed) |
| T0.3 | Write product, architecture, specification docs and ADRs | Docs | T0.1 | L | Review | Done |
| T0.4 | Write AGENTS.md, CLAUDE.md, CODEX.md, Cursor rules, Claude settings | Docs | T0.3 | M | Review | Done |
| T0.5 | Owner review; answer open decisions (risks.md) | Owner | T0.3–T0.4 | S | Decisions recorded | Done (D-01, D-02, D-05) |
| T0.6 | Commit planning on `docs/planning` and open PR into `develop` (when asked) | Repo | T0.5 | S | PR merged | Pending |

## M1 — Overlay proof of concept (branch `spike/overlay-poc`, not merged)

| ID | Task | Deps | Size | Verify | Status |
|---|---|---|---|---|---|
| T1.1 | Create a minimal `OverlayPoC` accessory app (status-item menu with Quit) on the spike branch | T0.5 | S | Launches, no Dock icon | Done (SwiftPM + bundling script, see PoC notes) |
| T1.2 | E1: borderless non-activating `NSPanel` covering the main screen, clear background, `SKView` with `allowsTransparency`; draw `walk_01.png` at 96 pt | T1.1 | S | Screenshot: no background, crisp sprite | Done (E1 confirmed) |
| T1.3 | E2: implement click-through strategies A, B, C with a menu switch; log hit/miss; measure toggle latency | T1.2 | M | Results table E2 | Done (C confirmed by owner) |
| T1.4 | E3: place the sprite on `visibleFrame.minY`; test Dock sizes, magnification, autohide, left/right; log whether screen-parameter notifications fire for each change | T1.2 | M | Results table E3 + screenshots | Done (E3 confirmed; level → Dock − 1) |
| T1.5 | E4: click and drag the sprite (strategy C) without activating the app or stealing focus from the frontmost app | T1.3 | S | Results table E4 | Done (E4 confirmed in owner session) |
| T1.6 | E5/E6: resolutions/scaling, external display, Spaces, Mission Control, Stage Manager, fullscreen, lock/sleep | T1.2 | M | Results tables E5, E6 | Done (S9 external display not run → M14; S8 needs log evidence in M3) |
| T1.7 | E7: animate the 8 frames at 9 fps and move at 40 pt/s; measure CPU/energy at 60 fps, paused, hidden; optional CALayer comparison if > targets | T1.2 | M | Measurements entry | Done → Core Animation (ADR-0015) |
| T1.8 | E8: check Dock interactions under the overlay (hover magnification, click, right-click, drag file to Dock) and menu bar menus over the overlay | T1.3 | S | Results table E8 | Done (E8 confirmed) |
| T1.9 | Write results in proof-of-concept.md; update ADR-0003/0004/0009, scope assumptions and risks; recommend go/adjust | T1.3–T1.8 | S | Owner sign-off | Done (conclusion in proof-of-concept.md; ADR-0003/0009 accepted) |

## M2 — App skeleton

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T2.1 | Create `PetScape.xcodeproj` (macOS App, SwiftUI lifecycle, folder-synchronized groups); `Config/Base|Debug|Release.xcconfig` with `PETSCAPE_BUNDLE_ID`, deployment 14.0, Swift 6, Hardened Runtime on, sandbox off, warnings-as-errors in Release | App | M1 | M | `xcodebuild build` succeeds |
| T2.2 | Info.plist: `LSUIElement`, display name, `LSMinimumSystemVersion`; `Localizable.xcstrings`; placeholder app icon | App | T2.1 | S | No Dock icon on launch (Man) |
| T2.3 | Create `Packages/PetScapeKit` (`swift-tools-version: 6.2`) with Core/Platform/Rendering/Runtime + test targets, dependencies per modules.md, `defaultIsolation(MainActor)` for non-Core targets | Pkg | T2.1 | S | `swift build` succeeds |
| T2.4 | `Log` categories (subsystem = bundle ID) and `OSSignposter` helpers in Core; smoke test with Swift Testing | Core | T2.3 | S | U |
| T2.5 | Link the package to the app; `AppDelegate` + `AppContainer` composition root; `MenuBarExtra` (SF Symbol `pawprint`) with "Quit PetScape" | App | T2.3 | S | Man: quit works, no crash report |
| T2.6 | `.swift-format` config; Makefile (`build`, `test`, `test-core`, `lint`, `format`, `run`) | Repo | T2.3 | S | All targets run clean |
| T2.7 | UI test target with a launch test (process starts; status item exists — **[validate]** XCUITest access to status items) | App | T2.5 | S | UI |
| T2.8 | GitHub Actions: build + `make test-core` on push/PR to `develop` (only if owner approves CI, D-06) | Repo | T2.6 | S | Green run |
| T2.9 | Update setup.md with verified commands and project settings | Docs | T2.6 | S | Review |

## M3 — Transparent overlay

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T3.1 | `ScreenDescriptor`, `Segment`, `CoordinateConverter` (Quartz↔global↔overlay-local) with the test list in coordinate-system.md | Core | T2.3 | M | U |
| T3.2 | `ScreenProvider`: NSScreen → descriptors, primary detection, change notifications → async stream / callback | Plat | T3.1 | S | U (pure mapping) + Man |
| T3.3 | `OverlayPanel` configured exactly as macos-integration.md (style, level, collection behavior, never key/main, accessibility hidden) | Rend | T2.3 | S | Man + unit test of configuration values |
| T3.4 | `OverlayWindowManager`: create/update/remove panels for requested screen IDs on descriptor changes | Rend | T3.2, T3.3 | M | Man (connect/disconnect display) |
| T3.5 | `OverlayContentView` (layer-backed, clear) + `DisplayLinkFrameDriver` skeleton; DEBUG-only outline of the overlay and a test rectangle layer | Rend | T3.4 | S | Man screenshot |
| T3.6 | `PetHitTesting` protocol + `MousePassthroughController` state machine (passThrough / interactive / dragging) with fake hit tester | Run | T3.1 | M | U |
| T3.7 | `CursorSampler`: per-frame `mouseLocation`; global mouse-moved monitor started only while paused and visible; teardown | Plat | T2.3 | S | Man + U for lifecycle |
| T3.8 | `SystemEventsMonitor` (sleep/wake, screens sleep, session, lock, occlusion) + `RunStateController` combining user intent and system state | Plat, Run | T2.3 | M | U for all state combinations |
| T3.9 | Wire into `AppContainer`; manual click-through matrix (Finder, Dock, menu bar, other apps, desktop icons) with the test rectangle | App | T3.4–T3.8 | S | Man (matrix in PR) |
| T3.10 | Full-screen Space rule: on `activeSpaceDidChange`, read `CGWindowList` twice (after the transition, 400 ms apart); no on-screen Dock-owned window at the Dock level → `RunStateController` suspended + overlay ordered out; restore when it returns. Pure decision function in Core with tests | Plat, Run, Core | T3.8 | S | U (decision function) + Man (full-screen app, auto-hide Dock) |

## M4 — Animation system

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T4.1 | `CharacterManifest` Codable (schema v1) + JSON fixtures (valid cat, each error case); check all 8 frames for stray islands (audit F8) in a fixture test | Core | T2.3 | M | U |
| T4.2 | `ManifestValidator` with the error/warning catalog from animation-schema.md | Core | T4.1 | M | U (one test per code) |
| T4.3 | `CharacterDefinition` resolution: defaults, fallback chains (cycle detection), variants, durations from fps | Core | T4.2 | S | U |
| T4.4 | `AnimationPlayer`: loop/once/pingPong, per-frame durations, rate, multi-frame steps, ordered events; parameterized over 8/12/16/24/32 frames and 60/120 Hz stepping | Core | T4.3 | M | U |
| T4.5 | `AnimationController`: requests with priority, interruptible, `next` chaining, fallback resolution | Core | T4.4 | S | U |
| T4.6 | `ImageDecoder`: ImageIO decode + downsample to target pixel size off the main actor; errors for missing/undecodable files | Rend | T2.3 | S | I (fixture PNGs) |
| T4.6b | Sheet slicing (`sheet` + `cell`) — optional for MVP | Rend | T4.6 | S | I |
| T4.7 | `FrameImageStore` (decoded `CGImage` cache, preload, cache key, memory accounting) + `HitMask` generation (¼ res, α ≥ 128, 1-cell dilation) | Rend | T4.6 | M | I + U (mask) |
| T4.8 | Author `assets/characters/cat/character.json` (new file) per schema; test that validates every bundled pack | Assets, Core | T4.2 | S | U |
| T4.9 | Bundle the cat pack into the app (folder reference to `assets/characters`, excluding OS files); verify paths inside the built `.app` | App | T4.8 | S | Man (inspect bundle) + I |
| T4.10 | `CharacterLoader` (Runtime): load + validate + textures; error reporting; programmatic placeholder; DEBUG "Animation preview" menu that plays a clip in place | Run, App | T4.5, T4.7, T4.9 | M | I + Man (walk plays at 9 fps) |

## M5 — Rendering & automatic walking

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T5.1 | `Surface`, `SurfaceID`, `SurfaceMap` (horizontal segments, lookup, diff apply) | Core | T3.1 | S | U |
| T5.2 | `FixedStepAccumulator` (dt 1/60, max 5 steps, 0.25 s clamp, reset) | Core | T2.3 | S | U |
| T5.3 | `Pet`, `PetWorld.step`, MVP FSM (spawning/walking/turning/recovering), edge margins; measure walk stride in the preview and set `nominalSpeed` + `footstep` frames in the manifest | Core, Assets | T4.5, T5.1, T5.2 | L | U + Man (no foot sliding) |
| T5.4 | `RenderSnapshot` + `PetLayer` (contents, explicit bounds, anchor, mirroring transform, implicit animations disabled); global→overlay-local conversion | Core, Rend | T5.3, T4.7 | M | U (snapshot) + Man |
| T5.5 | `PetRuntime` + `FrameDriver` (`CADisplayLink`): drain inputs → steps → snapshot → render → pass-through; temporary surface = bottom of the Dock screen | Run | T5.4, T3.6 | M | I (fake driver) + Man |
| T5.6 | `PreferencesStore` (+ in-memory fake); menu Show/Hide and Pause/Resume via `AppModel`; persistence of `isPaused`/`isHidden` | Plat, App | T5.5 | M | U + Man (relaunch keeps state) |
| T5.7 | Adaptive render rate (60 while moving; `isPaused` when paused/hidden/suspended) | Run, Rend | T5.5, T3.8 | S | Man + CPU check |
| T5.8 | Pass-through with real hit masks (mirroring, scale) | Run, Rend | T4.7, T5.5 | S | U (mask lookup) + Man (click near ears/tail) |

## M6 — Dock integration & MVP hardening

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T6.1 | `DockGeometryEstimator` (pure) with the test table in surface-detection.md | Core | T3.1 | S | U |
| T6.2 | `DockSurfaceProvider`: estimate → `.dockTop`/`.screenBottom`; recompute on screen-parameter changes; fallback re-read strategy per PoC E3 | Plat, Core | T6.1, T5.1 | M | U + Man |
| T6.3 | `dockOffsetAdjustment` preference (−40…+40 pt) with DEBUG menu stepper | Plat, App | T6.2, T5.6 | S | Man |
| T6.4 | Surface re-projection on change (Dock resized/moved/hidden) with clamping and edge handling | Core | T6.2 | S | U |
| T6.5 | Suspend/resume integration: sleep/wake, lock, display sleep, fast user switching, occlusion; accumulator reset | Run | T3.8, T5.5 | S | Man (matrix) |
| T6.6 | Screen configuration changes: overlays rebuilt, pet respawned if its screen disappears, Dock moved to another display | Run | T3.4, T6.2 | M | Man (external display) |
| T6.7 | Error UX: menu status line for load failures / degraded mode; placeholder visible | App | T4.10 | S | Man (rename fixture in a dev build) |
| T6.8 | Performance pass per performance.md protocol; record measurements; fix regressions | All | T6.1–T6.7 | M | Measurements entry |
| T6.9 | Leak check (Instruments Leaks) + 2 h soak run | All | T6.8 | S | Report in PR |
| T6.10 | Run full MVP manual matrix (testing.md); README usage section; prepare v0.1.0 notes | Docs | T6.9 | S | Matrix recorded |

## M7 — Basic physics

Status: **Done, 2026-10-18: implemented; owner confirmed all remaining tests and explicitly requested closure.** Spec: [Physics Engine](../architecture/physics-engine.md).
Baseline and proposed API impact: [technical review](m7-m8-technical-review.md).

**Goal:** gravity, visible falls and bounded landing/recovery while preserving walking and desktop behavior.
**Architecture:** pure Core stepper returns candidate state; existing PetWorld commits Pet.position/velocity;
Runtime retains its display link, accumulator and recovery coordination. Rendering consumes snapshots.
**Stack:** Swift 6 (6.2-compatible), CoreGraphics value geometry, Swift Testing; AppKit/QuartzCore at existing edges.

### Shared execution constraints and quality gate

These apply to every T7/T8 task below: macOS 14+, no dependencies/private APIs/new permissions;
original art read-only; no new schema/preferences keys; Core nonisolated/Sendable, actual world owner
MainActor. Owner approved planning and then explicitly authorized continuous execution of all M7/M8 tasks on 2026-10-18.
No commits/pushes/tags/PRs unless separately requested. Paths labelled **Create** identify the original implementation plan; implemented files now exist.
This authorization permits runtime/M8 engineering before predecessor manual closeout; it does not mark those evidence gaps passed.

During execution: run focused new tests red first, implement, run them green, then
`make test-core`, `make lint`, `make build`; all must pass with zero Swift warnings. Runtime/App
slices also run `make test` in existing Automation Mode; never enable a permission as part of the app.
Record actual output/environment and update task evidence, specs and milestone status only when warranted.
This shared gate is each task's **Definition of Done**, together with its specific acceptance below;
no task is complete merely because the next task will make it testable. Keep every slice buildable.

**Review focus:** x at crossing rather than endpoint (T7.2); hidden/still snapshot recovery liveness
(T7.6); changed geometry during paused flight (T7.7/T8.2); duplicate phase events with fallback art
(T7.8/T8.4); unknown real Dock ends and non-host displays (T7.3/T7.5/T8.3). Each has tests below.

For concise paths in these task plans, `S/` = `Packages/PetScapeKit/Sources/`,
`T/` = `Packages/PetScapeKit/Tests/`; names under these prefixes identify real files unless **Create**.

### T7.1 — Bounded physics values and integration (S)

Owner authorized the recommended first task with planning approval on 2026-10-18. Scope is pure
Core helpers only; M5/M6 evidence/deviations remain open and the later runtime gate is unchanged.

- **Objective/context:** establish reusable tested kinematics before changing live walking. Current Pet has no velocity.
- **Dependencies:** owner approval of ADR-0016, predecessor M6 gate/explicit exception in implementation-plan.md.
- **Files:** Create `S/PetScapeCore/Physics/PhysicsTuning.swift`, `ContactGeometry.swift`,
  `PhysicsStepper.swift`, `MovementIntent.swift`, `PhysicsStepResult.swift` in the same Physics folder;
  Create `T/PetScapeCoreTests/Physics/PhysicsStepperTests.swift`.
- **Contracts:** internal Sendable values. `PhysicsStepper.integrate(position: CGPoint, velocity: CGVector,
  acceleration: CGVector, dt: Double, tuning: PhysicsTuning) -> PhysicsStepResult?`; nil for invalid input.
  Result contains candidate position/velocity and optional attachment/edge/contact fields for T7.2.
  ContactGeometry derives stable halfWidth/height from validated displaySize/scale. No stored second body.
- [x] Write failing `gravityFromRest` (100→99⅓ pt, dy=−40 after 1/60), `horizontalAcceleration`
  (vx0=0, ax=60 → vx1=1, dx=1/60), `terminalClamp` (dy≥−1800), `invalidStepIsRejected`
  (0, negative, NaN, infinity, 0.5 → nil), `geometryIndependentOfPose` (96 pt → 48×60, scale 1.5 →72×90).
- [x] Run focused PhysicsStepperTests; confirm assertions fail for missing implementation.
- [x] Implement the pure bounded integration and immutable tuning defaults from Physics Engine;
  preserve existing world behavior because it does not consume this seam yet.
- [x] Run focused tests green and shared quality gate; document exact tuning/units.
- **Accept:** AC-M7-04/05/06 core helper subset; no live behavior change.
- **Risks:** gravity sign/unit confusion or invalid dt contaminating state; nil has no side effects.
- **DoD:** shared gate + tested helper, old app unchanged, defaults explicitly provisional.

**Verification (2026-10-18):** Complete. New PhysicsStepperTests ran RED against nil-returning
stubs (10 failed behavior assertions), then GREEN with all 16 tests. `make test-core` passed 299
package tests (Core 190, Runtime 40, Rendering 44, Platform 25); `make lint` passed; `make build`
succeeded with zero Swift compiler warnings. Xcode emitted only the known AppIntents metadata
extraction warning documented in setup.md. Independent read-only review found no actionable issues.
No existing Swift source/test was edited; five internal Core physics files and one test file added.
No collision, world integration, live velocity, frame scheduling or recovery behavior is implemented
yet. No new visual/performance claims, permissions, dependencies, commits or releases.

**Implementation rulings:** reuse FixedStepAccumulator.defaultStep/tolerance rather than duplicate
loop constants; ContactGeometry uses CGSize points plus scale, rejecting invalid/overflowed size;
invalid injected tuning returns nil at the step boundary. These clarify the approved bounded-helper
contract without changing world APIs. M5/M6 remain In review; T7.1 authorization is not a waiver of
manual acceptance gates. The later continuous-execution instruction authorized the remaining engineering; the following evidence supersedes the isolated-helper snapshot above.

### T7.2 — Swept horizontal support and deterministic contact (M)

- **Objective/context:** implement actual swept crossing; highestWalkable(below:) alone is not a sweep.
- **Dependencies:** T7.1.
- **Files:** Modify `S/PetScapeCore/Physics/PhysicsStepper.swift`, `PhysicsStepResult.swift`,
  `S/PetScapeCore/Surfaces/SurfaceMap.swift`; Create `T/PetScapeCoreTests/Physics/LandingTests.swift`;
  extend existing `T/PetScapeCoreTests/Surfaces/SurfaceMapTests.swift`.
- **Contracts:** internal `SurfaceMap.firstLanding(from: CGPoint, to: CGPoint, geometry: ContactGeometry,
  visualRange: ClosedRange<CGFloat>, tolerance: CGFloat) -> SurfaceContact?`;
  Create `S/PetScapeCore/Surfaces/SurfaceContact.swift` (surfaceID, position, fraction).
  Candidate result attachment/landedSurfaceID use existing SurfaceID/SurfaceAttachment.
- [x] Red tests `terminalDropsNeverTunnel` (10,000 seeded line crossings), `usesXAtImpact`
  (p0=(0,10), p1=(20,−10), surface at y=0 containing x=10 but not x=20), `firstHitWins`,
  `tieIndependentOfInsertionOrder`, `ascendingPassesThrough`, `narrowSurfaceRejected`,
  `exactBoundaryContactOnce`, `nonfiniteSurfaceIgnored`.
- [x] Run focused LandingTests/SurfaceMapTests; confirm new behavior fails, old lookup tests remain.
- [x] Implement linear candidate scan, epsilon clamp, stable kind/ID tie rule and whole-support interval;
  return exact foot y, zero contact velocity, discard remainder. No filter/sort allocations in hot sweep.
- [x] Run focused tests and shared gate; retain existing query semantics and annotate new query.
- **Accept:** AC-M7-01/07/08 helper subset; x crossing and tie results stable under reordered surfaces.
- **Risks:** accepting below/underside contacts or midpoint fallback on too-narrow surfaces; test rejection explicitly.
- **DoD:** shared gate + deterministic sweep reusable by both solver and live world.

### T7.3 — Persistent floor composition (S)

- **Objective/context:** keep a floor beneath a bottom Dock without lifting already floor-attached pets.
- **Dependencies:** T7.2. Refines original proposal of a new Platform ScreenEdgeSurfaceProvider;
  existing ScreenProvider already supplies geometry, so use Core floor construction instead.
- **Files:** Modify `S/PetScapeCore/Surfaces/SurfaceMap.swift`,
  `S/PetScapeRuntime/PetRuntime/PetRuntime.swift` (applySurfaces),
  `T/PetScapeCoreTests/Surfaces/SurfaceMapTests.swift`,
  `T/PetScapeRuntimeTests/PetRuntime/PetRuntimeTests.swift`.
- **Contracts:** public static `SurfaceMap.screenBottoms(for screens: [ScreenDescriptor]) -> [Surface]`;
  runtime merge preferred Dock walkway + hosted floor, unique SurfaceID. DockSurfaceProvider.surface,
  surfaces and hostScreenID retain current contracts. Pure builder supports all screens; runtime filters host.
- [x] Red tests `floorAndDockCoexist`, `fallbackFloorNotDuplicated`, `dockAdditionKeepsFloorAttachment`,
  `floorsRespectNegativeCoordinates`, `onlyHostFloorEntersWorld`, `noScreensProducesNoWork`.
- [x] Run focused tests; implement floor builder and merge without new observers or polling.
- [x] Keep spawnSurface Dock-first and M6 resettle behavior until T7.4 replaces lost-contact policy;
  verify old walk tests still pass, including same-ID reprojection.
- [x] Run shared gate (including runtime UI suite); document floor/provider contract.
- **Accept:** AC-M7-09; no unrelated multi-display flight feature.
- **Risks:** duplicate ID or accidental automatic lift; surviving attachment must win over spawn preference.
- **DoD:** shared gate + simultaneous floor/Dock, compatible still-walking app.

### T7.4 — Integrate the single world-owned physical state (L)

- **Objective/context:** replace walk position integration and surface-loss respawn with visible flight in existing FSM.
- **Dependencies:** T7.1–T7.3.
- **Files:** Modify `S/PetScapeCore/Pets/Pet.swift`, `S/PetScapeCore/Behavior/PetState.swift`,
  `S/PetScapeCore/World/PetWorld.swift`, `WorldEvent.swift`, `RenderSnapshot.swift` in World;
  Create `S/PetScapeCore/Behavior/GroundedState.swift`, `AirborneState.swift`;
  modify `S/PetScapeRuntime/PetRuntime/PetRuntime.swift` for exhaustive switches/logging and initial
  airborne-demand handling; extend world/snapshot/runtime tests in their existing directories.
- **Contracts:** Pet.velocity readable CGVector, existing Pet.position remains sole stored position;
  PetState `.grounded(GroundedState)` / `.airborne(AirborneState)` preserve walking/turning kinds for logs.
  GroundedState walking/turning/landing; AirborneState falling (M8 adds rising). Add WorldEvent
  `surfaceLost(PetID, SurfaceID)` / `landed(PetID, SurfaceID)`; runtime consumes exhaustively.
- [x] Red tests `walkingUsesOneDisplacement`, `turnStillHolds015Seconds`, `lostDockFallsVisibly`,
  `contactDoesNotRepeat`, `allStatesRespectFinitePosition`, `largeWorldDtHasNoEffects`.
  Replace 0.5 s test calls with 30 fixed calls retaining speed and rate expected outcomes.
- [x] Run focused tests red; migrate exhaustive switches in same slice; integrate MovementIntent →
  candidate → world commit; remove old walk displacement, reuse place/reproject recovery writers.
- [x] Add same-step landed→Landing, 0.10 s bounded settle→Walking; change snapshot visibility to
  valid grounded/airborne rather than attachment. Ensure initial falling demand runs until landing.
- [x] Run shared gate including runtime suite; audit all position assignments are in PetWorld.
- **Accept:** AC-M7-02/04/05/07/08/10; gravity without new sprites, walking preserved.
- **Risks:** exhaustive enum breaks, double movement, invisible flight, old respawn assertions becoming obsolete.
  Preserve test intent; explicitly replace ordinary surface-loss teleport expectations with fall/contact checks.
- **DoD:** shared gate + runnable gravity slice; no task leaves live airborne cats without frames.

### T7.5 — Movement intent, edges and contact-loss policy (S)

- **Objective/context:** preserve deterministic walking turns and distinguish real support loss from screen boundaries.
  Original task proposed random drops at Dock ends; unknown shelf extents make that unsupported. That
  subfeature is deferred to later finite-surface geometry/M9, not silently implemented.
- **Dependencies:** T7.4.
- **Files:** Modify `S/PetScapeCore/World/PetWorld.swift`, `S/PetScapeCore/Pets/Pet.swift`
  for the stable visual margin, and `S/PetScapeCore/Behavior/BehaviorTuning.swift` only if a named movement-policy constant is needed; extend existing PetWorldTests.
- **Contracts:** current nominalSpeed × speedScale × scale from walk/default definition, stable visual
  margin captured independently of active pose; no new random edge choice. Explicit unsupported x detaches.
- [x] Red tests `speedBothFacingsWithinFivePercent`, `hundredTurnsNoDrift`, `tailPoseDoesNotChangeEdge`,
  `supportLostOnce`, `narrowSupportDoesNotInventContact`, `sideDockStillTurnsAtScreenEdge`.
- [x] Implement missing policy guards; request hold/walk intent only, no new position writer.
- [x] Run focused tests and shared gate; record the original random-walk-off deferral in docs.
- **Accept:** AC-M7-05/08/12 plus existing AC-07/08/09; no random drop beyond a hosted screen.
- **Risks:** using fall art nominalSpeed or current anchor changes velocity/margins; always use resolved walk reference.
- **DoD:** shared gate + prior walking quality and explicit edge policy.

### T7.6 — Runtime frame-demand and Dock-side liveness (M)

- **Objective/context:** retain 2f7f33f invariant while decoupling simulation demand from snapshot visibility.
- **Dependencies:** T7.4–T7.5.
- **Files:** Modify `S/PetScapeCore/World/PetWorld.swift`, `RenderSnapshot.swift`,
  `S/PetScapeRuntime/PetRuntime/PetRuntime.swift`, `S/PetScapeRuntime/Overlay/OverlayCoordinator.swift`;
  extend `T/PetScapeRuntimeTests/PetRuntime/PetRuntimeTests.swift`, world/snapshot tests.
- **Contracts:** public read-only `PetWorld.needsSimulationSteps`, `needsAnimationFrames`;
  add `PetRenderState.isAnimating: Bool` (initializer default true preserves existing constructors),
  snapshot.isAnimating becomes any visible pet with this flag; world derives it from playback state,
  not physical/timer demand. Runtime sets needsFrames = OR, then existing RunStatus gate. Reset accumulator on demand stop,
  demand restart and host-driver replacement, not merely still sprite. No second driver/scheduler.
- [x] Strengthen existing `movingDockToASideKeepsFramesRunningUntilThePetResettles` for **both left/right**:
  assert driver active at removal, every airborne frame and landing; visible cat reaches floor within
  60 fixed steps, then walks. Rename test only to reflect falling, preserve regression intent.
- [x] Red tests `hiddenRecoverySnapshotStillNeedsSteps`, `heldFallFrameStillFalls`, `idleStillNeedsNoSteps`,
  `noSurfaceWaitsForNotification`, `driverReplacementHasNoCatchup`, `sideToBottomKeepsFloorContact`.
- [x] Implement demand policy and reset points; keep mask update after same published snapshot.
- [x] Run focused runtime/world tests and shared gate including UI suite.
- **Accept:** AC-M7-11/12/13/14, no invisible recovery stall and no polling.
- **Risks:** RunStatus running means permission rather than actual driver demand; avoid assuming it is enough
  for cursor idle monitoring. While demand is false and overlay visible, retain event-driven cursor monitoring
  through coordinator's effective-driver policy (test opaque-pixel pass-through without simulation frames).
- **DoD:** shared gate + liveness and static-energy/cursor behavior tested independently of art.

### T7.7 — Environment interruption and bounded recovery (M)

- **Objective/context:** extend current validation to all physical states; recover only when continuity is impossible.
- **Dependencies:** T7.6.
- **Files:** Modify `S/PetScapeCore/World/PetWorld.swift`, `S/PetScapeCore/Behavior/PetState.swift`,
  `S/PetScapeRuntime/PetRuntime/PetRuntime.swift`; extend PetWorldTests, PetRuntimeTests and
  `T/PetScapeCoreTests/Time/FixedStepAccumulatorTests.swift`. Modify
  `S/PetScapePlatform/Screens/ScreenProvider.swift` to add an injected screen-value reader defaulting to
  existing NSScreen behavior, only for deterministic environment integration tests.
- **Contracts:** same recover/place/resettle path; finite velocity/contact validation, host-bound recovery,
  3 s simulated airborne watchdog; at most one placement attempt per eligible step, no-surface wait.
  ScreenProvider initializer adds optional injected `@MainActor () -> [ScreenDescriptor]` reader;
  existing call sites unchanged. No new protocol solely for this test seam.
- [x] Red tests `pauseMidFallPreservesBody`, `sleepNoCatchup`, `changedSurfaceWhilePausedReconcilesFirst`,
  `removedHostRecoversOnce`, `invalidVelocityRecovers`, `airborneTimeoutBounded`, `noSurfaceNoRetryLoop`,
  `raisedSurfaceDoesNotCaptureFromBelow`, `sameIdResizeReprojects`, `seededReplayMatches`.
- [x] Implement guards and runtime resume/environment ordering. Reset time on frame stop/replacement;
  use synthetic descriptors for new runtime environment tests instead of relying on machine Dock settings.
- [x] Close shared gate with package/UI results and owner confirmation of remaining environment tests
  (2026-10-18). Individual manual logs/hardware details were not supplied; unavailable external hardware remains recorded.
- **Accept:** AC-M7-03/06/10/11/12/13/15; at most one recovery event per incident.
- **Risks:** invalid surfaces causing endless retries; no clock polling/watchdog outside simulated steps.
- **DoD:** shared gate + deterministic interruption coverage and accurate manual evidence.

### T7.8 — Presentation fallbacks and M7 verification gate (M)

- **Objective/context:** finish M7 with walk-only pack/placeholder; new art is optional, never a prerequisite.
- **Dependencies:** T7.7; separate owner art delivery only if integrating optional assets.
- **Files:** Modify `S/PetScapeCore/World/PetWorld.swift` animation policy as needed; extend
  `T/PetScapeCoreTests/Animation/AnimationControllerTests.swift`, PetWorldTests,
  `T/PetScapeRuntimeTests/Characters/CharacterLoaderTests.swift`, runtime tests; update performance/testing/
  milestones docs. Optional future manifest integration only when separately authorized; original art immutable.
- **Contracts:** Falling requests fall, Landing requests landing→legacy land→default; fallback held frame
  cannot affect physical timing; default walking still loops. Critical safety requests beat noninterruptible clips.
- [x] Red tests `noFallClipStillLands`, `missingLandingCannotBlock`, `placeholderFalls`,
  `invalidFrameUsesFallback`, `phaseEventsDoNotRepeat`, `noninterruptibleArtCannotBlockContact`.
- [x] Implement presentation resolution using CharacterDefinition/AnimationController, no counts hard-coded;
  request at phase entry, avoid repeated per-frame logging.
- [x] Close M7 verification by available automated/Release evidence plus explicit owner acceptance
  after reporting all remaining tests complete. Missing numeric signpost/wakeup/soak/leak-delta
  records remain evidence limitations, not invented measurements; see the owner closeout below.
- [x] Obtain owner visual approval and subsequent confirmation of all remaining M7/M8 tests;
  explicit owner-directed milestone closure, no tag/release.
- **Accept:** AC-M7-01…15, tests and measured budgets; see acceptance criteria for manual split.
- **Risks:** declaring missing art a milestone blocker or declaring planned tests executed; evidence must be real.
- **DoD:** shared gate + measurements/manual record + owner gate, M8 can rely on frozen contracts.

## M8 — Jumps & landings

Status: **Done, 2026-10-18: T8.1–T8.6 engineering/V4 delivered; visual result and remaining test closure accepted by owner.** Spec: [Jump System](../architecture/jump-system.md).
**Goal:** explicit safe vertical/short horizontal and reachable floor↔Dock jumps, with walk/idle return.
**Architecture/stack:** reuse M7 state/stepper/sweep/runtime and Core Animation; no animation-controlled force.
Shared T7/T8 constraints and quality gate above apply. Review focus: discrete solver error (T8.1),
changes at launch (T8.2), unreachable targets (T8.3), varying/missing art (T8.4), masks/asset memory (T8.5/6).

### T8.1 — Discrete jump planning and replay (M)

- **Objective/context:** meet ≤1 pt actual contact tolerance using M7 integration, not continuous parabola alone.
- **Dependencies:** M7 accepted; ADR-0017 approved.
- **Files:** Create `S/PetScapeCore/Physics/JumpTuning.swift`, `JumpPlan.swift`, `JumpSolver.swift`;
  Create `T/PetScapeCoreTests/Physics/JumpSolverTests.swift`.
- **Contracts:** `JumpSolver.solve(from:target:targetSurfaceID:surfaces:geometry:screen:physics:tuning:) -> JumpPlan?`
  as specified in Jump System; immutable plan contains initial velocity/predicted contact/time and captured
  geometry; no position storage or mutations. Max 120 candidate flight steps and 120 replay steps each.
- [x] Red tests `verticalReturnsWithinOnePoint`, `shortJumpBothDirections`, `raisedTargetReached`,
  `tooHighOrFarRejected`, `interveningSurfaceRejected`, `ceilingRejected`, `nanRejected`,
  `terminalClampDoesNotInvalidateAcceptedPlan` (accepted replay must still meet tolerance).
- [x] Implement bounded candidate equation + M7 replay, stable tie scoring; no runtime integration yet.
- [x] Run focused tests and shared gate; measure request-time worst case on the main thread.
- **Accept:** AC-M8-01/03/04/13/14 helper subset, predicted and executed paths share collision semantics.
- **Risks:** continuous/discrete mismatch or long planning hitch; reduce replay candidates if measured budget fails.
- **DoD:** shared gate + bounded safe planner, existing app still runs M7 behavior.

### T8.2 — Explicit jump execution and return intent (M)

- **Objective/context:** execute Walking/Idle → preparation → rising → falling → landing → prior activity.
- **Dependencies:** T8.1.
- **Files:** Create `S/PetScapeCore/Behavior/JumpRequest.swift`, `ResumeActivity.swift`;
  modify `S/PetScapeCore/Pets/Pet.swift`, grounded/airborne/PetState files, PetWorld/WorldInput/WorldEvent,
  `S/PetScapeRuntime/PetRuntime/PetRuntime.swift` exhaustive consumers; extend world/runtime tests.
- **Contracts:** public `WorldInput.requestJump(PetID, JumpRequest)`, `setActivity(PetID, ResumeActivity)`;
  proposed JumpRejection enum in JumpRequest file; add WorldEvent tookOff(PetID), apex(PetID),
  jumpRejected(PetID, JumpRejection), jumpCancelled(PetID). Store immutable active plan/return intent,
  consumed ID/cooldown, no second FSM. Runtime drops commands unless runState running.
- [x] Red tests `walkingJumpReturnsWalking`, `idleJumpReturnsIdle`, `oneTakeoffAndApex`,
  `duplicateRequestRejected`, `surfaceLossWinsOverLaunch`, `pausePreparationFreezesTimer`,
  `targetChangedDuringSleepCancelsBeforeLaunch`, `cooldownFrozenWhilePaused`, `idleLoopAtThirtyHzKeepsSimulationTime` (explicit 30/15 Hz
  callbacks advance correct phase time within one step, held Idle stops driver).
- [x] Integrate simulation deadline (0.15 s), phase/contact transitions and 0.10 s Landing;
  add idle hold and explicit work demand for timed phases, 60 fps while physical/timed and
  30 fps for a real grounded idle loop (held idle stops); no M9 selector/menu.
- [x] Run focused tests and shared gate including UI suite; default still walks without jump command.
- **Accept:** AC-M8-02/05/06/07/08/09/10/11/12 execution subset.
- **Risks:** duplicate event launches, stale target, priority blocking; guard before every commit.
- **DoD:** shared gate + full deterministic jump/return cycle and interruption handling.

### T8.3 — Target eligibility and Dock transitions (M)

- **Objective/context:** only current-host same-surface/floor↔Dock targets in approved envelope.
- **Dependencies:** T8.2.
- **Files:** Modify `S/PetScapeCore/Physics/JumpSolver.swift`, `S/PetScapeCore/World/PetWorld.swift`;
  extend JumpSolverTests/PetWorldTests/runtime tests. No new Platform target discovery.
- **Contracts:** JumpRequest target SurfaceID + targetX validated at request and launch; reject outside
  logical support/stable screen envelope, >80 pt horizontal / >120 pt apex rise, unknown or removed IDs.
- [x] Red tests `floorToDock`, `dockToFloorOnlyWhenFirstHitIsFloor`, `dockReappearsNoAutomaticLift`,
  `dockLeftAndRightCancelTargetButKeepFalling`, `hostChangeUsesExistingRecovery`,
  `resizeDuringFlightDoesNotTeleport`, `noNonHostTarget`, `noUnreachableRetryLoop`.
- [x] Implement eligibility/current geometry comparison and invalidate plan once; after flight changes,
  use M7 sweep on current surfaces, preserve velocity. Reject impossible Dock→floor jump where full-width
  Dock is first hit; do not bypass collisions to make a target reachable.
- [x] Run shared gate including runtime suite and synthetic geometry scenarios.
- **Accept:** AC-M8-10/11/13/14; no window jumps/climbing or fabricated Dock shelf ends.
- **Risks:** full-width Dock prevents some floor targets; safe rejection is required, not a failed feature.
- **DoD:** shared gate + explicit reachability/cancellation results.

### T8.4 — Simulation-to-animation mapping (S)

- **Objective/context:** replaces the original T8.4 art-frame-driven impulse plan under D8/ADR-0017.
- **Dependencies:** T8.2–T8.3; no new sprites required.
- **Files:** Modify PetWorld animation policy, existing AnimationController/CharacterDefinition only if
  needed for alias lookup; extend AnimationControllerTests/PetWorldTests/CharacterLoaderTests.
- **Contracts:** semantic requests idle/jump-start/jump/fall/landing; valid legacy jump-air/land resolution;
  missing clip holds default as specified; frame markers never mutate physics or state timers.
- [x] Red tests `sameTrajectoryForVariableFrameCounts` (1/8/12/24/32), `noTakeoffMarkerStillLaunches`,
  `duplicateTakeoffMarkerCannotLaunchTwice`, `loopingFallbackCannotHoldLanding`,
  `contactStartsLandingSameStep`, `legacyAliasesAndMissingFramesResolve`.
- [x] Implement entry-only critical requests then normal grounded priority, rate reset to 1 outside walk;
  avoid physics phase `next` chains. Hold fallback pose without freezing phase timers.
- [x] Run shared gate; assert exact body/state timing equality across fixture packs.
- **Accept:** AC-M8-02/09/15/16; no schema edit, art determines appearance only.
- **Risks:** walk's spawn priority remains 90, controller refuses ordinary transitions, or automatic next changes
  pose prematurely; test explicit priority restoration and every phase cut.
- **DoD:** shared gate + art-independent motion and compatible current pack.

### T8.5 — V4 production integration and owner calibration (M, delivery-dependent)

- **Objective/context:** preserve identity/anchors. Owner separately authorized V4 production and integration on 2026-10-18; revision 1 is implemented and its delivered visual result was approved by owner on 2026-10-18. Owner subsequently confirmed all remaining M7/M8 tests and requested closure (2026-10-18).
- **Dependencies:** T8.4; owner-authorized V4 generation/integration and approved ≤16 MiB budget. Provenance is recorded; redistribution license D-08 remains required before public distribution.
- **Files:** New clips under `assets/characters/cat/<new-clip>/`, additive `character.json`,
  `v4/` production metadata/sheets, offline exporter and V4CharacterPackTests. Existing
  preview, manifest, texture, geometry and mask suites remain in place.
- **Contracts:** additive schema v1 clips, no original frame/atlas edits; valid regex, cycle-free aliases;
  512 px source /96 pt display / shared virtual anchor; 28 recommended new frames are not a code requirement.
- [x] Close [V4 production QA/integration](../specifications/animation-assets-v4.md) using actual-art
  automated evidence, previews, owner visual approval and subsequent test confirmation. Optional atlas not needed; D-08 remains a distribution decision.
- [x] Actual revision 1 pack validated/decoded, shared anchor and baseline checked, 10,616,832 decoded bytes; individual PNG delivery, no atlas needed. Original walk-only ≤3 MiB gate retained.
- [x] Add authorized pack data, run shared gate including UI suite; generate light/dark, both-facing actual-simulation and independent-clip previews.
- [x] Owner approves the delivered V4 visual result (“está aprovado”, 2026-10-18).
- [x] Accept native calibration by owner test confirmation; no per-scale recording supplied.
  Asset redistribution license D-08 remains a project distribution gate, outside M7/M8 implementation.
- [x] Owner accepts delivered tuning/visual result and reports all remaining tests complete.
  Existing tuning is unchanged; no recording or Screen Recording request is required for owner acceptance.
- **Accept:** AC-M8-15/16 visual subset, V4 identity/alpha/bbox/alignment and owner review.
- **Risks:** memory >MVP image budget, see-through body, art/physics timing mismatch; reject delivery or
  adjust measured texture/frame budget with owner, no silent size/proportion change.
- **DoD:** shared gate + approved asset revision/measurements and visual evidence; core M8 remains testable with fallbacks.

### T8.6 — M8 regression, performance and acceptance gate (M)

- **Objective/context:** close physics/jump acceptance without assuming platform or visual results from tests.
- **Dependencies:** T8.1–T8.4; T8.5 for V4 visual sign-off (or explicit owner art deferral).
- **Files:** Existing runtime/world/animation tests and docs/development/testing.md,
  docs/specifications/performance.md, milestones/acceptance evidence; no new testing framework.
- **Contracts:** all regression rows/AC-M8-01…18 have evidence or explicit owner-accepted exception.
- [x] Run shared gate and full deterministic scenarios, including both Dock sides, auto-hide during flight,
  airborne pause/resume, source/target loss, invalid assets, and recovery-demand invariants.
- [x] Close manual interaction/environment gate by owner report of all remaining M7/M8 tests
  and explicit acceptance. No per-point count, recording or additional hardware claim is inferred.
- [x] Accept milestone performance/test closure using recorded Release measurements and owner
  confirmation. Unrecorded metrics/soak duration and paused CPU variability are retained as evidence
  limitations in performance.md; no claim that every numeric target was independently measured.
- [x] Record results/gaps, owner decisions and status; no automatic release/commit/tag or M9 implementation.
- **Accept:** AC-M8-01…18 and retained MVP non-interference/energy/privacy gates.
- **Risks:** visual/demo absence mistaken for success, hardware gaps or >20% unexplained regression.
- **DoD:** shared gate + measured/observed evidence and owner sign-off, next milestone separately authorized.


### Execution evidence (2026-10-18)

Owner instruction: proceed through all tasks without pauses. T7.2–T7.6 and T8.1–T8.4 engineering
is implemented. T7.7/7.8 and T8.6 have automated coverage and recorded measurements. The owner
subsequently confirmed all remaining M7/M8 tests and explicitly requested milestone closure;
see [owner closeout](m7-m8-technical-review.md#owner-m7m8-closeout-2026-10-18) for evidence limitations. Earlier the owner explicitly selected V4
production/integration. T8.5 revision 1 now adds 24 generated frames, an additive v1 manifest,
source/prompts/exporter/checksums and actual-art QA; original walk assets are unchanged.
See the [production record](../../assets/characters/cat/v4/README.md) for previews and owner visual approval. Native test closure is accepted by the subsequent owner report.

| Tasks | Implemented and verified evidence |
|---|---|
| T7.2 | LandingTests: 10k seeded terminal drops, x at impact, ascending/unsupported rejection, exact contact, all six permutations of near-equal height chains. Two linear scans anchor ties to the highest eligible crossing. |
| T7.3 | SurfaceCompositionTests + runtime composition: host floor/Dock coexist, negative origins, unique IDs, no lift when Dock appears. Existing ScreenProvider reused. |
| T7.4/7.5 | PhysicsWorldTests + retained PetWorldTests: one displacement, visible falls/contact, bounded Landing, both facings, nominal speed, 100 turns; nonzero walk frame preserved after Turning, stable walk anchor/speed independent of fall pose. Old teleport assertions replaced with physical fall/no-respawn checks; large-dt distance tests use fixed steps. |
| T7.6/7.7 | Runtime/world tests: both Dock sides, pause mid-flight, paused geometry refresh, replaced driver reset, invalid velocity/contact, watchdog/no-surface wait, hidden recovery liveness, held Idle support loss and invalid-body wake. Cursor monitoring follows effective driver demand. |
| T7.8 | Current walk-only/default fallbacks and physical-phase animation tests: missing art cannot stop falling/timers; phase `next` cannot escape physical state; placeholder/invalid-file loader regressions retained. |
| T8.1 | JumpSolverTests: vertical, both short directions, raised/blocked/unreachable/ceiling/invalid targets. Optimized request-cost measurement in performance.md; same discrete stepper and sweep as execution. |
| T8.2/8.3 | JumpWorldTests/runtime tests: one impulse/apex/contact, walk/idle return, duplicate/busy/cooldown rejection, source loss at launch, changed target in flight, actual endpoint error≤1 pt, raised surface rejection. Launch re-solves against current ceiling/all surfaces; unrelated changes leave the body and accepted plan unchanged. |
| T8.4 | JumpAnimationTests: exact trajectories/timings with 1/8/12/24/32 frames and absent art, duplicate markers, legacy aliases, priority/rate restoration and same-step contact art. Real idle loops tested with 15/30 Hz callbacks. |
| T8.5 | Existing synthetic 1/8/32-frame compatibility tests retained. V4CharacterPackTests load actual 24 new frames without fallback, test identical art-independent physics, opaque silhouettes, soft-alpha border and individual planted contacts. Reviewer foot-drift/border findings reproduced RED then fixed. Actual decoded total 10.125 MiB; 361 package tests + UI, lint, Debug/Release pass. Owner approved the delivered visual result on 2026-10-18; remaining test closure accepted by owner report. |
| T8.6 | Full package/UI tests, lint, Debug/Release builds, independent review and accelerated deterministic stress run. Measurements and remaining manual gates are recorded in performance.md and testing.md. |

Independent review found held-Idle liveness, stale launch environment and nontransitive epsilon ties;
all reproduced RED and fixed. Follow-up found needless reprojection rounding after an unrelated
surface addition; a RED launch-continuity test now guards it, and only moved attached surfaces reproject.
All executable changes stay uncommitted. This is the M7/M8 execution record; M9 was subsequently
reauthorized below.

## M9 — Autonomous behaviors & Settings v1

**Done by explicit owner acceptance, 2026-10-18.** Implementation, package/build gates and both UI tests passed. Real login-item action, native cadence and installed-app playtest remain unverified evidence limits recorded in the [owner closeout](m9-implementation.md#owner-m9-closeout-2026-10-18). The owner closed M2/M3/M5/M6
and instructed full M9 implementation through completion without per-task approval stops.
Follow the [concrete plan](m9-implementation.md) and accepted [Behavior Engine](../architecture/behavior-engine.md).

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T9.1 | `Needs` model and drift rules | Core | M7 | S | U |
| T9.2 | `Personality` from manifest with defaults | Core | T9.1 | S | U |
| T9.3 | `ActivitySelector`: eligibility/cooldown filtering + simple weighted choice (accepted ADR-0018) | Core | T9.2 | M | U (seeded scenarios) |
| T9.4 | Resting states: sit-down/sit/stand-up, lie-down/sleep/wake-up | Core | T9.3 | M | U |
| T9.5 | Expressive states: stretch, look-around | Core | T9.3 | S | U |
| T9.6 | Cooldowns, novelty, stuck detection | Core | T9.3 | S | U |
| T9.7 | Render rate per state (sleep at animation fps) | Run | T9.4 | S | Man + CPU check |
| T9.8 | Settings window: size, speed, behavior toggles, restore defaults, Advanced › Dock offset; preferences versioning | App, Plat | T9.3 | L | UI + U |
| T9.9 | Launch at login (`SMAppService.mainApp`) with status display | Plat, App | T9.8 | S | Man |
| T9.10 | Playtest (≥ 2 h) and tuning notes | Docs | T9.4–T9.7 | S | Notes recorded |

## M10 — Cursor interaction & dragging

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T10.0 | Isolated native routing/focus PoC; owner go/no-go | Docs, native spike | Owner authorization | M | Man + measurements |
| T10.1 | Shared cursor/primary-button values and monitor lifecycle | Core, Plat, Run, Rend | T10.0 accepted | S | U |
| T10.2 | Bounded cursor observation in existing HSM; approach/startle deferred | Core, Run | T10.1 | M | U |
| T10.3 | Drag parent task, completed only by both slices below | Core, Run, Rend | T10.3a/b | — | U + Man |
| T10.3a | Target/sequence acquisition, press reservation, selected native capture | Core, Run, Rend | T10.1, native topology approval | M | U + Man |
| T10.3b | ≥4 pt pickup, preserved offset, world-owned held body | Core, Run | T10.3a | M | U + Man |
| T10.4 | Zero-impulse release → existing falling/contact/landing | Core, Run | T10.3b | S | U + Man |
| T10.5 | Primary click/hover; bounded reaction or explicit wake | Core, Run | T10.3a, T10.2 | S | U + Man |
| T10.6 | Lifecycle/settings parent, completed by both slices below | All | T10.6a/b | — | U + Man |
| T10.6a | Cancellation before teardown, lost primary-up, host/Dock changes | Core, Plat, Run | T10.2/3b/4/5 | M | U + Man |
| T10.6b | Two toggles, preference v3, Reduce Motion/VoiceOver | Core, Plat, Run, App | T10.6a | M | U + UI + Man |
| T10.7 | Produce minimum V5 art, separately authorized | Assets | Owner art authorization | M | Art QA + owner |
| T10.8 | Optional V5 integration, safe missing-art replay | Core, Run, Assets | T10.6b, approved art for real integration | S | U + Man |
| T10.9 | Regression/performance/soak and owner acceptance | All, Docs | T10.6b, T10.8 or explicit V5 deferral | M | All |

**2026-10-18 planning revision, not implementation:** executable details, exact files/interfaces,
RED/GREEN steps, risks and DoD live in [m10-implementation.md](m10-implementation.md).
Original T10.1–6 IDs are retained. T10.4 historically required a throw estimator; the current brief
explicitly makes impulse optional/future, so its first-delivery task is zero-velocity drop.
T10.2 approach/startle locomotion is deferred; T10.6 resolves paused dragging as disabled to
preserve the no-step paused contract. No native PoC, Swift, tests or assets changed in planning.

## M11 — Edge climbing

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T11.1 | Wall surfaces (screen left/right) | Core, Run | M8 | S | U |
| T11.2 | Climbing motion mode and states; alignment-aware rendering (authored orientation, mirroring, anchor) | Core, Rend | T11.1 | L | U + Man |
| T11.3 | Transitions: walk into wall → climb; climb to height → descend or drop | Core | T11.2 | M | U |
| T11.4 | `climb` art integration (2-frame loop) | Assets | T11.2 | S | U + Man |

## M12 — Window detection

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T12.1 | Spike: CGWindowList fields without permission; AX move notifications during drags; AX↔window correlation by PID+frame; costs. Update window-tracking.md (+ ADR) | Docs | M7 | M | Findings doc |
| T12.2 | `AccessibilityPermission` + Settings toggle with explanation and System Settings deep link | Plat, App | T12.1 | M | Man |
| T12.3 | CGWindowList adapter (`QuartzRect` → canonical), filters | Plat | T12.1 | S | U (fixtures) |
| T12.4 | AX observer adapter (frontmost app + ridden window), messaging timeout | Plat | T12.2 | M | Man |
| T12.5 | `CompositeWindowTracker` (implements `WindowTracker`) combining sources; throttling; lifecycle bound to run state and feature flag | Plat, Run | T12.3, T12.4 | M | I + CPU check |
| T12.6 | `WindowSurfaceBuilder`: visible top segments by z-order, clipping to screens/menu bar | Core | T12.3 | M | U |
| T12.7 | DEBUG surface visualization | Rend | T12.6 | S | Man |
| T12.8 | Revocation handling and status in menu/Settings | Plat, App | T12.5 | S | Man |

## M13 — Window interaction

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T13.1 | Window surfaces in `SurfaceMap`; spawn/land on windows | Core, Run | M12 | S | U |
| T13.2 | Riding moving windows; teleport detach threshold | Core | T13.1 | M | U + Man |
| T13.3 | Window closed/minimized/app hidden → fall | Core | T13.1 | S | U + Man |
| T13.4 | Jumps between windows (targets include window tops) | Core | T13.1, M8 | M | U |
| T13.5 | Occlusion changes (window raised over the pet's segment) → detach | Core | T13.1 | S | U |
| T13.6 | Performance validation with tracking enabled | All | T13.1–T13.5 | S | Measurements entry |
| T13.7 | Autonomous window excursion: randomly choose a visible window, jump to an exposed side below its top, climb the side, walk on its top, then jump back to Dock | Core, Run | T13.1–T13.5, M11 | L | U + Man |

### M13 implementation evidence (2026-10-23)

- Implemented: host-screen visible window surfaces enter `PetWorld` through `PetRuntime`; spawn and
  swept contacts use logical body width; same-ID move/resize reprojects the attachment; translated
  samples above the documented speed/gap guard drop that window's support; moved occlusion boundaries
  invalidate covered support; window destinations use the existing `JumpSolver` and return phases.
- Automated coverage added for window spawn, undersized support rejection, move/resize re-projection,
  support removal with one continuous fall, occlusion detach-once, jump landing on a window, segment
  identities, and deterministic teleport classification. T13.7 adds visible-side clipping, bounded
  jump-to-side solving, reuse of M11 climbing, randomized visible-window selection, top walking and a
  Dock return jump. New seeded coverage exercises the complete excursion and selection across multiple
  windows. Existing package regressions are retained.
- Verification (2026-10-23): `make lint` passed; `make test-core` passed (309 Core tests plus the
  Runtime, Platform and Rendering package suites); `make test` passed (package suites and 2 UI tests);
  `make build` passed. No warning was introduced by the changed code. Xcode emitted its existing
  AppIntents metadata-extraction warning during UI-test build; build also reports multiple matching
  macOS destinations and selects the arm64 host.
- **Owner closeout (2026-10-23):** The owner confirmed M13 behavior and tests are validated and accepted
  closure, including native validation of window interaction and the autonomous climb/return flow. The
  owner accepts the documented ≤2 Hz tracker cadence and lack of paired Release CPU measurements for
  this milestone. The existing Debug sample remains exploratory and no new quantitative result is
  claimed; see the [M13 closeout](milestones.md#m13-owner-closeout--2026-10-23),
  [performance record](../specifications/performance.md#m13-tracking-measurements),
  [window-tracking contract](../architecture/window-tracking.md#m13-interaction-behavior) and
  [ADR-0023](../decisions/0023-window-interaction-cadence.md).

## M14 — Multi-display, optimization & stabilization

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T14.1 | Overlays on all screens; pet hand-off between overlays; single `FrameDriver` (display link) | Run, Rend | M13 | L | Man (2 displays) |
| T14.2 | Mixed-DPI texture policy check | Rend | T14.1 | S | Man |
| T14.3 | Render interpolation if 120 Hz judder is measured | Run, Rend | T14.1 | S | Man + measurement |
| T14.4 | Lazy clip loading by behavior family; strip unreferenced pack files from the bundle | Rend, App | M9 | M | Memory measurement |
| T14.5 | 8 h soak, Leaks, memory growth | All | T14.1 | S | Report |
| T14.6 | macOS 14 VM manual matrix | All | T14.1 | M | Matrix |
| T14.7 | VoiceOver/keyboard audit of menu and Settings | App | M9 | S | Checklist |
| T14.8 | Performance regression checks (XCTest `measure` for step cost; signpost review) | All | T14.1 | S | CI/local results |

## M15 — Animation quality

| ID | Task | Mod | Deps | Size | Verify | Status |
|---|---|---|---|---|---|---|
| T15.1 | Inventory all manifest clips and establish frame/timing decisions | Docs, Art | M14 | M | AC-M15-01; per-clip review | **Done**; see [inventory](m15-implementation.md) |
| T15.2 | Produce versioned, distinct in-between art for clips where the inventory justifies it | Art | T15.1 | L | AC-M15-02; source QA and provenance | **Done by owner acceptance**; final 134-frame pack; V7/V8 production and retained pixel-QA exception recorded |
| T15.3 | Integrate approved frames; update counts/FPS/events while preserving duration and contracts | Pack | T15.2 | M | AC-M15-03/04; schema, references, tests | **Done**; final 134 references, owner-authorized timing rework and contracts recorded |
| T15.4 | Build clip previews and inspect changed clips/transitions at runtime timing | Art, Runtime | T15.3 | M | AC-M15-05; recorded visual results | **Done by owner acceptance**; owner confirmed revised animations and final pacing tests |
| T15.5 | Record asset provenance, evidence, limitations and closeout | Docs | T15.4 | S | AC-M15-06; owner review | **Done**; final V8 visual follow-up accepted 2026-10-25; exact hashes/48 known findings retained, historical release waiver retired |
| T15.6 | Owner pacing refinement: rare stops ≤5 s and faster configurable walking, preserving approved art | Core, Settings | T15.4 | M | Seeded pacing/landing/speed tests; build/lint/UI | **Done**; Core/UI/build/lint pass; pre-existing V8 pixel-QA failure documented |

## M16 — New behaviors and animations

**Done by explicit owner acceptance, 2026-10-24.** T16.1–T16.10 scope is delivered; remaining
native/performance measurement limits are accepted as documented, not newly measured passes.
Contract, file responsibilities, task evidence and Git authorization:
[M16 owner closeout](m16-implementation.md#owner-m16-closeout--2026-10-24).

| ID | Task | Module | Verify |
|---|---|---|---|
| T16.1 | Define session/priority/cleanup/art contracts | Docs | AC-M16-01 |
| T16.2 | Session hysteresis; bounded automatic/manual dance | Core | AC-M16-02…05 |
| T16.3 | Eligible descending Dock contact → stable cleanup | Core | AC-M16-06 |
| T16.4 | Local system audio classifier and lifecycle | Platform, Runtime | AC-M16-07/08 |
| T16.5 | Consent, persisted opt-in, manual menu/Settings control | App, Runtime | AC-M16-09 |
| T16.6 | Art briefs and integration handoff, no images | Docs | AC-M16-10 |
| T16.7 | Regression gates and honest evidence/status | All | AC-M16-11 |
| T16.8 | Owner supplies V9 art; integrate real clips, complete native/visual/performance acceptance | Owner, Pack, All | AC-M16-07…11; V9 art delivered and integrated 2026-10-23 (V8 rig, owner-approved; pack tests added); **Done by owner acceptance 2026-10-24**, with measurement limits retained |
| T16.9 | Owner follow-up: emit real audio usage-description key, preserve first session after startup/failure, clean after held drop onto Dock/screen ground | App config, Core, Platform | Artifact key gate, red/green music/drop regressions, lint/build/UI; owner confirmed all behavior working at closeout; detailed native evidence limits retained |
| T16.10 | Owner-requested Stop Dance in normal menu and Settings, with live availability and consumed-session preservation | Core, Runtime, App | Manual/automatic stop and non-dance guards; model availability; native UI |

## M17 — Portuguese and English localization (authorized 2026-10-24)

| ID | Task | Modules/files | Verification |
|---|---|---|---|
| T17.1 | Inventory product strings, metadata, model/service statuses, M16/M18 surfaces; establish translation rules | App, Runtime, Platform, catalog, InfoPlist, Docs | Complete source audit and resource inventory |
| T17.2 | Resolve the first supported macOS preferred language (`en`, `pt-BR`); route other Portuguese variants to `pt-BR`, otherwise English; observe locale changes | Platform, App | Deterministic ordered-preference tests; notification/update test where supported |
| T17.3 | Translate menu, Settings, consent/privacy, help/accessibility, debug-visible UI, bundled Cat name and app identity | App, String Catalog | Catalog validation, both locale UI assertions and manual layout review |
| T17.4 | Keep Runtime/App status and character-selection errors semantic until rendered; localize login errors; preserve diagnostic logs | App, Runtime, Platform | Model and UI locale tests; no UI error rendered from process-default `localizedDescription` |
| T17.5 | Localize audio usage text and configure source language, supported regions and target resources | Xcode project, Config, Resources | Debug/Release bundle inspection for catalog and `InfoPlist.strings` |
| T17.6 | Add regression coverage for selection, locale changes, M16/M18 copy and fallback behavior | Platform, Runtime, UI tests | `make lint`, `make test-core`, UI tests, Debug/Release builds and catalog checks |
| T17.7 | Record real verification results, visual/accessibility limits and owner follow-up without changing M15/M16/M18 closeouts | Planning, testing docs | Closeout inventory and exact manual matrix |

## M16–M19 — Planned product milestones

| ID | Scope | Boundary for M15 |
|---|---|---|
| M16 | New autonomous behaviors and animations, including music-associated dancing and cleanup after certain landings | No behavior or new clip implementation in M15 |
| M17 | Portuguese and English localization with automatic language detection | No localization implementation in M15 |
| M18 | Selection among characters bundled in the app | No selector implementation in M15 |
| M19 | Discovery and installation of character packs | No pack discovery/installation implementation in M15 |

## M18 — Bundled character selection (authorized 2026-10-24)

**Done by explicit owner acceptance, 2026-10-24.** The owner accepted generic engineering with
one real bundled cat, deferred AC-M18-08 and retained native/V8/performance limits, then authorized
branch creation, commit and local merge into develop. This does not claim two real characters or
passing native UI tests. See the [closeout](milestones.md#owner-m18-closeout--2026-10-24).

Design and execution checklist: [M18 register](milestones.md#m18--bundled-character-selection).
M17 localization was completed separately. M19 external discovery/installation has separate
authorization and its own scope below.

| ID | Task | Modules/files | Verification |
|---|---|---|---|
| T18.1 | Inventory actual bundled characters and document M17 dependency | AppContainer, copy script, planning | Only complete immediate pack roots count |
| T18.2 | Bundle catalog and full resource validation; reject duplicate stable IDs | Runtime/Characters: BundledCharacterCatalog, CharacterLoader | Real cat plus isolated malformed/missing/duplicate fixtures; retained lazy bytes |
| T18.3 | Observable transaction, persist/restore/fallback, cancellation | CharacterSelectionModel; Platform/Preferences | Zero/one/many, restart, unknown ID, load failure and late task tests |
| T18.4 | Atomic safe swap preserving contact and settings | Core/PetWorld; Runtime/PetRuntime | Supported swap, busy rejection, geometry fit, paused/hidden, old snapshots/events/masks |
| T18.5 | Native accessible Settings integration through composition root | AppContainer, SettingsModel, SettingsView | Single real Cat text; native keyboard/AX assertions, model multi-option tests |
| T18.6 | Gates and owner handoff | Planning/criteria; build evidence | Lint, package/UI, Debug/Release, asset validation; preserve V8 exception |

## M19 — Character pack discovery and installation (authorized 2026-10-24)

**Authorization:** the owner explicitly requested end-to-end M19 implementation on 2026-10-24.
The owner later accepted M19 closure and explicitly authorized branch creation, a commit, and local
merge into `develop`. At that closeout, this did not authorize M20, network discovery, publishing, pushes, tags,
releases or PRs. The accepted real-pack/manual evidence limits are in the [owner closeout](milestones.md#owner-m19-closeout--2026-10-24).

**Flow and contract:** the user chooses a local pack **folder** with root `character.json` using the
native folder picker. Schema v1 and the existing validator remain authoritative. Import copies only
the root manifest and referenced PNG resources to
`~/Library/Application Support/PetScape/Characters/<id>`. ZIPs are unsupported. Unreferenced files
are ignored and not copied or executed. The source tree is bounded and inspected for symlinks,
aliases and special files; referenced paths are read without following links.

The external-pack profile caps the manifest at 256 KiB; source trees at 2,048 entries and depth 32;
the manifest at 64 clips, 512 frame entries and 64 sheets; sheet grids at 16×16; unique referenced
PNG files at 256; individual/aggregate referenced file bytes at 4/64 MiB; source image dimensions
at 4,096×4,096; target decode side at 768 px; and estimated aggregate decoded image bytes at
64 MiB. These caps cover the current 200-frame cat pack's referenced resource size and maximum
runtime decode target. Imported art still has no native performance approval or guarantee.

Install uses a same-volume staging directory and exclusive atomic promotion to `<id>`. It validates
the source snapshot and staged copy. IDs must match the existing identifier rule, remain unique
against bundled and installed characters, and the installed folder name must equal the manifest ID.
Duplicate IDs and existing destinations are rejected; M19 has no update/overwrite or in-app remove
flow. Users can remove an installed folder in Finder while PetScape is quit; the next launch
rediscovers the catalog and uses M18's successful-application fallback policy. External edits are
seen on the next launch. No bookmarks are kept.

| ID | Task | Modules/files | Verification |
|---|---|---|---|
| T19.1 | Record the folder format, source-of-truth, file access, removal/update/fallback policy, security boundaries and resource caps | Planning, asset-format, permissions, setup, testing | Docs agree with M18/FR-44 and current asset budget |
| T19.2 | Read selected folders safely; validate schema, all declared resources and bounded PNG metadata; write sanitized staging and promote atomically without overwrite | Runtime/Characters, Rendering/ImageDecoder | Temporary-directory tests for path, link, file-type, byte, frame, dimension, duplicate and failure cases |
| T19.3 | Discover immediate installed pack folders; combine valid installed and bundled entries with stable origin labels and unique IDs | Runtime/Characters, AppContainer | Isolated catalogs, corrupt/duplicate external entries, bundled isolation and fallback |
| T19.4 | Add localized Settings folder import, progress/result/error states and installed source labels; retain M18 transactional selection | App, Runtime, String Catalog | English/pt-BR UI/model assertions; cancellation and failed import preserve selection |
| T19.5 | Add adversarial/import/selection regression coverage, update user docs and record lint, test, build, validator and manual evidence | Tests, docs, all touched modules | `make lint`, `make test-core`, UI tests, Debug/Release builds, pack validator and manual matrix |

## M20 — Settings redesign & multiple active characters (authorized 2026-10-25; implementation complete, in review)

| ID | Task | Modules/files | Deps | Verify | Status |
|---|---|---|---|---|
| T20.1 | Audit current Settings controls, selection/import flows, preference keys, runtime pet ownership, menu actions, renderer caches, localization catalog and performance budgets; record current behavior to preserve | App, Runtime, Core, Platform, Rendering, Docs | M17–M19 accepted | Inventory maps every current control/action/status/permission and existing contract; no feature is silently dropped | Done |
| T20.2 | Design and implement a complete native Settings information architecture and visual refresh; retain every current setting, consent/status/error/import state, localization and accessibility identifier or update its tests deliberately | App, String Catalog, UI tests | T20.1 | English/pt-BR assertions, keyboard traversal, VoiceOver labels, long-copy layout and full manual review | Accepted: native sections and long copy reviewed at default size; keyboard/VoiceOver and supported-minimum resize remain unverified |
| T20.3 | Introduce a persisted active-character roster with one entry per stable character ID; migrate `petscape.selectedCharacterID`, preserve selection and default/Restore Defaults semantics, and recover safely from missing/unknown/invalid IDs | Platform/Preferences, Runtime/Characters | T20.1 | Store migration, round-trip, restore-defaults, duplicate and invalid-entry tests | Done: migration, empty roster and recovery covered; Restore Defaults manually reviewed with isolated preferences |
| T20.4 | Replace character replacement-only lifecycle with add/remove-one-character lifecycle while preserving each existing pet's position, state, interaction and pending event correctness; reject duplicate active character IDs and make requested removal safe in every pet phase | Core/PetWorld, Runtime/PetRuntime | T20.3 | Core lifecycle tests for zero/one/many, duplicate ID, removal while dancing/held/falling/climbing/window-bound, snapshots/events and continued operation of remaining pets | Done: roster and scoped-removal tests pass; native removal of Cat preserved Dimas |
| T20.5 | Make character loading/rendering/behavior-family ownership multi-pet and keyed by pet/character identity; clean up per-pet resources and stale tasks on removal; keep renderer snapshots and hit-testing unambiguous | Runtime, Rendering, character loaders/caches | T20.4 | Runtime/render tests with dissimilar definitions and frame counts; remove/re-add, async completion, hit-test and cache-lifecycle regressions | Done: automated runtime/render suites passed; native per-pet visual output was inspected |
| T20.6 | Make behavior and interaction state independent per pet, including seeded autonomous choices/timers, dance eligibility and duration, manual Dance/Stop Dance targeting, cleanup, hold/drag and window excursions; fan out shared environment signals without mirroring pet state | Core, Runtime, App/menu and Settings models | T20.4–T20.5 | Deterministic tests prove different pets can occupy different states/timings and one pet's action/removal/cancellation does not alter another; automatic music and manual actions target eligible pets correctly | Done: deterministic/runtime tests pass; native Dance/Stop Dance and single-pet removal were reviewed |
| T20.7 | Add accessible active-roster management in Settings: each active pet has an individual Remove action and per-pet Dance/Stop Dance where applicable; inactive catalog characters can be added; duplicates are disabled; source, loading, empty and error states remain clear/localized | App, Runtime/Characters, String Catalog, UI tests | T20.2–T20.6 | UI/model tests for zero/one/many bundled and installed packs, add/remove, duplicate prevention, import then add, restart persistence and status/error states | Accepted: isolated native install/add/remove, localization and 7 XCUITests passed; native VoiceOver/keyboard review remains unverified |
| T20.8 | Evaluate aggregate active-pack resource use, add safe lazy loading/release or an evidence-based accessible cap if needed, and document measured results and tradeoffs | Runtime, Rendering, tests, performance docs | T20.5 | Repeatable profile/test across representative simultaneous packs; compare to existing targets; no unsupported performance claims | Accepted with limit: Core step and decoded-frame measurements recorded; matched native Release CPU/process footprint remains unverified; no arbitrary cap added |
| T20.9 | Complete regression gates, manual matrix, docs, milestone status and honest evidence closeout | All touched modules, docs/planning, docs/development/testing.md | T20.1–T20.8 | `make lint`, `make test-core`, `make test`, `make build`, Release build, asset validation; owner-facing Settings/VoiceOver/visual checklist and exact unverified evidence record | Done by owner acceptance: lint, Debug/Release builds and separate 7-test XCUITest pass; package gate retains known V8 exception; remaining native evidence limits are documented and accepted |
| T20.10 | Tune the existing seeded activity mix for more jump/window exploration; land lower on eligible window sides and extend the existing top walk without adding states, clips or permissions | Core, behavior docs/tests | T20.6, T13.7 | Seeded default-choice distribution; lower side contact, bounded top dwell/cooldown, full return-to-Dock regression | Done by owner acceptance: focused tests pass; owner manually tested the revised autonomous variation and reported it worked perfectly |

## M21 — Reproducible ad-hoc release pipeline (authorized 2026-10-25; no paid Apple Developer membership)

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T21.1 | Record release policy: no paid Apple Developer membership, no Developer ID/notarization; verify final bundle ID, GitHub repo visibility, runner availability, free usage limits and publication authorization boundary | Owner, Docs | M20 accepted | S | `risks.md` and release docs state the approved no-cost Apple signing path and its Gatekeeper limitations |
| T21.2 | Versioning (`MARKETING_VERSION`, build number), release notes and `CHANGELOG.md` (Keep a Changelog); keep version validation deterministic | Repo | T21.1 | S | Valid/invalid version tests and review; do not create a release tag |
| T21.3 | Local Release archive/package script using the project's ad-hoc identity (`CODE_SIGN_IDENTITY = -` or verified equivalent); verify app-bundle signature integrity without treating it as Developer ID trust | Repo | T21.1–T21.2 | M | Repeated local builds package successfully; `codesign --verify` and recorded ad-hoc identity; no Apple secrets or notary calls |
| T21.4 | Build a user-installable DMG or ZIP, include app and versioned release notes, produce SHA-256 checksum and validate the extracted app/resources | Repo | T21.3 | M | Package structure, checksum round-trip, clean install and launch test; no false `spctl` pass claim |
| T21.5 | GitHub Actions workflow: run canonical validation and create/upload a dry-run artifact; release publication must require an explicit workflow input/approval, default off, and minimal `GITHUB_TOKEN` permissions | Repo | T21.2–T21.4 | M | Workflow validation; dry-run artifact; review trigger, permissions, pinned actions, runner and private-repo quota behavior; no release/tag pushed |
| T21.6 | English/pt-BR install, verification, upgrade and troubleshooting docs, including the actual unidentified-developer/Notarization warning and safe user-approved macOS override; do not instruct disabling Gatekeeper or removing quarantine | Docs | T21.4 | S | Review on supported macOS; steps reflect Apple documentation and real clean-machine behavior |
| T21.7 | Run final release rehearsal and record every quality gate, artifact digest, environment, expected security warning and remaining external owner action | All, Docs | T21.1–T21.6 | M | `make lint`, `make test-core`, `make test`, Debug/Release build, package/signature/checksum, CI dry run and manual Gatekeeper matrix reported honestly; preserve known M15 V8 exception |

T21.1–T21.7 local implementation and documentation are complete and closed by owner direction on
2026-10-25; see the [closeout and evidence](m21-implementation.md#owner-directed-local-closeout--2026-10-25).
At that local closeout, hosted dry-run and clean-machine installation were unverified; failed gates
still blocked strict packaging. Local closure did not claim those checks passed and authorized no
commit, merge, push, tag, PR or publication.

Subsequent owner instruction authorizes v1.0.0 Git integration/tag/publication, universal DMG/ZIP
delivery and the disclosed exact V8 exception; D-08's art redistribution decision is recorded.
All other quality gates still apply. See the [publication follow-up](m21-implementation.md#v100-publication-follow-up--2026-10-25).

The subsequent hosted run passed all remaining release gates, generated verified universal DMG/ZIP
artifacts, and v1.0.0 was published. The public README DMG download and matching checksum were
validated without authentication, including mounted payload/signatures. This closes the hosted
artifact work for T21.4/5/7; clean-machine first-launch/Gatekeeper and native Intel execution remain
unverified. See the [publication record](m21-implementation.md#public-release-and-download-verification--2026-10-25).

T21.4/6/7 were subsequently updated for the separately authorized v1.0.1 installation follow-up:
MacDevClean-style verified Terminal download, prominent app-specific approval guidance and
`INSTALL-FIRST.txt` for TextEdit. v1.0.1/build 11 is published after successful hosted/public
artifact checks with the separately approved exact V8 exception. Complete clean-machine
approval/relaunch and native Intel remain unverified. See the [follow-up](m21-implementation.md#v101-installation-follow-up--2026-10-25).
