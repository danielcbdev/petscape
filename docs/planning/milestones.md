# Milestones

Tasks: [task-breakdown.md](task-breakdown.md). Criteria: [acceptance-criteria.md](acceptance-criteria.md).
Every milestone's Definition of Done also includes the task-level quality bar in
[AGENTS.md §15](../../AGENTS.md#15-quality-bar-definition-of-done-for-any-task).

## Status

| ID | Milestone | Release | Status |
|---|---|---|---|
| M0 | Repository preparation & planning | — | **Done** (approved 2026-10-16; commit pending, T0.6) |
| M1 | Overlay proof of concept | — | **Done** (2026-10-16; recommendation: go for M2 — see [conclusion](proof-of-concept.md#conclusion-t19)) |
| M2 | App skeleton | v0.1.0 | In review (2026-10-18: `make test` and UI launch/Quit test passed in Automation Mode; T2.8 CI awaits D-06) |
| M3 | Transparent overlay | v0.1.0 | In review (owner approved the manual matrix; resolution-change log evidence still missing, PoC S8) |
| M4 | Animation system | v0.1.0 | **Done** (2026-10-18: lint, package tests, build, 9.00 fps DEBUG preview and owner anchor check verified) |
| M5 | Rendering & automatic walking | v0.1.0 | In review (2026-10-18: lint, 256 package tests, build and owner visual checks passed; full AC-14 click-through matrix around the walking cat remains) |
| M6 | Dock integration & MVP hardening | v0.1.0 | In review (2026-10-18: implementation checks and owner manual checks passed; resolution-change log evidence remains missing and external-display checks are unavailable — see the M6 block) |
| M7 | Basic physics | v0.2.0 | Not started |
| M8 | Jumps & landings | v0.2.0 | Not started |
| M9 | Autonomous behaviors & Settings v1 | v0.3.0 | Not started |
| M10 | Cursor interaction & dragging | v0.4.0 | Not started |
| M11 | Edge climbing | v0.4.0 | Not started |
| M12 | Window detection | v0.5.0 | Not started |
| M13 | Window interaction | v0.5.0 | Not started |
| M14 | Multi-display, optimization & stabilization | v1.0.0 | Not started |
| M15 | Release pipeline | v1.0.0 | Not started |

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

- **Objective:** gravity, falling and landing; robust surface loss handling.
- **Scope:** kinematic airborne integration, swept landing, floor surfaces, HSM foundation (Grounded/Airborne), walk-off and Dock-hide falls, invariant recovery.
- **Prerequisites:** M6.
- **Modules:** Core (Physics, Behavior, Surfaces), Platform (screen edges).
- **Dependencies:** `fall`/`land` art optional (fallbacks).
- **Risks:** tunneling; feel tuning.
- **Tests:** physics tables, landing at speeds, surface removal, NaN guards.
- **DoD:** FR-20 met; no respawn-based recovery remains for surface loss.

## M8 — Jumps & landings

- **Objective:** purposeful jumps between surfaces with animation-synchronized takeoff/landing.
- **Scope:** jump solver, jump states, target selection (floor ↔ Dock), event-driven takeoff, art integration.
- **Prerequisites:** M7.
- **Modules:** Core (Physics, Behavior, Animation events).
- **Dependencies:** `jump-*`/`land` art (fallbacks otherwise).
- **Risks:** unconvincing arcs → tuning session.
- **Tests:** solver accuracy, state transitions, event timing.
- **DoD:** FR-21 met; recorded demo reviewed by owner.

## M9 — Autonomous behaviors & Settings v1

- **Objective:** the cat feels alive: rests, sleeps, stretches, observes; users can tune it.
- **Scope:** needs, personality, activity selector, resting/expressive states, cooldowns, adaptive render per state, Settings window, launch at login.
- **Prerequisites:** M7 (M8 recommended).
- **Modules:** Core (Behavior), Platform (LoginItem, Preferences), App (Settings), Rendering.
- **Dependencies:** idle/sit/sleep/stretch art.
- **Risks:** behavior feels random/repetitive.
- **Tests:** seeded scenario tests; settings persistence; UI tests for Settings.
- **DoD:** FR-22, FR-23 met; playtest notes recorded.

## M10 — Cursor interaction & dragging

- **Objective:** the cat notices the cursor and can be picked up and thrown.
- **Scope:** cursor perception, observe/approach/startle, drag, throw, click reaction, edge cases.
- **Prerequisites:** M9 (needs HSM + selector), M7 (airborne).
- **Modules:** Core, Runtime (pass-through during drag), Platform (Input).
- **Risks:** stealing clicks; drag state stuck.
- **Tests:** perception and drag state tests; manual click/drag matrix.
- **DoD:** FR-24, FR-25 met; no click-through regressions.

## M11 — Edge climbing

- **Objective:** the cat climbs the left/right screen edges.
- **Scope:** wall surfaces, climbing motion and states, alignment rendering, art.
- **Prerequisites:** M8.
- **Modules:** Core, Rendering (alignment).
- **Dependencies:** `climb` art.
- **Risks:** rotation/anchor visuals.
- **Tests:** climbing transitions, alignment math.
- **DoD:** FR-26 met.

## M12 — Window detection

- **Objective:** opt-in, reliable, cheap tracking of other apps' windows.
- **Scope:** spike, permission flow, CGWindowList and AX adapters, tracker, surface builder, debug visualization, revocation.
- **Prerequisites:** M7 (surfaces as diffs). Can run parallel to M8–M11.
- **Modules:** Platform (WindowTracking, Permissions), Core (WindowSurfaceBuilder), App (Settings).
- **Risks:** AX limitations, correlation without private API, CPU.
- **Tests:** builder tests (z-order, clipping); adapter fixture tests; manual app matrix.
- **DoD:** FR-27 met; ≤ 1% CPU idle with tracking on.

## M13 — Window interaction

- **Objective:** the cat walks on, rides and jumps between windows.
- **Scope:** window surfaces in the world, riding, close/minimize falls, jumps between windows, occlusion changes.
- **Prerequisites:** M12, M8.
- **Modules:** Core, Runtime.
- **Risks:** jitter when riding; surprising behavior with many windows.
- **Tests:** riding/teleport/removal tests; manual matrix.
- **DoD:** FR-28 met.

## M14 — Multi-display, optimization & stabilization

- **Objective:** v1.0 quality.
- **Scope:** overlays on all screens + hand-off, single frame driver, texture policy, interpolation (if needed), lazy clips, bundle strip, soak/leaks, macOS 14 VM pass, VoiceOver audit, perf regression checks.
- **Prerequisites:** M10, M11, M13.
- **Risks:** multi-display edge cases.
- **Tests:** full manual matrix; 8 h soak; performance protocol.
- **DoD:** FR-29, NFR-01..13 verified.

## M15 — Release pipeline

- **Objective:** reproducible, signed, notarized releases on GitHub.
- **Scope:** owner decisions (license, bundle ID, Developer ID), versioning, changelog, archive/export, notarization, DMG, GitHub Actions release workflow, install docs.
- **Prerequisites:** M14; Apple Developer Program membership.
- **Risks:** secrets handling in CI; notarization failures.
- **Tests:** dry-run release on a tag in a fork/branch; Gatekeeper check on a clean machine/VM.
- **DoD:** FR-30 met; v1.0.0 published when asked.
