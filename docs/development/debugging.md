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
| Animation Preview (done in M4): plays any clip in place at 1×/1.5×/2× with the anchor baseline and cross, mirroring toggle, declared vs. measured frame rate; logs `Animation preview '<clip>': measured N frame changes/s` (category `animation`). Frame-by-frame stepping is not implemented yet | M4 |
| Show anchor, hit mask, sprite bounds | M4–M5 |
| Show surfaces (segments with IDs) and Dock estimate | M5–M6 |
| Show pet state, clip, frame, facing, needs | M5–M9 |
| Frame stats (measured FPS, step time, frame-image memory) from signposts/counters | M5 |
| Dock offset stepper | M6 |
| Simulation speed (0.25×, 1×, 4×) and single-step while paused | M7 |
| Force events (surface lost, startled, low energy) | M7–M9 |
| Show window surfaces and tracked windows | M12 |

DEBUG launch arguments (ignored in Release):

| Argument | Effect |
|---|---|
| `--animation-preview` | Opens the Animation Preview as soon as the character has loaded |
| `--character-pack <folder>` | Loads that pack folder instead of the bundled cat (e.g. to check a broken manifest: placeholder, menu status line, `assets` error log) |

```bash
open -n build/DerivedData/Build/Products/Debug/PetScape.app --args --animation-preview
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
