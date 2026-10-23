# Debugging & Observability

All diagnostics are local. No external services. DEBUG-only tooling is compiled out of Release
(`#if DEBUG`).

## Logging (OSLog)

Categories and levels: [conventions.md](conventions.md#logging). Subsystem = bundle identifier.

Stream logs while the app runs:

```bash
log stream --level debug --predicate 'subsystem == "io.github.danielcbdev.petscape"'
```

Filter one category:

```bash
log stream --level debug --predicate 'subsystem == "io.github.danielcbdev.petscape" AND category == "overlay"'
```

Console.app works too (enable "Include Debug Messages").

## Signposts

`OSSignposter` intervals (category `performance`): `frame`, `simulationStep`, `render`,
`passthroughUpdate`, `characterLoad`, `imageDecode`; events: `runStateChanged`, `surfaceChanged`.
Inspect with Instruments › os_signpost / Points of Interest.

## DEBUG menu (menu bar, DEBUG builds only)

| Item | Milestone |
|---|---|
| Show overlay bounds | M3 |
| Show pass-through state (tint when interactive) | M3 |
| Animation Preview (done in M4): plays any clip in place at 1×/1.5×/2× with the anchor baseline and cross, mirroring toggle, declared vs. measured frame rate; logs `Animation preview '<clip>': measured N frame changes/s` (category `animation`). Since M5 the baseline has tick marks scrolling at a ground speed (starts at the clip's `nominalSpeed`, stepper to adjust): planted paws should move with the ticks (foot sliding, AC-07). Frame-by-frame stepping is not implemented yet | M4–M5 |
| Show anchor, hit mask, sprite bounds | M4–M5 |
| Show walkway (done in M6): the pet's surface as a 1 pt green line whose top edge is the surface y; the Dock estimate and walkway are logged (category `dock`) | M5–M6 |
| Show pet state, clip, frame, facing, needs | M5–M9 |
| Frame stats (step time, frame-image memory) from signposts/counters; the measured frame rate is logged instead (see below) | later |
| Dock offset (done in M6): submenu "Dock offset: +0 pt" with Raise/Lower 1 pt and 5 pt and Reset; persisted (`petscape.dockOffsetAdjustment`) | M6 |
| Jump vertically; short jump left/right (60 pt); jump to Dock; Idle; Walk (implemented). Commands preserve walk/idle return intent; rejected while paused/hidden/suspended, busy, unreachable or in the 2 simulated-second cooldown. Current walk-only art holds a safe fallback pose in flight. | M8 |
| Simulation speed (0.25×, 1×, 4×) and single-step while paused | Deferred |
| Force events (surface lost, startled, low energy) | M7–M9 |
| Show window surfaces (DEBUG-only pink dashed top and side segments; no names or titles) | M12–M13 |

DEBUG launch arguments (ignored in Release):

| Argument | Effect |
|---|---|
| `--animation-preview` | Opens the Animation Preview as soon as the character has loaded |
| `--character-pack <folder>` | Loads that pack folder instead of the bundled cat (e.g. to check a broken manifest: placeholder, menu status line, `assets` error log) |

```bash
open -n build/DerivedData/Build/Products/Debug/PetScape.app --args --animation-preview
```

The M3 test rectangle and the "Pause frames" / "Hide overlay" stand-ins were removed in M5: the cat is the
pass-through target and the real Pause/Resume and Show/Hide Pet items drive the run state.

DEBUG log lines added in M5 (useful predicates: `category == "simulation"`, `category == "performance"`):

| Line | Meaning |
|---|---|
| `Pet 1 'cat' spawned on screen:<id>:bottom` (notice) | Character handed to the runtime and placed |
| `Pet 1: walking → turning`, `Pet 1 reached an edge` (debug) | State machine transitions; the turn hold is the time between `walking → turning` and `turning → walking` |
| `Pet 1 recovered: <reason>` (error) | An invariant failed (out of bounds, invalid numbers, invalid contact or airborne timeout); ordinary surface loss is a separate physical event |
| `Mouse down on pet 1 at (x, y)` (debug) | A click reached the overlay over the cat's opaque pixels (AC-M5-02) |
| `Frames: 60.0 fps, 60.0 steps/s over 10.0 s` (debug, `performance`) | Delivered display-link rate while frames run (T5.7) |

Log lines added in M6 (all builds; predicate `category == "dock" OR category == "overlay"`):

| Line | Meaning |
|---|---|
| `Dock estimate: bottom on screen 1, inset 64.0 pt, edge at 64.0` (notice, `dock`) | New estimate after a screen change (`hiddenOrUnknown` when auto-hidden) |
| `Walkway dock (dockTop) at y=64.0, x 0.0…1470.0, offset 0.0 pt` (notice, `dock`) | The pet's surface changed (estimate or offset) |
| `Host screen: <id>` (notice, `overlay`) | The overlay moved to another screen (the Dock's) |
| `Screen parameters changed: [...]` (notice, `overlay`) | `didChangeScreenParametersNotification` with the new frames — the evidence for resolution, Dock and display changes |
| `Screens changed while suspended: [...]` (notice, `overlay`) | The fallback re-read after wake/unlock found a change no notification reported |

```bash
log stream --level info --predicate 'subsystem == "io.github.danielcbdev.petscape" AND (category == "dock" OR category == "overlay")'
```

The debug overlay is drawn by `DebugOverlayLayer` (`CAShapeLayer`s) in `OverlayContentView` from data in the snapshot; it must
not affect simulation.

## Profiling

| Question | Tool |
|---|---|
| CPU per frame / hot paths | Instruments Time Profiler (release build, launched outside Xcode) |
| Frame pacing, hitches | Instruments Animation Hitches / Core Animation FPS; signposts |
| Energy | Activity Monitor Energy tab; Instruments Energy Log (if available on the OS) |
| Wakeups while idle | Activity Monitor "Idle Wake Ups"; `top -stats pid,command,cpu,idlew` |
| Memory, textures | Instruments Allocations / VM Tracker; `FrameImageStore` debug counter |
| Leaks, retain cycles | Instruments Leaks; Xcode Memory Graph Debugger |
| Main-thread stalls | Xcode Thread Performance Checker; Instruments Hangs |

Protocol and targets: [performance.md](../specifications/performance.md).

## Common issues (to grow with experience)

| Symptom | Likely cause | Check |
|---|---|---|
| Cat offset by ~24–37 pt vertically | Quartz/AppKit flip or menu bar height mix-up | All conversions via `CoordinateConverter`? `NSScreen.main` used instead of the primary screen? |
| Clicks blocked near the cat | Pass-through stuck interactive | DEBUG tint; pass-through logs |
| Cat huge or tiny | Layer bounds taken from image pixels | Bounds must come from `displaySize` |
| CPU high while paused | A timer or monitor still running; display link not paused | Run-state logs; Time Profiler |
| Accessibility permission "forgotten" | Rebuilt with a different signing identity | Use a stable dev identity |
| DEBUG "Show window surfaces" displays nothing | It draws only surfaces already delivered by the opt-in tracker | The submenu now reports whether interaction is off, Accessibility is missing, or zero visible top/side segments were found; check Settings › Interact with windows |

M7/M8 physical events (`simulation` category): surface lost, landed, took off, apex, jump rejected
(with typed reason) and jump cancelled. These are emitted once per transition/request; art markers
never apply impulse or change contact. DEBUG jump commands use the same world validation as tests.
