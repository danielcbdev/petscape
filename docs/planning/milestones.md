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
| M10 | Cursor interaction & dragging | v0.4.0 | **Done by owner acceptance** (2026-10-22; native/performance evidence limits remain in the [closeout](m10-implementation.md#owner-m10-closeout--2026-10-22)) |
| M11 | Edge climbing | v0.4.0 | **Done by owner acceptance** (2026-10-22 — [record](m11-implementation.md#owner-closeout--2026-10-22)) |
| M12 | Window detection | v0.5.0 | **Done by owner acceptance** (2026-10-23; native evidence limits accepted — [closeout](#m12-owner-closeout--2026-10-23)) |
| M13 | Window interaction | v0.5.0 | **Done by owner acceptance** (2026-10-23 — [closeout](#m13-owner-closeout--2026-10-23)) |
| M14 | Multi-display, optimization & stabilization | v1.0.0 | **Done by explicit owner acceptance** (2026-10-23; see [implementation record](m14-implementation.md); evidence limits and waived soak remain documented) |
| M15 | Animation quality | — | **Done; V8 visual follow-up closed by owner acceptance** (2026-10-25; exact original hashes/48 known findings retained in the regression baseline, historical release waiver retired — [final closeout](m15-implementation.md#final-v8-visual-acceptance--2026-10-25)) |
| M16 | New behaviors and animations | — | **Done by explicit owner acceptance** (2026-10-24; owner confirmed all behavior works and authorized integration/push; V8 QA exception and measurement limits preserved — [closeout](m16-implementation.md#owner-m16-closeout--2026-10-24)) |
| M17 | Portuguese/English localization | — | **Done by explicit owner acceptance** (2026-10-24; native visual/VoiceOver/live locale checks unverified, package-run exceptions retained — [closeout](#owner-m17-closeout--2026-10-24)) |
| M18 | Bundled character selection | — | **Done by explicit owner acceptance** (2026-10-24; generic engineering accepted with one real bundled pack and retained native/V8 evidence limits — [closeout](#owner-m18-closeout--2026-10-24)) |
| M19 | Character pack discovery and installation | — | **Done by explicit owner acceptance** (2026-10-24; real-pack/manual/VoiceOver/performance evidence limits retained — [closeout](#owner-m19-closeout--2026-10-24)) |
| M20 | Settings redesign & multiple active characters | — | **Done by explicit owner acceptance** (2026-10-25; minimum-window, native accessibility/keyboard, and matched Release resource checks remain unverified; package test run retains the existing M15 V8 pixel-QA exception — [closeout](m20-implementation.md#owner-closeout--2026-10-25)) |
| M21 | Reproducible ad-hoc release pipeline | v1.0.3 | **Done; v1.0.3 documentation-package correction in progress** (2026-10-25; primary cURL flow already corrected on main/develop, updated bundled guide pending strict release validation — [follow-up](m21-implementation.md#v103-curl-first-installation--2026-10-25)) |

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
- **DoD:** AC-M15-01…06 in [acceptance criteria](acceptance-criteria.md#m15--animation-quality); delivery and remaining owner actions in [M15 record](m15-implementation.md).

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
- **Authorization:** explicit owner request on 2026-10-24 to implement M17 end to end. No manual language setting or persisted language preference.
- **Scope:** English source, Brazilian Portuguese translation, first supported macOS preferred language, runtime locale updates where public APIs allow, all user-visible app and M18 text, and localized app metadata.
- **Prerequisites:** M16 and M18 accepted. Preserve their behavior and closeout evidence; M19/M20 excluded.
- **Status:** **Done by explicit owner acceptance, 2026-10-24.** Native visual, VoiceOver and live system language-change checks remain unverified and are recorded as accepted evidence limits; no pass is claimed.
- **API impact:** `CharacterSelectionModel.error: String?` became the typed `issue: CharacterSelectionIssue?` so package code no longer freezes UI copy using the process locale. The package is only consumed by this app and its in-repo tests; all current callers were updated. No persisted key, manifest schema or Core API changed.
- **Verification (2026-10-24):** `make format`, `make lint`, Debug build, Release build, and the UI suite (6 tests) passed. Focused M17 language selection (5 tests), M18 bundled selection (10 tests), and isolated `PetRuntime` (32 tests) passed. The String Catalog compiles with 94 entries and no missing pt-BR values; Debug and Release bundles contain the pt-BR catalog, both localized Info.plist resources, English development region, and `en` / `pt-BR` localizations. Release emitted the existing Xcode AppIntents metadata-extraction warning (the app has no `AppIntents.framework` dependency); no Swift compiler warnings were emitted. The full `make test-core` run exited with the pre-existing M15 V8 image-QA failure (48 issues) and 62 `PetRuntime` issues in the same concurrent package run; isolated `PetRuntime` passed. These do not change the accepted M15 V8 exception or M18's deferred second-character criterion.

### Owner M17 closeout — 2026-10-24

After receiving the verification results and the exact native visual/VoiceOver/language-change
follow-up, the owner explicitly requested M17 closure, branch creation, commit, local merge to
`develop` and push. M17 is **Done by explicit owner acceptance** with the limits above: no native
visual layout, VoiceOver, or live macOS preferred-language change was observed during this run.
Automated UI assertions and locale-monitor unit tests do not substitute for those checks. The
complete package run retains the M15 V8 exception and the concurrent `PetRuntime` failures recorded
above; isolated `PetRuntime` and all six UI tests passed. No M15/M16/M18 exception or M18's deferred
second-character criterion is changed.

## M18 — Bundled character selection

- **Objective:** select one validated character shipped inside the application bundle.
- **Authorization:** explicit owner request on 2026-10-24 includes generic implementation even if
  fewer than two real packs exist; original-art changes remain prohibited. Subsequent owner closeout
  below separately authorizes branch creation, commit and local merge into develop.
- **Prerequisites:** M16 accepted. At M18 implementation/closeout, M17 remained separate and was not
  a technical blocker: existing SwiftUI literals were localizable without changing M18 selection
  behavior. M17 was later authorized and closed separately; its locale detection and translations
  are recorded in the M17 plan and owner closeout above.
- **Design:** bundle-only catalog at immediate `characters/*/character.json` roots, manifest IDs as
  identity, strict resource validation, independent image caches. A native Settings picker appears
  only with multiple valid packs; zero/one options have honest text. No extra menu or preview art.
  Load the candidate fully before a synchronous MainActor commit. Core replaces a settled pet at
  the same contact/facing/surface only when the new geometry fits. Busy physical/interaction states
  reject with a retry message, leaving the current pet unchanged; no deferred action queue.
- **Persistence:** additive `petscape.selectedCharacterID`, no migration/version change or per-pet
  preferences. Missing/removed/invalid IDs fall back to `cat`, then the first valid manifest ID in
  lexical order. Persist only after successful application. Zero valid packs use the existing
  placeholder and retain the saved ID for recovery. Restore Defaults resets existing global settings
  and retains the selected character (a content choice).
- **Scope boundary:** only the composition root supplies the bundle root; no user-folder search,
  external install/import or network (M19). Existing DEBUG explicit pack override remains diagnostic
  and does not enter the bundled catalog or persist its identity.
- **Implementation/verification:** T18.1–T18.6 and AC-M18-01…08 below the linked planning registers.
- **Status:** Done by explicit owner acceptance, 2026-10-24, with the limitations recorded below.
  Inventory remains only `cat` / “Cat”, schema 1, 12 clips, 200 frames. Historical V7/V8 manifests and
  V9 clips are not independent characters. The owner accepts closure of the generic implementation;
  real multi-character selection and its visual acceptance remain deferred, not claimed as verified.

### M18 execution plan — 2026-10-24

- [x] T18.1 Read instructions, architecture, schema, state machine, testing and M15/M16 closeouts;
  inspect clean develop, bundle-copy script, AppContainer → loader → runtime → world and preferences.
- [x] T18.2 Add catalog/strict loader tests first, run red, implement immediate-root discovery,
  reject duplicate IDs and any clip/resource error; keep lazy residency after validation.
- [x] T18.3 Test and implement additive preference, startup restore/fallback and transactional
  observable selection model with an injected async loader, cancellation/stop and informative errors.
- [x] T18.4 Test Core safe replacement and runtime commit for paused/hidden/busy/geometry cases;
  clear snapshots/layers/masks/events and isolate old lazy callbacks; preserve all global settings.
- [x] T18.5 Wire AppContainer and native Settings; add accessible zero/one/many presentation tests
  and UI assertions for the actual single bundled character; preserve diagnostic preview behavior.
- [x] T18.6 Run lint, package suite, app/UI tests, Debug/Release, real bundle validation and asset
  checks; record inherited V8 failure separately, evidence limits and precise second-pack handoff.

### M18 engineering evidence — 2026-10-24

At engineering handoff, the generic implementation was delivered and M18 remained Blocked.
The owner subsequently accepted closure with the recorded limitations. These checks do not
substitute for AC-M18-08 or visual acceptance with two real bundled characters.

| Gate | Actual result |
|---|---|
| `make lint`; `git diff --check` | Pass, including module import boundaries |
| `make test`; final `make test-core` | **538 package tests: 537 pass**. Core 338, Platform 42, Rendering 50 pass; Runtime 107/108 pass. The only failing test is the unchanged M15 V8 `newDrawingsAreDistinctOpaqueContainedAndRegistered` with **48 issues**; no test removed, weakened or skipped. The package failure prevents `make test` reaching app tests |
| Native `xcodebuild ... -configuration Debug test` | App and all four UI tests compile; execution cannot initialize UI testing: **Timed out while enabling automation mode**. No scenario is counted as passed. Earlier attempts had the same initialization blocker |
| Direct native inspection | Computer-use app inspection returned `timeoutReached`; no screenshot, visual swap or VoiceOver run was obtained |
| Final `make build` and Release `xcodebuild ... build` | Pass with Swift/compiler warnings treated as errors. Inherited AppIntents metadata-extraction warning remains; no new Swift warning |
| Actual Debug/Release character bundles | Exactly one `cat` / “Cat”, schema 1, 12 clips, 200 image references. Manifests and every bundled PNG are byte-identical to validated source; no missing or extra PNG. M16 audio consent description remains in both actual Info.plists |
| Runtime isolation regression | Actual failing old-family task handles are awaited after replacement and stop. Temporarily removing the started/character-identity guard makes **both** cases fail; guard restored before final gates |
| Geometry regressions | Oversized width/height at surface midpoint and primary/secondary-display window/floor bounds are covered. Secondary window-top test reproduced the primary-screen-helper defect before the local support-bound fix; final cases pass |
| Independent read-only review | Findings addressed; follow-up review reports no remaining actionable correctness issue |
| Original assets and closed milestones | `git diff --exit-code -- assets docs/planning/m15-implementation.md docs/planning/m16-implementation.md` passes: originals and closeouts unchanged |

Durable local evidence (ignored build output): `build/m18-test-core.log`, `build/m18-test.log`,
`build/m18-ui.log`, `build/m18-debug.log`, `build/m18-release.log`, `build/m18-lint.log`,
`build/m18-bundle-validation.log`, `build/m18-lifetime-mutation.log`, `build/m18-geometry-red.log`,
`build/m18-secondary-red.log` and `build/m18-geometry-green.log`. Native result bundle:
`build/DerivedData/Logs/Test/Test-PetScape-2026.10.24_12-53-53--0300.xcresult`.

AC-M18-01/03/05/06 have automated evidence; AC-M18-04 has deterministic fixture evidence including
paused/hidden and busy rejection, while real multi-character/native presentation remains unverified.
AC-M18-02 has model and compiled native test coverage, **not** a keyboard/VoiceOver execution pass.
AC-M18-07 preserves its inherited exceptions. AC-M18-08 remains unmet because owner content is
missing; it is explicitly deferred by the owner closeout, not converted into a passed criterion.

The real cat passes strict complete resource decoding, and its returned initial decoded-frame
residency remains ≤16 MiB after noninitial families are evicted. Discovery validates each pack,
releases validation images, and reloads the chosen candidate before commit; this intentionally adds
startup I/O/temporary decoding work. Peak process memory, swap/startup latency, CPU/energy and leaks
were **not measured**. Frame-byte assertions do not prove those performance targets. Existing V8
pixel findings and M16 permission/native/hardware evidence limits are preserved, not reapproved.
At engineering handoff, no commit, push, tag, release, PR, merge or branch creation had been
performed for M18. The later closeout separately authorizes the local Git integration below.

### M18 changed-file inventory

| Area | Files |
|---|---|
| Core | [PetWorld.swift](../../Packages/PetScapeKit/Sources/PetScapeCore/World/PetWorld.swift) |
| Platform | [PreferencesStore.swift](../../Packages/PetScapeKit/Sources/PetScapePlatform/Preferences/PreferencesStore.swift), [InMemoryPreferencesStore.swift](../../Packages/PetScapeKit/Sources/PetScapePlatform/Preferences/InMemoryPreferencesStore.swift), [UserDefaultsPreferencesStore.swift](../../Packages/PetScapeKit/Sources/PetScapePlatform/Preferences/UserDefaultsPreferencesStore.swift) |
| Runtime | `BundledCharacterCatalog.swift` (current successor: [CharacterCatalog.swift](../../Packages/PetScapeKit/Sources/PetScapeRuntime/Characters/CharacterCatalog.swift)), [CharacterLoader.swift](../../Packages/PetScapeKit/Sources/PetScapeRuntime/Characters/CharacterLoader.swift), `CharacterSelectionModel.swift` (M20 replacement: [CharacterRosterModel.swift](../../Packages/PetScapeKit/Sources/PetScapeRuntime/Characters/CharacterRosterModel.swift)), [PetRuntime.swift](../../Packages/PetScapeKit/Sources/PetScapeRuntime/PetRuntime/PetRuntime.swift), [SettingsModel.swift](../../Packages/PetScapeKit/Sources/PetScapeRuntime/Settings/SettingsModel.swift) |
| App | [AppContainer.swift](../../PetScape/App/AppContainer.swift), [SettingsView.swift](../../PetScape/SettingsView.swift) |
| Tests | [CharacterReplacementTests.swift](../../Packages/PetScapeKit/Tests/PetScapeCoreTests/World/CharacterReplacementTests.swift), [BundledCharacterSelectionTests.swift](../../Packages/PetScapeKit/Tests/PetScapeRuntimeTests/Characters/BundledCharacterSelectionTests.swift), [CharacterSwitchRuntimeTests.swift](../../Packages/PetScapeKit/Tests/PetScapeRuntimeTests/PetRuntime/CharacterSwitchRuntimeTests.swift), [PreferencesStoreTests.swift](../../Packages/PetScapeKit/Tests/PetScapePlatformTests/PreferencesStoreTests.swift), [PetScapeSettingsTests.swift](../../PetScapeUITests/PetScapeSettingsTests.swift) |
| Documentation | [AGENTS.md](../../AGENTS.md), [data-flow.md](../architecture/data-flow.md), [testing.md](../development/testing.md), [milestones.md](milestones.md), [task-breakdown.md](task-breakdown.md), [acceptance-criteria.md](acceptance-criteria.md) |

### M18 deferred content and native follow-up

Missing material: **one additional real character**, distinct from the existing `cat`. The owner
must choose its stable identity/name and supply a complete original pack under
`assets/characters/<stable-id>/character.json` plus every referenced PNG/sheet at pack-relative
paths. Do not rename/change the existing cat or duplicate its historical V7/V8 variants as choices.
The stable ID must match `^[a-z0-9][a-z0-9-]*$`, be unique and remain unchanged across later display-
name translations or folder renames. Replacing an ID is treated as removing the old character;
startup repairs its saved selection using the documented fallback policy.

Required data follows [schema v1](../specifications/animation-schema.md): schemaVersion, id,
displayName, defaultAnimation, canvas, displaySize, anchor and a playable animations dictionary,
with valid timing, paths and any deliberate fallbacks. Provide artwork/provenance and review the
physical anchors/contact and behavior presentation. Existing semantic clips include walk, idle,
jump-start, jump, fall, landing, curious, picked-up, held, climb, dance and cleanup; absent optional
clips may deliberately use the schema's fallback/default contract, but a declared broken clip
excludes the selection. No dedicated preview image is required; the current UI uses text names.
The bundle-copy phase already includes all immediate complete pack roots, so no subclass, new
schema, external installer or additional runtime registry is needed.

After delivery: add the real pack without changing originals, rebuild Debug/Release, validate the
actual bundled resources, extend the real catalog inventory assertion beyond its current one-cat
baseline, run package/UI gates, and perform the manual matrix below. Only then review AC-M18-08
and obtain owner acceptance of real multi-character behavior; synthetic test packs never satisfy
that criterion. This content follow-up does not reopen the owner's acceptance of the generic M18
implementation unless the owner requests it.

Remaining native acceptance: zero/one/multiple presentation, active checkmark/name, keyboard and
VoiceOver, restart, failure without losing current pet, pause/hide, current window-top support on
both displays, rejected flight/held/climb/busy phases and fit rejection. Native process peak memory,
matched startup/swap timing, CPU/leaks and alternate macOS/Xcode hardware are not established by
frame-byte assertions or fixtures. See [M18 test matrix](../development/testing.md#m18-character-selection).
M17 localization and M19 external installation are separate milestones, not missing M18 engineering.

### Owner M18 closeout — 2026-10-24

After being explicitly informed that generic engineering was complete, only `cat` was bundled,
UI/VoiceOver execution was blocked by Automation Mode timeout and the existing V8 test still
failed, the owner requested: “pode fazer a finalização, criando a branch, commitando, fazendo o
merge para a develop e marando como concluído”. This is explicit acceptance of M18 closure with
those known limitations and authorization for local branch creation, Conventional Commit and
merge into develop. It does not authorize push, release, tag, PR or M17/M19/M20 implementation.

M18 is **Done by explicit owner acceptance**. This closes the generic bundled-catalog, validated
selection transaction, persistence/fallback, Settings presentation, tests and documentation.
It does **not** assert that a user can currently choose between two real characters: only `cat`
ships. AC-M18-08 remains unmet and deferred until a second original pack is supplied and reviewed.
Compiled native tests are not a keyboard, VoiceOver or visual-swap pass; Automation Mode timeout,
unmeasured peak memory/startup/CPU/leaks and alternate-hardware limits remain explicit. The M15
V8 pixel-QA failure and M16 closeout remain unchanged. No test or original art was altered to make
closure appear green. The deferred material and native matrix above remain actionable follow-ups.

Local integration: `feature/M18-bundled-character-selection` → `develop`. Fresh closeout
verification is recorded below; no remote publication is implied.

| Fresh closeout check | Result |
|---|---|
| `make lint`, documentation links and `git diff --check` | Pass |
| `make test-core` | 538 tests: 536 pass in this run. Core 338, Platform 42 and Rendering 50 pass; Runtime 106/108 pass. The inherited V8 test has 48 issues; the unchanged `trackedWindowSurfaceEntersWorldAndBecomesAJumpDestination` also rejected a jump because the real desktop reported `.fullScreenSpace` suspension |
| Isolated unchanged window-test retry | 1/1 passes. The full-run log establishes an environment-sensitive failure, not a repaired product defect or an entirely green full suite; no test was changed or weakened |
| `make build` | Debug succeeds; inherited AppIntents metadata warning remains |
| Original asset and M15/M16 closeout diff | No changes |

Local closeout logs: `build/m18-closeout-tests.log`, `build/m18-closeout-lint.log` and
`build/m18-closeout-debug.log`; isolated retry: `build/m18-closeout-window-retry.log`.
Previously recorded Release/build-bundle and native-timeout evidence
above remains unchanged; no new native/performance success is claimed at owner acceptance.

## M19 — Character pack discovery and installation

- **Objective:** discover and install character packs.
- **Authorization:** the owner explicitly requested end-to-end M19 implementation on 2026-10-24. The owner later accepted closure and authorized local branch/commit/merge. At that time this did not authorize M20, network, publication, push, tag, release or PR.
- **Scope:** local folder selection, bounded validation, atomic installation, immediate-directory discovery in `~/Library/Application Support/PetScape/Characters`, and integration with M18 selection. No ZIP, network, publishing, update/overwrite, or in-app removal.
- **Prerequisites:** M18 selection and M17 localization are accepted. Their closeouts and evidence limits remain unchanged.
- **Status:** **Done by explicit owner acceptance, 2026-10-24, with evidence limits recorded below.** The real external-pack/manual flow gate remains unverified and is not recorded as passed.
- **Current contract:** choose a folder with root `character.json` (schema v1). Copy only the manifest and referenced PNGs. Ignore and omit unreferenced files. Reject symlinks, aliases, special files, unsafe paths and unsupported image content. Stage under the destination, validate the snapshot and staged copy, then promote exclusively and atomically to a folder named by manifest ID. Duplicate IDs are rejected; update and in-app removal are out of scope. External deletion/edits are detected after restart; a missing persisted selection uses M18 fallback after successful application.
- **Resource limits:** 256 KiB manifest; 2,048 scanned tree entries/32 levels; 64 clips, 512 frame entries, 64 sheets with at most 16×16 cells; 256 unique referenced PNGs; 4 MiB per PNG/64 MiB aggregate referenced source bytes; 4,096 px per source dimension; 768 px target side; 64 MiB estimated decoded bytes across referenced images. Current cat art has 200 frame entries, 200 unique PNGs and ~45.2 MB referenced source bytes, within this profile. These are import bounds, not measured performance guarantees.
- **Verification:** T19.1–T19.5 and AC-M19-01…10 are specified in the [task breakdown](task-breakdown.md#m19--character-pack-discovery-and-installation-authorized-2026-10-24) and [acceptance criteria](acceptance-criteria.md#m19--character-pack-discovery-and-installation).
- **Implementation verification (2026-10-24):** `make format` and `make lint` passed. The focused M19 package suite passed all 15 tests; the full package run embedded in `make test` also passed M19. That full run exited nonzero only for the existing M15 `newDrawingsAreDistinctOpaqueContainedAndRegistered` V8 pixel-QA exception (48 recorded issues): Core passed 338 tests/32 suites, Rendering 50/10 and Platform 47/9 passed, and the Runtime run recorded 123 tests/13 suites with the M19 suite passing and the 48 M15 issues. `make test` stopped before its app/UI phase, so UI was run separately: all 8 UI tests passed, including the native picker cancellation, isolated installed-pack discovery/selection/relaunch, empty catalog, pt-BR Settings and M18 keyboard selection. `make build` Debug and the Release `xcodebuild` build passed; no Swift compiler warnings were emitted. Release reported Xcode's existing AppIntents metadata-extraction warning because the app has no `AppIntents.framework` dependency. The String Catalog compiled with 114 entries and pt-BR values, emitted-string synchronization had no missing translations, and the bundled asset copy/validation script produced 201 files. Environment: macOS 27.0.1, Xcode 27.1.
- **Evidence limits:** no owner-supplied external pack was present. Automated installer tests use temporary valid/invalid fixtures; UI automation exercised native picker cancellation and a separately pre-populated isolated installed directory, not a successful real-pack selection in the native picker. A successful real external import/select/relaunch and visual review in English and pt-BR, VoiceOver review, and measured imported-art performance remain unverified. These are accepted limitations for this owner-directed closeout, not passed checks; fixtures do not satisfy the real-pack/manual gate.

### Owner M19 closeout — 2026-10-24

After receiving the full test results and the outstanding real-pack/manual evidence limits, the owner
explicitly directed finalization, branch creation, commit and local merge into `develop`. M19 is **Done
by explicit owner acceptance** with those limitations retained. No external real-pack import or
successful native-picker selection was verified; the English/pt-BR visual review, VoiceOver review and
imported-art performance measurements remain unverified. The 48-issue M15 V8 pixel-QA exception is
unchanged and is not attributed to M19.

The owner authorized local Git integration only. No push, tag, release or PR is authorized by this
closeout. At that closeout, M20 remained Not started and unauthorized. The unmet manual components of AC-M19-01,
AC-M19-08 and AC-M19-10 are recorded as accepted evidence limits, not passed criteria.

## M20 — Settings redesign & multiple active characters (planned 2026-10-24; accepted 2026-10-25)

- **Objective:** replace the crowded Settings presentation with a clear native macOS layout, and allow one active pet per unique character pack at the same time.
- **Authorization:** the owner explicitly requested end-to-end M20 implementation on 2026-10-25 and directed use of `feature/T20-settings-multi-pet`. On 2026-10-25, the owner reported that the final autonomy-variety refinement worked perfectly after testing, accepted M20 closure, and authorized branch commit, local merge into `develop`, and push. This does not authorize M21, tag, release or PR.
- **Status:** **Done by explicit owner acceptance**, with the evidence limits below retained. Existing M18/M19 acceptance records and evidence limits remain unchanged.
- **Scope:** redesign Settings presentation from the ground up while preserving every existing setting, action, permission explanation, status, import flow, localization and persistence behavior; replace single-character selection/replacement with an active roster that can contain at most one instance for each valid bundled or installed character ID; add/remove roster entries independently; ensure each spawned pet owns independent behavior, movement, animation, timing, interaction and lifecycle state. Existing `cat` and `human-programmer`/Dimas packs are examples, not hard-coded special cases.
- **Suggested Settings information architecture:** a native tab or sidebar layout with (1) Pets and pack management, (2) Behavior and music, (3) Appearance and placement, (4) Interaction, and (5) General. Pets should show each active character as an accessible row/card with source label, per-pet Dance/Stop Dance when eligible, and an individual Remove action; a clear Add Character picker should list only inactive valid packs and disable duplicates. Keep import progress/errors and empty/loading states in the pack-management area. The implementation agent may improve this proposal after auditing the current Settings and native macOS conventions.
- **Shared preferences versus independent state:** settings that are currently global (pause/hide, scale/speed, autonomy toggles, music detection, window/cursor interaction, login item and Dock offset) remain global unless a documented existing contract says otherwise. Runtime state is per `PetID`: autonomous choices and timers, random sequence, dance duration/phase, animation frame, position/velocity/surface, interaction/hold, climbing/window excursion, and cleanup must not be copied, mirrored or synchronized between pets. Preserve the current rule that a music-start signal reaches each eligible pet; each pet then advances its own behavior and bounded dance interval using its independent seeded state, so synchronized copies of another pet's later behavior do not occur.
- **Persistence:** replace the singular active-character preference with a versioned/list preference appropriate to the existing store. Migrate an existing valid `petscape.selectedCharacterID` into a one-entry roster without losing the user's selection; preserve sensible first-launch/default and Restore Defaults behavior; safely handle unknown, missing, invalid and duplicate IDs. Do not create duplicate instances for one stable character ID.
- **Resource policy:** lazy-load assets for active characters, release resources after removal when safe, and evaluate aggregate memory/frame cost against existing per-pack limits and `docs/specifications/performance.md`. Support all valid unique catalog entries unless measured evidence requires a concurrency cap; any cap must be justified, documented, localized and exposed accessibly. Do not claim performance targets without measurement.
- **Prerequisites:** M17 localization, M18 character selection and M19 local pack discovery/installation accepted. Preserve their historical closeouts; M20 supersedes the one-active-character constraint without rewriting prior evidence.
- **Non-goals:** new art/image generation, new character packs, new animation behaviors, network discovery, pack publishing, release signing/notarization/CI, and distribution. The existing release pipeline moves to M21.
- **Risks:** per-pet identity and asset ownership leaking across render/runtime boundaries; old singular preferences being lost; global controls becoming ambiguous; aggregate resources scaling with roster size; Settings redesign regressing accessibility or localization.
- **Verification:** Core/runtime lifecycle and independence tests; migration and invalid-roster tests; per-pet manual-action targeting tests; Settings UI/model assertions for zero/one/many installed and bundled entries, add/remove/duplicate prevention, statuses and localization; keyboard/VoiceOver review; lint, package/UI suites, Debug/Release builds, and relevant asset validation. Retain the known M15 V8 pixel-QA exception rather than suppressing it.
- **Definition of Done:** AC-M20-01…AC-M20-12 pass or each unverified native/manual evidence item is explicitly recorded for owner review without being reported as passed; all existing Settings behavior remains available; simultaneous distinct pets remain independently simulated and controllable; migration is tested; docs and localization are complete; no unresolved implementation task remains.

### M20 owner closeout (2026-10-25)

The owner explicitly accepted M20 closure after testing and confirming that the final autonomous
animation-variation refinement worked as expected. The owner authorized committing the existing
`feature/T20-settings-multi-pet` branch, merging it locally into `develop`, and pushing the result.
The existing M15 V8 pixel-QA exception remains a failed package gate, not a product pass; VoiceOver
and complete keyboard traversal, supported-minimum Settings size, and matched native Release CPU/
physical-footprint comparison remain unverified and accepted evidence limits. The separate UI suite,
Debug/Release builds, real Dimas pack integration and focused autonomy/window-climb tests are recorded
in the [M20 implementation closeout](m20-implementation.md#owner-closeout--2026-10-25). M21, tags,
releases and PRs remain out of scope.

## M21 — Release pipeline

- **Objective:** produce a repeatable macOS release package and GitHub release workflow without paid Apple Developer membership.
- **Authorization:** the owner explicitly requested end-to-end M21 local implementation on 2026-10-25 using `feature/T21-adhoc-release`, without paid Apple membership. That original local scope excluded Git/publication; the subsequent explicit publication authorization below supersedes it for v1.0.0. Do not add Developer ID, notarization, App Store distribution or Apple credentials. See the [implementation and evidence](m21-implementation.md).
- **Status:** **Done; v1.0.2 published**, 2026-10-25. The [V8 closeout publication](m21-implementation.md#v102-v8-closeout-publication--2026-10-25) passed every strict hosted gate with no release failure waiver; 574-test package rounds report the exact 48 owner-accepted known findings. Public DMG/README download, checksum, mounted payload, offline guide and artwork acceptance record were verified without authentication. Earlier local/release records remain historical. Native Intel execution and complete clean-machine approval/relaunch remain unverified.
- **Scope:** version/changelog validation, Release archive, ad-hoc code signature, DMG or ZIP packaging, SHA-256 checksum, minimal-permission GitHub Actions build/release workflow, and English/pt-BR installation and security guidance. Provide a local release script using the same steps as CI. A dry-run must not publish a release.
- **Signing and Gatekeeper contract:** ad-hoc signature permits integrity verification but does not identify a developer. The artifact cannot be notarized, and downloaded copies may trigger Gatekeeper warnings or require a user-approved override in System Settings. Do not claim `spctl --assess` acceptance, notarization, identified-developer status or warning-free launch. Never disable Gatekeeper or strip quarantine attributes as a product workaround. Explain the supported manual override cautiously and only for users who trust the downloaded artifact and verified its checksum.
- **Prerequisites:** M20 accepted; no paid Apple Developer Program membership is available or required for this M21 scope. Confirm repository visibility and GitHub Actions runner/usage constraints before selecting automation.
- **Risks:** Gatekeeper friction and reduced provenance/identity assurances; artifact/checksum replacement together remains possible; GitHub Actions minutes/storage may be quota-limited for private repositories.
- **Verification:** local Release build/package and signature-integrity checks; checksum round-trip; CI dry-run that uploads an artifact without publishing; release-workflow permissions and dependency review; installation on a clean supported macOS environment to record the actual Gatekeeper flow. Run and report all existing quality gates, preserving the accepted M15 V8 failure accurately.
- **Definition of Done:** AC-M21-01…AC-M21-08 pass; a clean Release artifact can be built locally and by CI without Apple credentials; package, version and checksum are validated; installation instructions describe the real security prompts; no code/docs/workflow item in M21 remains. Publishing v1.0.0, creating a tag, pushing, or overriding a failing pre-existing quality gate requires a separate explicit owner instruction.

### v1.0.0 publication authorization — 2026-10-25

The owner subsequently explicitly requested Git integration, updating branches and publishing a
release with a ready-to-install download linked from the README. Commit/merge/push/tag/publication
are now authorized for this release. The owner also expressly approved publishing v1.0.0 with the
existing V8 48-issue pixel-QA exception documented, keeping the failed test and original assets
unchanged; all other gates must pass. D-08 is resolved by owner confirmation of art redistribution
in the app with rights reserved, while source remains MIT. Official packages are universal
arm64/x86_64 DMG and ZIP for macOS 14+. Native Intel/clean-machine evidence remains unverified.
Actual publication and CI results: [M21 publication follow-up](m21-implementation.md#v100-publication-follow-up--2026-10-25).
