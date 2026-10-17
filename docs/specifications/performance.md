# Performance

PetScape may run all day, so energy is a product requirement (NFR-01, NFR-02).
**All numbers below are targets to validate by measurement, not guarantees.** They are first
calibrated by PoC E7 and revised with evidence.

## Targets (MVP, one pet, Apple silicon, release build)

| Metric | Target | Measured with |
|---|---|---|
| CPU while walking (60 fps) | ≤ 5% of one core average over 60 s | Activity Monitor (% CPU), Instruments Time Profiler |
| CPU while paused / hidden | ≤ 0.2% average over 60 s (effectively idle) | Activity Monitor; Instruments |
| Idle wakeups while paused / hidden | ≤ 1 per second | Activity Monitor "Idle Wake Ups"; `top -stats pid,cpu,idlew` |
| Energy Impact while walking | "Low" category; average ≤ 2.0 | Activity Monitor Energy tab |
| Frame pacing while walking | ≥ 99% of frames within 20 ms at 60 Hz; no visible stutter | Instruments (Animation Hitches / Core Animation FPS), `os_signpost` per tick |
| Simulation step cost | ≤ 0.3 ms per frame (p95) | `os_signpost` intervals |
| Resident memory | ≤ 100 MB (process footprint) | Activity Monitor "Memory", Instruments Allocations/VM Tracker |
| Frame image memory | ≤ 10 MB for the MVP cat | Debug counter in `FrameImageStore` |
| Launch to first rendered frame | ≤ 1.0 s warm, ≤ 2.0 s cold | `os_signpost` from `main` to first `didRender`; stopwatch for cold |
| Quit | ≤ 0.5 s, no hang | Manual |
| 8 h soak | No crash, memory growth < 10 MB | Overnight run + Instruments Leaks at start/end |

Post-MVP budgets: window tracking enabled and idle adds ≤ 1% CPU; each additional pet adds ≤ 1.5% CPU.

## Strategies

| Strategy | Detail |
|---|---|
| Stop, don't throttle | Paused, hidden, suspended (sleep, lock, display sleep, occlusion) → display link `isPaused = true`, frame driver stopped, no timers |
| Adaptive render rate | `CADisplayLink.preferredFrameRateRange`: 60 while moving; 30 for idle/sitting; down to the animation FPS (e.g. 12) while sleeping; never above 60 by default (ProMotion opt-in later) |
| No per-frame allocations | Snapshots reuse buffers; no string formatting in the hot path; logging in the loop only at `.debug` and behind signposts |
| Event-driven environment | Notifications instead of polling; the only per-frame sampling is `NSEvent.mouseLocation` (cheap) |
| Frame image budget | Downsample at load to target pixel size; preload before first display; one cache |
| Small overlay surface | Only screens that host pets get an overlay (MVP: one); empty overlays are ordered out |
| Hit testing | 1-bit masks at ¼ resolution; bounding-box rejection first |
| Leaks / retain cycles | `[weak self]` in long-lived closures; observers removed in `stop()`; Instruments Leaks in DoD of M6 and M14 |

## Measurement protocol

1. Release build, launched outside Xcode (Xcode's debugger inflates CPU).
2. Machine and macOS version recorded; Low Power Mode off; external displays noted.
3. Let the app settle 30 s after launch; measure 60 s per scenario: walking, paused, hidden,
   display asleep → wake.
4. Record results in the milestone's PR description and in the table below. Regressions over 20%
   versus the previous entry block the milestone unless explained.

## Measurements

| Date | Build | Machine / macOS | Walking CPU | Paused CPU | Memory | Launch | Notes |
|---|---|---|---|---|---|---|---|
| 2026-10-16 | PoC (SpriteKit, 300 pt band, 288 px) — rejected | Apple silicon, built-in 1470×956 @2x / macOS 27.0.1 | 5.7% walking ❌ (1.8% in place) | 0.0% | 106–115 MB ❌ | not measured | Details in [proof-of-concept.md](../planning/proof-of-concept.md#e7-measurements-2026-10-16) |
| 2026-10-16 | PoC (Core Animation, 288 px) — adopted ([ADR-0015](../decisions/0015-core-animation-renderer.md)) | same | 1.0% walking 40 pt/s ✅ (0.5% in place) | 0.0% | 19 MB ✅ | not measured | WindowServer delta similar to SpriteKit (~+1–1.5 points, coarse) |
| 2026-10-17 | M6 Release (`feature/nifty-wozniak-cd5c91`, uncommitted), walking on the Dock top | Apple silicon, built-in 1470×956 @2x / macOS 27.0.1 | 2.06% avg, 3.33% max over 69 min ✅ | 0.00% paused, 0 idle wakeups/60 s; 0.00% locked, ~0% full-screen Space ✅ | 21.8 MB footprint at launch, 23.7 MB after 2 h ✅ | 0.49 s warm (`open` → first frame) ✅ | CPU from cumulative process CPU time per 15 s (`ps`); `top`'s own continuous sampling adds wakeups and CPU, so it was not used for the idle numbers. Leaks: none in PetScape (416 objects in Apple's AppIntents XPC, unchanged over 2 h). Energy Impact and frame pacing not measured. **Regression vs the PoC entry (1.0% → 2.06%, > 20%)**: the PoC spike moved a sprite only; the app adds the fixed-step simulation, the per-frame cursor sample and mask hit test (pass-through) and runs a Release build of the full pipeline (M5 Debug measured ~2.5%). Still within the 5% target — needs the owner's acceptance per the rule above |
