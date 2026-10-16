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

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T7.1 | `PhysicsTuning` + airborne integration (semi-implicit Euler, terminal velocity) | Core | M6 | S | U |
| T7.2 | Swept landing against `SurfaceMap` (highest crossed segment) | Core | T7.1 | M | U (speeds up to terminal, stacked segments) |
| T7.3 | `ScreenEdgeSurfaceProvider`: `.screenBottom` floor for each screen | Plat, Core | M6 | S | U |
| T7.4 | HSM foundation: `Grounded`/`Airborne` parents, `Falling`, `Landing`; replace respawn on `surfaceLost` | Core | T7.2 | L | U (transition table) |
| T7.5 | Walk-off decision at Dock ends (turn vs drop, probability from `BehaviorTuning`) | Core | T7.4 | S | U (seeded) |
| T7.6 | Dock hidden at runtime → fall to floor; Dock shown → remains on floor | Core | T7.4 | S | U + Man |
| T7.7 | Invariant checks and recovery (NaN, out of bounds, stuck) | Core | T7.4 | S | U |
| T7.8 | Manifest fallbacks for `fall`/`land`; integrate art when delivered | Assets | T7.4 | S | U (validation) + Man |

## M8 — Jumps & landings

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T8.1 | `JumpSolver` (target point + apex height → initial velocity, flight time) | Core | M7 | S | U (tolerance ≤ 1 pt) |
| T8.2 | Jump states (`JumpStart`, `Rising`, `Falling`, `Landing`) with `takeoff`/`apex`/`contact` events | Core | T8.1 | M | U |
| T8.3 | Jump target selection between floor and Dock top (reachability, clearance) | Core | T8.2 | M | U |
| T8.4 | Event-driven takeoff (velocity applied on `takeoff` frame) | Core | T8.2 | S | U |
| T8.5 | Art integration + tuning session; screen recording for owner review | Assets | T8.4 | M | Man (owner) |

## M9 — Autonomous behaviors & Settings v1

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T9.1 | `Needs` model and drift rules | Core | M7 | S | U |
| T9.2 | `Personality` from manifest with defaults | Core | T9.1 | S | U |
| T9.3 | `ActivitySelector` scoring + weighted top-k choice | Core | T9.2 | M | U (seeded scenarios) |
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
| T10.1 | Cursor perception (position, velocity) in `WorldInput` | Core, Run | M9 | S | U |
| T10.2 | Observe/approach/startle behaviors | Core | T10.1 | M | U |
| T10.3 | Drag: grab on mouse-down over pet, `Dragged` state, grab offset; pass-through stays interactive until mouse-up | Core, Run, Rend | T10.1 | M | U + Man |
| T10.4 | Throw: release velocity estimate → `Airborne` | Core | T10.3 | S | U |
| T10.5 | Click reaction (single, minimal) | Core | T10.3 | S | U + Man |
| T10.6 | Edge cases: drag while paused (allowed, resumes simulation for the pet? decide), drag beyond screen, app quit during drag | Run | T10.3 | S | Man |

## M11 — Edge climbing

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T11.1 | Wall surfaces (screen left/right) | Core, Plat | M8 | S | U |
| T11.2 | Climbing motion mode and states; alignment-aware rendering (rotation/anchor) | Core, Rend | T11.1 | L | U + Man |
| T11.3 | Transitions: walk into wall → climb; climb to height → descend or drop | Core | T11.2 | M | U |
| T11.4 | `climb` art integration | Assets | T11.2 | S | Man |

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

## M15 — Release pipeline

| ID | Task | Mod | Deps | Size | Verify |
|---|---|---|---|---|---|
| T15.1 | Owner decisions: license, final bundle ID, Developer ID enrollment | Owner | — | S | Recorded in risks.md |
| T15.2 | Versioning (`MARKETING_VERSION`, build number) + `CHANGELOG.md` (Keep a Changelog) | Repo | T15.1 | S | Review |
| T15.3 | Archive/export script with Developer ID signing | Repo | T15.1 | M | Signed app verified with `codesign --verify` |
| T15.4 | Notarize (`notarytool`), staple, build DMG, notarize DMG | Repo | T15.3 | M | `spctl --assess` passes |
| T15.5 | GitHub Actions release workflow on tags (secrets via repository secrets, temporary keychain) | Repo | T15.4 | M | Dry run on a test tag |
| T15.6 | Install/upgrade docs in README and release notes template | Docs | T15.4 | S | Review |
