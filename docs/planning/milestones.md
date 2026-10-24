# Milestones

Tasks: [task-breakdown.md](task-breakdown.md). Criteria: [acceptance-criteria.md](acceptance-criteria.md).
Every milestone's Definition of Done also includes the task-level quality bar in
[AGENTS.md §15](../../AGENTS.md#15-quality-bar-definition-of-done-for-any-task).

## Status

| ID | Milestone | Release | Status |
|---|---|---|---|
| M0 | Repository preparation & planning | — | **Done** (approved 2026-10-16; commit pending, T0.6) |
| M1 | Overlay proof of concept | — | **Done** (2026-10-16; recommendation: go for M2 — see [conclusion](proof-of-concept.md#conclusion-t19)) |
| M2 | App skeleton | v0.1.0 | **Done** (2026-10-18: owner explicitly confirmed correct operation and directed closure; detailed evidence limits preserved in m5-m6-closeout.md) |
| M3 | Transparent overlay | v0.1.0 | **Done** (2026-10-18: owner explicitly confirmed correct operation and directed closure; detailed evidence limits preserved in m5-m6-closeout.md) |
| M4 | Animation system | v0.1.0 | **Done** (2026-10-18: lint, package tests, build, 9.00 fps DEBUG preview and owner anchor check verified) |
| M5 | Rendering & automatic walking | v0.1.0 | **Done** (2026-10-18: owner explicitly confirmed correct operation and directed closure; detailed evidence limits preserved in m5-m6-closeout.md) |
| M6 | Dock integration & MVP hardening | v0.1.0 | **Done** (2026-10-18: owner explicitly confirmed correct operation and directed closure; detailed evidence limits preserved in m5-m6-closeout.md) |
| M7 | Basic physics | v0.2.0 | **Done** (2026-10-18: implemented; automated evidence plus owner confirmation of all remaining tests and explicit closure — [owner closeout](m7-m8-technical-review.md#owner-m7m8-closeout-2026-10-18)) |
| M8 | Jumps & landings | v0.2.0 | **Done** (2026-10-18: jumps/V4 implemented and approved; automated evidence plus owner confirmation of remaining tests and explicit closure — [owner closeout](m7-m8-technical-review.md#owner-m7m8-closeout-2026-10-18)) |
| M9 | Autonomous behaviors & Settings v1 | v0.3.0 | **Done by owner acceptance** (2026-10-18: 400 package tests, 2 UI tests, lint and Debug/Release pass; owner accepted documented gaps in real login-item action, native sleep cadence and installed-app playtest — [closeout](m9-implementation.md#owner-m9-closeout-2026-10-18)) |
| M10 | Cursor interaction & dragging | v0.4.0 | **Done by owner acceptance** (2026-10-22; native/performance evidence limits remain in the [closeout](m10-implementation.md#owner-m10-closeout-2026-10-22)) |
| M11 | Edge climbing | v0.4.0 | **Done by owner acceptance** (2026-10-22 — [record](m11-implementation.md#owner-closeout--2026-10-22)) |
| M12 | Window detection | v0.5.0 | **Done by owner acceptance** (2026-10-23; native evidence limits accepted — [closeout](#m12-owner-closeout--2026-10-23)) |
| M13 | Window interaction | v0.5.0 | **Done by owner acceptance** (2026-10-23 — [closeout](#m13-owner-closeout--2026-10-23)) |
| M14 | Multi-display, optimization & stabilization | v1.0.0 | **Done by explicit owner acceptance** (2026-10-23; see [implementation record](m14-implementation.md); evidence limits and waived soak remain documented) |
| M15 | Animation quality | — | **Done by explicit owner acceptance** (2026-10-23; revised animations and pacing tested by the owner; retained V8 pixel-QA exception — [closeout](m15-implementation.md#owner-m15-closeout--2026-10-23)) |
| M16 | New behaviors and animations | — | **Done by explicit owner acceptance** (2026-10-24; owner confirmed all behavior works and authorized integration/push; V8 QA exception and measurement limits preserved — [closeout](m16-implementation.md#owner-m16-closeout--2026-10-24)) |
| M17 | Portuguese/English localization | — | Not started |
| M18 | Bundled character selection | — | Not started |
| M19 | Character pack discovery and installation | — | Not started |
| M20 | Release pipeline | v1.0.0 | Not started |

M2/M3/M5/M6 owner-directed closure and retained diagnostic/hardware limits: [closeout](m5-m6-closeout.md).
Baseline HEAD is 2f7f33f; M6 is merged, but v0.1.0 remains unreleased. M9 is reauthorized; no
commit/push/tag/PR is authorized by milestone acceptance.

Status values: Not started · In progress · In review · Done · Blocked (reason).

---

## M0 — Repository preparation & planning

- **Objective:** a repository any agent can pick up: product, architecture, specs, ADRs, plan, agent configs.
- **Scope:** docs, ADRs, `AGENTS.md`/`CLAUDE.md`/`CODEX.md`, `.cursor/rules`, `.claude/settings.json`, `.gitignore`, README. No code.
- **Prerequisites:** none.
- **Modules:** none.
- **Dependencies:** owner review.
- **Risks:** plan built on unvalidated platform assumptions → mitigated by M1.
- **Tests:** link check, consistency review.
- **DoD:** documents reviewed and approved by the owner; open decisions answered or explicitly deferred.

## M1 — Overlay proof of concept (spike)

- **Objective:** validate assumptions A1–A5 ([scope.md](../product/scope.md)) with throwaway code.
- **Scope:** experiments E1–E8 in [proof-of-concept.md](proof-of-concept.md); results documented; ADR-0003/0004/0009 confirmed or revised.
- **Prerequisites:** M0 approved.
- **Modules:** none (separate spike project on branch `spike/overlay-poc`, not merged).
- **Dependencies:** a Mac with a Dock at the bottom; ideally an external display.
- **Risks:** click-through strategy fails → fall back to per-pet windows (ADR-0003 alternative).
- **Tests:** manual, against objective success criteria; CPU measured.
- **DoD:** results table filled; decisions updated; owner approves continuing with (or changing) the architecture.

## M2 — App skeleton

- **Objective:** a menu bar–only app built from the final project structure.
- **Scope:** Xcode project, xcconfigs, `PetScapeKit` package with four modules and test targets, menu with Quit, logging, Makefile, swift-format, optional CI.
- **Prerequisites:** M1 done.
- **Modules:** App, all package targets (skeletons + `Log`).
- **Dependencies:** none external.
- **Risks:** package `defaultIsolation` or Swift Testing integration quirks with Xcode 27 → resolve early.
- **Tests:** smoke unit test, UI launch test, `make lint`.
- **DoD:** FR-01 and FR-13 (quit) met; `make build`, `make test`, `make lint` pass from a clean clone.

## M3 — Transparent overlay

- **Objective:** a correct, click-through overlay on the Dock screen, with run-state plumbing.
- **Scope:** screens and coordinates, overlay panels, transparent scene, pass-through controller, cursor sampling, system events → run state.
- **Prerequisites:** M2.
- **Modules:** Core (Geometry), Platform (Screens, Input, SystemEvents), Rendering (Overlay, Scene), Runtime (pass-through, run state).
- **Dependencies:** PoC findings E1, E2, E6.
- **Risks:** pass-through latency; Spaces behavior.
- **Tests:** CoordinateConverter, MousePassthroughController, RunStateController unit tests; manual click-through matrix.
- **DoD:** FR-03, FR-14, FR-16 (partial) met with a debug rectangle in place of the pet.
- **Verification (2026-10-17, macOS 27.0.1, built-in Retina 1470 × 956 pt, Dock at the bottom):**
  `make lint`, `make test-core` (67 tests), `make build` (0 warnings) pass. Window server: overlay at layer 19
  with full-screen bounds, Dock at 20. AC-M3-04: 56 pass-through toggles over two sessions, each completed
  ≤ 14.4 ms after the input event/sample that crossed the target edge. Full-screen rule: 8 entries hidden
  ~1 s after the switch, restored on every return; the inconclusive case kept the state. Clicks/drags on the
  target: never activated the app or made the overlay key (DEBUG log). Quit: observers, monitors and display
  link removed, no crash report. Owner approved AC-03, AC-14, AC-16, AC-21, the paused path and the resolution
  change by hand; **the resolution change left no `Screen parameters changed` line in the log** (as in PoC
  S8), so the re-layout on resolution change is still not evidenced.

## M4 — Animation system

- **Objective:** data-driven animation from character packs, independent of render rate.
- **Scope:** manifest decode/validate, definition resolution, player/controller, image decoding, texture store, hit masks, cat `character.json`, bundling, loader with errors and placeholder, DEBUG preview.
- **Prerequisites:** M2 (T4.1–T4.5 can start right after M2, in parallel with M3).
- **Modules:** Core (Characters, Animation), Rendering (Textures), Runtime (CharacterLoader), App (bundle resources).
- **Dependencies:** asset audit ([asset-format.md](../specifications/asset-format.md)).
- **Risks:** bundling the pack; memory; alpha fringe.
- **Tests:** decoding/validation tables, player parameterized tests (8/12/16/24/32 frames, 60/120 Hz), decoder/texture tests with fixtures, bundled-pack validation test.
- **DoD:** FR-05, FR-06, FR-15 met in the DEBUG preview.
- **Owner check (2026-10-18):** DEBUG Animation preview showed the `walk` anchor aligned at the paws (AC-M4-03 pass).

## M5 — Rendering & automatic walking

- **Objective:** the cat walks back and forth, controlled from the menu.
- **Scope:** surfaces (minimal), fixed-step loop, MVP FSM, snapshots and sprite node, runtime wiring, menu pause/hide with persistence, adaptive render rate, real hit masks for pass-through.
- **Prerequisites:** M3, M4.
- **Modules:** Core (Surfaces, Time, Pets, World, Behavior), Rendering (Scene), Runtime, Platform (Preferences), App (menu).
- **Dependencies:** none new.
- **Risks:** foot sliding (speed vs art); jitter.
- **Tests:** accumulator, world step and FSM tests; preferences tests; manual walking/visual checks.
- **DoD:** FR-02, FR-04, FR-07, FR-08, FR-09, FR-11, FR-12, FR-18 met (walking on the screen bottom).
- **Verification (2026-10-17, macOS 27.0.1, built-in Retina 1470 × 956 pt, Dock at the bottom, Debug build):**
  `make lint` clean, `make test-core` 256 tests pass (Core 156, Rendering 44, Platform 36, Runtime 20), `make build`
  0 compiler warnings. Automated: AC-07 speed ±5% over 10 s both directions, AC-08 sprite inside the segment over
  100 turns (3 anchors), AC-09 0.15 s hold + mirrored walk back + no drift, AC-11 frozen while not stepped and no
  catch-up after resume, AC-18 store round-trip, AC-M5-02 mask hit and 5 pt outside (incl. mirroring and scale).
  Running app (screenshots + DEBUG log): cat spawned on `screen:1:bottom`, display link 60.0 fps / 60.0 steps/s;
  turn at the right edge with the sprite inside the screen, walk back mirrored; hold measured 0.150 s in the log;
  menu items via System Events: "Hide Pet/Show Pet" and "Pause/Resume" labels follow the state; paused cat
  pixel-identical over 3 s and resumed from the same place; Hide ordered the overlay out, Show restored it; quit +
  relaunch restored `paused=true` (cat drawn, frozen) and `hidden=true` (no overlay window, "Show Pet");
  synthetic click on the cat logged `Mouse down on pet 1`, `app active=false overlay key=false`; cursor just
  above its back returned to pass-through. CPU (Debug, `top`): ~2.5% walking, 0.0% paused; footprint 29 MB.
  **Not verified / pending:** AC-14 full click-through matrix around the walking cat (partial Dock check passed);
  other owner visual checks passed on 2026-10-18. The M5 walkway is
  the screen bottom, so most of the time the cat walks **behind the Dock** (overlay level is below the Dock);
  the Dock surface is M6.

## M6 — Dock integration & MVP hardening

- **Objective:** ship v0.1.0: the cat walks on the bottom Dock, robustly and cheaply.
- **Scope:** Dock estimator/provider, offset preference, surface re-projection, sleep/wake/lock/occlusion, screen changes, error UX, performance and leak checks, manual matrix, README usage.
- **Prerequisites:** M5.
- **Modules:** Core (Surfaces/Dock), Platform (Dock, SystemEvents), Runtime, App.
- **Dependencies:** PoC E3 results.
- **Risks:** Dock change notifications; visual offset per macOS version.
- **Tests:** estimator tables; re-projection; run-state combos; performance protocol; manual matrix.
- **DoD:** all MVP acceptance criteria (FR-01…FR-18) pass; performance targets met or deviations accepted by the owner; v0.1.0 tagged when asked.
- **Verification (2026-10-17, macOS 27.0.1, built-in Retina 1470 × 956 pt, Dock at the bottom (64 pt reservation),
  Debug and Release builds; screen access was not granted, so nothing below was checked by eye):** `make lint` clean, `make test-core` 282 tests pass (Core 174,
  Rendering 44, Platform 25, Runtime 39), `make build` and a Release build with 0 compiler warnings.
  - Automated: estimator table (bottom/left/right, auto-hide 0–9.5 pt, menu bar ignored, Dock on the secondary
    screen, negative coordinates, ties), surface selection with offset clamping, provider (resize, auto-hide, side,
    host screen), offset preference persistence/clamping, lost-surface re-settle (same x/facing, clamp, other
    screen → random respawn), runtime walkway + offset, and sleep / display sleep / session / lock → frames stop,
    overlay ordered out, resume without catch-up.
  - Running app (logs): `Dock estimate: bottom on screen 1, inset 64.0 pt`, `Walkway dock (dockTop) at y=64.0`,
    `Pet 1 'cat' spawned on dock`. Real Space switches during the soak: `Full-screen Space detected` → overlay
    ordered out, frames off; `Desktop Space (Dock window present)` → visible, frames on (3 round trips). Real screen
    lock: `com.apple.screenIsLocked` → overlay out, frames off for 42 min (0.00% CPU), unlock → walking again.
    Paws vs shelf by geometry: anchor row 474/512 = lowest opaque paw row (±1 px = 0.2 pt), walkway =
    `visibleFrame.minY` = 64 pt, PoC E3 shelf top 63 pt → paws ≈ 1 pt above the shelf (AC-10 predicts pass; not
    seen).
  - Error UX (Debug, `--character-pack` copies with `character.json` renamed / truncated): error logged
    (`assets`), placeholder spawned on the Dock, no crash, no crash report.
  - Measurements (Release): paused 0.00% CPU over 60 s (cumulative CPU time unchanged) and 0 idle wakeups in
    60 s; walking on the Dock 2.06% average (median 2.06%, max 3.33%, 69 min of 15 s samples); full-screen Space
    ~0% (median 0.00%); locked 0.00%; launch `open` → cat spawned 0.45 s, → first simulation frame 0.49 s (warm).
    Leaks (`leaks`, Debug and Release): 416 objects / 19.9 KB, all in three retain cycles inside Apple's AppIntents
    XPC connection (`com.apple.linkd.autoShortcut`), none in PetScape code — identical at the start and end of the
    soak. 2 h soak (Release, 2026-10-17 15:17–17:18): no crash, no crash report, physical footprint 21.8 → 23.7 MB
    (+1.9 MB; RSS 66 → 39 MB).
  - Owner visual check (2026-10-17, macOS 27.0.1, built-in Retina display, bottom Dock): Debug › Show walkway
    confirmed the cat's paws are within ±3 pt of the Dock edge (AC-10). Small/large Dock sizes and magnification
    also passed the owner's visual check. Quit from the menu logged `PetScape stopped` after removing the overlay
    and stopping observers, monitors and the display link.
  - Owner manual check (2026-10-18, macOS 27.0.1, built-in Retina display): moving the Dock to the left and
    right briefly transitions the cat through `surfaceLost`, then restores it on the screen-bottom fallback
    walkway; the owner confirmed the cat remained visible and the behavior worked on both sides (AC-10 pass).
    T6.4 regression coverage reproduces both side placements; the runtime keeps frames running until placement
    completes.
  - Owner manual check (2026-10-18): Dock auto-hide on/off, resizing and moving the Dock while PetScape was
    running all worked as expected (AC-10, AC-17 pass).
  - Owner accepted the resolution-change check as passing without a direct run because no external monitor was
    available (2026-10-18); the required `Screen parameters changed` and new walkway log evidence was not captured,
    so the M3/PoC S8 evidence gap remains. External display connect/disconnect and Dock-on-secondary checks are
    not applicable until an external display is available (matrix 7–8).
  - Owner manual check (2026-10-18): the cat disappears in a full-screen app and returns after leaving full screen
    (matrix 11–12 pass); logs confirmed `Full-screen Space detected (no Dock window)` and `Desktop Space (Dock
    window present)`.
  - Owner manual check (2026-10-18): switching Spaces and returning left the cat visible and correctly placed,
    with no jump (matrix 11–12 pass); the log stream recorded full-screen/desktop Space transitions.
  - Owner manual check (2026-10-18): locking and unlocking the session returned the cat in the right place,
    without a jump (matrix 11–12 pass).
  - Owner manual check (2026-10-18): after the display went to sleep and was woken, the cat returned correctly
    (matrix 12 pass).
  - Owner manual check (2026-10-18): after putting the Mac to sleep and waking it, the cat returned in the right
    place (matrix 12 pass).
  - Owner manual check (2026-10-18): switching to another macOS user and returning worked; the cat resumed
    correctly (matrix 12 pass).
  - Owner manual check (2026-10-18): clicking and dragging Dock icons beside the cat and clicking around it on
    the Dock worked normally (AC-14 pass).
  - Owner manual check (2026-10-18): clicking the cat while typing left the other app frontmost and typing
    continued there (AC-21 pass).
  - Owner manual check (2026-10-18): the PetScape menu was reachable and correctly announced with VoiceOver
    (AC-02 pass).
  - Owner manual check (2026-10-18): the overlay remained transparent with no visible background, border or
    shadow on both light and dark wallpapers (AC-03 pass).
  - Owner manual check (2026-10-18): watching the cat walk showed no visible foot sliding (AC-07 pass).
  - Owner manual check (2026-10-18): PetScape had no entries in the checked Privacy & Security panes (AC-16 pass).
  - Owner manual check (2026-10-18): the DEBUG Animation preview showed the `walk` anchor aligned at the paws
    (AC-M4-03 pass).
  - Owner manual check (2026-10-18): with a missing `character.json`, the menu showed the placeholder error
    status and the placeholder pet appeared; logs recorded the load error, placeholder spawn and clean quit
    (AC-15 Man pass).
  - UI launch test (2026-10-18): `make test` passed in Automation Mode (174 package tests and 1 UI test).
  - Deviations for the owner to accept or reject: walking CPU 2.06% is a > 20% regression versus the PoC entry
    in performance.md (1.0%; the spike had no simulation or per-frame hit testing) though within the 5% target; when PetScape is launched inside a full-screen Space the cat
    can show for ~0.4 s until the two-read full-screen check confirms (T3.10 design); a Dock hidden/shown while
    paused leaves the cat at the old height until Resume (the world is not stepped while paused); the cat walks
    the full screen width beyond the shelf ends (ADR-0009, accepted).

## M7 — Basic physics

- **Objective:** gravity, visible falling/landing and bounded recovery; preserve walking/energy/non-interference.
- **Status of design:** owner approved 2026-10-18; [technical review](m7-m8-technical-review.md),
  [Physics Engine](../architecture/physics-engine.md), ADR-0016. Owner subsequently authorized continuous M7/M8 engineering. Physics, floor composition, visible fall/landing,
  recovery and demand are implemented. Automated/package/UI checks pass; see task evidence and performance.md.
  Owner subsequently reported all remaining M7/M8 tests completed and explicitly requested closure.
  **Done**, by owner acceptance; instrumented evidence limitations remain in the [closeout](m7-m8-technical-review.md#owner-m7m8-closeout-2026-10-18).
- **Scope:** Pet.position remains sole position, add velocity, semi-implicit stepper/swept first-hit,
  host floor+Dock, grounded/airborne refinement, explicit frame demand, existing recovery for exceptional
  invalid/host-loss cases. Side Dock/hide detach into fall; Dock shown retains existing floor contact.
- **Prerequisites:** accepted M6 or explicitly named owner exception per implementation-plan.md;
  planning approval and explicit T7 instruction. Planning itself is not blocked by M5/M6 evidence gaps.
- **Modules:** Core and Runtime; existing Platform ScreenProvider reader injection for deterministic tests.
  No new module, provider observer or second scheduler. Rendering consumes state-based visible flight.
- **Dependencies:** no new sprites. Fall/landing requests use default/legacy fallbacks.
- **Tasks:** T7.1–T7.8 in task-breakdown.md; original T7.3 provider refined into Core floor builder;
  original T7.5 random Dock-end drop deferred because real shelf ends are unknown (ADR-0009).
- **Tests:** AC-M7-01…15, deterministic time/seed/synthetic screens, both-side 2f7f33f liveness;
  manual matrix, Release measurements and 2 h soak/leaks.
- **DoD:** FR-20 and retained MVP contracts verified; ordinary surface loss uses physical fall, not
  respawn. Exceptional invalid-state/removed-display placement still allowed and logged; no no-surface loop.
  Owner accepts measured/visual evidence and exceptions. No automatic tag/release.

## M8 — Jumps & landings

- **Objective:** vertical/short horizontal and reachable floor↔Dock jumps with safe walk/idle return.
- **Status:** **Done**, owner-directed closure 2026-10-18 after confirming all remaining tests.
  Jumps and V4 (24 new frames) are implemented; 361 package tests + UI passed, visual result approved.
  See [closeout](m7-m8-technical-review.md#owner-m7m8-closeout-2026-10-18) for owner-reported versus instrumented evidence. [Jump System](../architecture/jump-system.md), ADR-0017.
- **Scope:** discrete-replayed bounded solver, explicit commands, PreparingJump/Rising/Falling/Landing,
  cooldown/cancellation/return intent, simulation-driven animation. No windows/climbing/M9 selector.
- **Prerequisites:** owner continuous-execution instruction authorized engineering before M7 sign-off;
  acceptance of M7 and retained MVP evidence is still required for release.
- **Modules:** Core physics/existing HSM/animation, Runtime integration; existing Core Animation renderer.
- **Dependencies:** engineering uses current pack/fallbacks; [V4 art](../specifications/animation-assets-v4.md)
  produced/integrated and approved by owner on 2026-10-18; remaining tests accepted by owner report.
  No schema modification required, underscore name mapped to jump-start.
- **Tasks:** T8.1–T8.6. Historical event-driven takeoff T8.4/AC-M8-02 revised under D8: simulation deadline
  applies velocity, physical contact starts landing; art events are presentation only.
- **Tests:** AC-M8-01…18, solver actual impact≤1 pt, one launch/apex/contact, interrupted targets,
  identical trajectories with variable/missing clips, manual mask/typing/VoiceOver and Release measurements.
- **DoD:** FR-21 within current-host reachable surfaces, no stuck/tunnel states, owner-reviewed demo,
  art integration or explicit art deferral; all regressions/measurements documented and accepted.

## M9 — Autonomous behaviors & Settings v1

- **Objective:** autonomous walk/idle/jump/rest/sleep/wake/observe/explore and native Settings.
- **Current scope:** reauthorized by owner on 2026-10-18 after predecessor closure; follow the
  [concrete implementation plan](m9-implementation.md). Core needs, selector and HSM are implemented
  and reviewed; Runtime/Settings integration and full verification are in progress.
- **Direction:** hierarchical execution + simple weighted choices after availability/cooldowns,
  stable order/injected randomness and typed requests/events. No full Behavior Trees, utility top-k or LLM.
- **Prerequisites:** M7/M8 accepted; explicit M9 instruction received. Owner delegated reversible tuning.
- **Modules:** Core behavior, Platform preferences/login service, App Settings, Runtime adaptive demand.
- **Dependencies:** optional rest/expression clips use deliberate held idle fallbacks; dedicated rest art
  is optional, and no new art is claimed. Original files remain unchanged.
- **Risks/tests:** repeat/cooldown/rejection bounds, seeded low-energy sleep/wake, support loss,
  settings persistence/live changes, fake login service, low-rate time preservation, native UI and playtest.
- **DoD:** FR-22/23, AC-M9 evidence, recorded ≥2 h playtest/tuning and full regression gates.
  No release/tag/commit is implied by completion.

## M10 — Cursor interaction & dragging

- **Objective:** bounded cursor awareness, primary click, pickup and predictable zero-impulse drop.
- **Planning:** [M10 implementation plan](m10-implementation.md), [native PoC](m10-native-poc.md),
  [interaction architecture](../architecture/interaction-system.md), [contracts](../specifications/interaction.md),
  [V5 brief](../specifications/animation-assets-v5.md). Engineering implementation and automated gates
  are complete; owner accepted behavior/tests on 2026-10-22. V5 interaction art was subsequently
  produced and integrated; final owner visual review and existing native/performance evidence limits
  remain recorded in the closeout.
- **Scope delivered:** M10.0 native review → M10.1 awareness → M10.2 direct input → M10.3 drag/drop →
  M10.4 V5 `curious` / `picked-up` / `held` clips plus safe fallbacks. Historical throwing and approach/startle are deferred by the current brief;
  do not claim full original FR-24/25 coverage. IDs are preserved with scope notes.
- **Prerequisites:** M9/M7/M8 accepted; owner planning review and explicit task authorization;
  production capture requires owner acceptance of PoC evidence and ADR-0020 topology.
- **Modules:** existing Core/Runtime/Platform/Rendering, App Settings; Core Animation retained.
- **Risks:** swallowed transparent clicks, focus theft, lost-up capture, simultaneous position writers.
- **Tests:** deterministic per-task tests, native focus/Dock/click-through matrix, paired Release measurements.
- **DoD:** revised AC-M10 criteria, explicit deferred requirements/art acceptance, native owner
  review. **Status: implementation complete; final visual review pending**; see the implementation
  record for accepted evidence limits. The V5 feature branch is merged into `develop` under the
  owner's Git instruction; no release or tag was created.

## M11 — Edge climbing

- **Objective:** the cat climbs the left/right screen edges.
- **Scope:** wall surfaces, climbing motion and states, alignment rendering, art.
- **Prerequisites:** M8.
- **Modules:** Core, Rendering (alignment).
- **Dependencies:** `climb` art.
- **Risks:** rotation/anchor visuals.
- **Tests:** climbing transitions, alignment math.
- **DoD:** FR-26 met.

**2026-10-22 closeout:** M11 adds canonical left/right wall surfaces, fixed-step climbing in the
existing `PetState`/`SurfaceAttachment`/PhysicsStepper flow, and the two-frame V6 `climb` art with a
schema-v1 fallback. Automated checks cover both wall directions, alignment, top exit and continuous
fall; the owner confirmed the climb was visible and approved the visual result. See the
[implementation and acceptance record](m11-implementation.md#owner-closeout--2026-10-22) for
verification details and evidence limits.

## M12 — Window detection

- **Progress (2026-10-23):** D-11 was decided by the owner: Accessibility is required, with no CG-only
  degraded mode. Core window values, frame correlator, visible-top builder and geometry tests are
  implemented; Settings has an opt-in preference and explicit Accessibility confirmation flow; CG
  snapshots, focused-window AX observers, run-state tracking and DEBUG surface lines are implemented.
  The owner accepted M12 closure with native evidence gaps recorded below; this does not claim that
  AC-M12-02 or AC-M12-03 passed. See
  [spike record](../architecture/window-tracking.md#m12-spike-findings-2026-10-22) and
  [ADR-0022](../decisions/0022-window-tracking-consent-and-sources.md).
- **Task evidence:** T12.1 documentation complete; partial native experiments recorded below. T12.2 implementation
  complete; owner granted Accessibility and the opted-in Debug app recognized the permission. T12.3
  adapter and fixture filters implemented. T12.4 focused-app/focused-window observer implemented;
  native event/timeout behavior unverified. T12.5 tracker is gated by opt-in, trust and running state,
  with 1 Hz snapshots; native lifecycle/revocation behavior remains unverified. T12.6
  pure builder/correlation tests pass. T12.7 DEBUG-only diagnostic lines implemented; native visual
  check pending. T12.8 activation/API-disabled paths implemented; revocation test and owner check
  pending.
- **Acceptance evidence:** AC-M12-01 is covered by a permission-spy unit test (disabled status refresh
  does not call trust/prompt APIs), a UI test that observes the toggle initially off, and a manual
  check on 2026-10-22: after the owner granted Accessibility, the Debug app accepted the opt-in without
  showing another permission alert. A 2026-10-23 inventory now sees 14 on-screen windows from 14
  external app owners, but AC-M12-02 remains unverified because their tracked tops were not compared
  with AX frames to the 2 pt tolerance. AC-M12-03 has no valid idle profile; the preliminary samples
  below do not establish a pass.
- **Local verification (2026-10-22, macOS 27.0.1 / Xcode 27.1):** `make lint` passed;
  `make test-core` passed (294 package tests); `make build` succeeded with the existing App Intents
  metadata-extraction warning (the app has no AppIntents dependency); `make test` passed (2 UI tests)
  on retry. Two earlier integrated UI runs had automation failures: one timed out waiting for the
  menu-open notification; another reported `Unable to update application state promptly for Application
  'com.SMI-Inc.InstantView'`. The latest full verification passed before native permission testing.

### M12 owner closeout — 2026-10-23

The owner explicitly accepted M12 closure on 2026-10-23 after reviewing the implementation and
remaining validation limits. Accessibility was granted, the opt-in was enabled, and a later inventory
counted 14 eligible on-screen windows across 14 external app owners. That count does not prove the
2 pt frame accuracy requirement. The short CPU runs used an active pet and do not establish the idle
target. The DEBUG visualization, AX drag/event cadence, hung-app timeout, and permission revocation
and recovery were not verified. These gaps are accepted for M12 closure and must remain visible as
limitations if M13 relies on this tracking behavior.

- **Objective:** opt-in, reliable, cheap tracking of other apps' windows.
- **Scope:** spike, permission flow, CGWindowList and AX adapters, tracker, surface builder, debug visualization, revocation.
- **Prerequisites:** M7 (surfaces as diffs). Can run parallel to M8–M11.
- **Modules:** Platform (WindowTracking, Permissions), Core (WindowSurfaceBuilder), App (Settings).
- **Risks:** AX limitations, correlation without private API, CPU.
- **Tests:** builder tests (z-order, clipping); adapter fixture tests; manual app matrix.
- **DoD:** FR-27 met; ≤ 1% CPU idle with tracking on.

## M13 — Window interaction

- **Objective:** the cat walks on, rides and jumps between windows, including occasional autonomous side climbs.
- **Scope:** window surfaces in the world, riding, close/minimize falls, jumps between windows, occlusion changes, and randomized Dock-to-window climbing excursions with a return jump to Dock.
- **Prerequisites:** M12, M8.
- **Modules:** Core, Runtime.
- **Risks:** jitter when riding; surprising behavior with many windows.
- **Tests:** riding/teleport/removal tests; manual matrix.
- **DoD:** FR-28 met.
- **Implementation record (2026-10-23):** Runtime now feeds visible host-screen window surfaces into the
  existing world map; Core uses those surfaces for spawn/contact/jumps, re-projects moved/resized
  attachments, detaches when visible support is occluded, and applies the 240 pt/s ride / 1.5 s sample-gap
  guards. Deterministic tests cover these paths. The 0.5 s refresh throttle (≤2 Hz) cannot demonstrate
  AC-M13-01's ≤1-frame visual lag; the existing exploratory 60 s Debug CPU sample is unpaired and does
  not independently satisfy T13.6. These evidence limits were explicitly accepted by the owner at the
  M13 closeout below. Details and the needed concurrency review are in
  [window-tracking.md](../architecture/window-tracking.md#m13-interaction-behavior) and
  [ADR-0023](../decisions/0023-window-interaction-cadence.md). `make lint`, `make test-core` (309 Core
  tests plus all package suites), `make test` (2 UI tests) and `make build` pass.
- **T13.7 implementation (2026-10-23):** Visible window sides are added with front-window occlusion
  clipping. The autonomous weighted activity randomly chooses an eligible window, approaches its side
  along the Dock when needed, jumps to an intermediate point on the side with a bounded discrete solver,
  leaving a substantial section to climb with M11, walks on the top for a random 5–17 simulated seconds,
  then moves to a safe launch point
  and jumps back to the Dock. A native playtest exposed and fixed an eligibility bug: sides were only
  selectable when the cat already stood outside the window's horizontal span, so a cat beneath the
  window could never approach its jump point. Seeded coverage now starts beneath the window and checks
  side contact, climbing, top walking, Dock return, and selection across multiple windows. Build and
  automated verification pass; the owner subsequently confirmed native validation of the complete
  autonomous flow.

### M13 owner closeout — 2026-10-23

The owner confirmed that M13 behavior and tests are validated and accepted closure. Native validation
includes the window interaction and autonomous side-climb flow. The owner accepts the documented
tracking-cadence and paired-performance evidence limits for this milestone. No new latency or CPU
measurements are claimed here; the ≤1-frame target and unpaired Debug sample remain recorded as limits
in [AC-M13-01](acceptance-criteria.md) and [performance.md](../specifications/performance.md#m13-tracking-measurements).

## M14 — Multi-display, optimization & stabilization

- **Objective:** v1.0 quality.
- **Scope:** overlays on all screens + hand-off, single frame driver, texture policy, interpolation (if needed), lazy clips, bundle strip, soak/leaks, macOS 14 VM pass, VoiceOver audit, perf regression checks.
- **Prerequisites:** M10, M11, M13.
- **Risks:** multi-display edge cases.
- **Tests:** full manual matrix; 8 h soak; performance protocol.
- **DoD:** FR-29, NFR-01..13 verified.

## M15 — Animation quality

- **Objective:** improve the fluency of the cat's existing clips by adding authored in-between poses where they improve the movement, while retaining each clip's intended duration, identity, contact registration, events and fallback behavior.
- **Scope:** inventory and visual review of every clip referenced by the current cat manifest; produce and integrate only justified additional frames; tune manifest frame counts/FPS together; retain new-source provenance and previews. No new behavior or clip.
- **Prerequisites:** M14 accepted; current character pack and schema-v1 contracts.
- **Risks:** inconsistent generated art, contact/anchor jitter, event drift, increased decoded image memory.
- **Tests:** manifest/schema/path and image QA; existing Core/Rendering pack tests; preview each changed clip and adjacent transitions at the real manifest timing.
- **DoD:** AC-M15-01…06 in [acceptance criteria](acceptance-criteria.md#milestone-specific-criteria); delivery and remaining owner actions in [M15 record](m15-implementation.md).

## M16 — New behaviors and animations

- **Objective:** add new autonomous behavior and corresponding character animation.
- **Scope:** owner-authorized music-associated dancing, manual dance, and post-landing cleanup; existing images are never modified (on 2026-10-23 the owner approved building the new V9 clips with the V8 rig). See [M16 contract and implementation](m16-implementation.md).
- **Prerequisites:** M15 accepted.
- **Status:** **Done by explicit owner acceptance, 2026-10-24.** The owner reported everything
  working after the music/held-drop fixes and Stop Dance addition, and explicitly authorized a
  feature branch, commit, merge into develop and push. V9 art is integrated. The inherited V8
  pixel-QA exception, AppIntents metadata warning and unmeasured native/performance evidence remain
  visible in the [closeout](m16-implementation.md#owner-m16-closeout--2026-10-24); no unrun check is
  converted into a measured pass. M17–M20 remain planning only.

## M17 — Portuguese and English localization

- **Objective:** offer Portuguese and English UI with automatic language detection.
- **Scope:** localization resources, language selection/detection and localized app strings. No M17 implementation is authorized by the M15 request.
- **Prerequisites:** M16 planning/implementation as later specified.
- **Status:** Not started; detailed task and acceptance criteria to be planned before implementation.

## M18 — Bundled character selection

- **Objective:** let the user choose among characters included with the app.
- **Scope:** bundled character selection and persistence as later specified. No M18 implementation is authorized by the M15 request.
- **Prerequisites:** M17 planning/implementation as later specified.
- **Status:** Not started; detailed task and acceptance criteria to be planned before implementation.

## M19 — Character pack discovery and installation

- **Objective:** discover and install character packs.
- **Scope:** local pack discovery and installation as later specified. No M19 implementation is authorized by the M15 request.
- **Prerequisites:** M18 planning/implementation as later specified.
- **Status:** Not started; detailed task and acceptance criteria to be planned before implementation.

## M20 — Release pipeline

- **Objective:** reproducible, signed, notarized releases on GitHub.
- **Scope:** owner decisions (license, bundle ID, Developer ID), versioning, changelog, archive/export, notarization, DMG, GitHub Actions release workflow, install docs.
- **Prerequisites:** preceding product milestones accepted; Apple Developer Program membership.
- **Risks:** secrets handling in CI; notarization failures.
- **Tests:** dry-run release on a tag in a fork/branch; Gatekeeper check on a clean machine/VM.
- **DoD:** FR-30 met; v1.0.0 published when asked.
