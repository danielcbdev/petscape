# Performance

PetScape may run all day, so energy is a product requirement (NFR-01, NFR-02).
**All numbers below are targets to validate by measurement, not guarantees.** They are first
calibrated by PoC E7 and revised with evidence.

## Owner acceptance update (2026-10-18)

The owner reported all remaining M7/M8 tests complete and explicitly requested milestone closure.
M7/M8 are **Done by owner acceptance**; the evidence and “not measured” statements below are
retained as historical measurement limits, not outstanding milestone approval requests.
No new numeric energy/wakeup/frame-pacing result, soak duration or leak-growth record accompanied
that report. In particular, paused CPU variability remains unexplained; acceptance is not a new
measurement proving the ≤0.2% target. See the [owner closeout](../planning/m7-m8-technical-review.md#owner-m7m8-closeout-2026-10-18).
No performance target is weakened. M9 was subsequently reauthorized and closed by owner acceptance with its unverified native performance/playtest checks recorded in the M9 closeout; no release was authorized.

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

## M13 tracking measurements

**Not measured for M13.** The M12 short samples in
[window-tracking.md](../architecture/window-tracking.md#m12-spike-findings-2026-10-22) ran with an
active pet and did not isolate tracking cost; they cannot satisfy T13.6. A valid comparison still
needs the same Release build, machine and OS with opt-in/trust already granted: 30 s warmup, then at
least three 60 s CPU windows for tracking enabled with the simulation idle and three with the cat
moving, plus matched tracking-disabled controls. Record Activity Monitor `% CPU` or process CPU-time
deltas, sample cadence, window count only, OS/hardware, state and preference state. Do not capture
titles or frame histories. No result is claimed here because enabling the setting or checking native
window behavior is owner-state dependent.

Exploratory observation (2026-10-23): on macOS 27.0.1 (build 26A434), Mac16,12 (10 logical CPUs),
the Debug app was launched with the already-persisted window-interaction preference enabled; no pet
was active. Over one 60 s process CPU-time window, PetScape advanced from 4.32 s to 6.22 s CPU time,
or 3.17% of one core. This does not isolate tracking from Debug/runtime idle work, lacks a matched
disabled control, and is not a T13.6 result or budget claim. The persisted preference was not changed.

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


## M7/M8 engineering measurements (2026-10-18)

Working tree over `develop` / `2f7f33f`, optimized Swift 6 Release outside Xcode; Apple M4
(Mac16,12), macOS 27.0.1, built-in 1470×956 @2x, bottom Dock with 64 pt reservation. One
current walk-only cat, 288 px decode / 96 pt display; **2,654,208 decoded bytes** unchanged.
No V4 memory/appearance claim. UserDefaults command-line overrides selected paused/hidden modes
without changing persisted preferences. Each CPU window used 30 s warmup + 60 s cumulative
process CPU-time delta (`ps`); RSS is not process footprint. Log inspection of the retained
walking window showed no full-screen suspension. No UI test or leak/footprint inspection ran
inside the retained clean measurement windows.

| Scenario | CPU (% of one core, 60 s average) | Evidence limits |
|---|---|---|
| Walking requested, bottom Dock | 0.83% | Single short window; frame pacing/energy not measured. Historical M6 2.06% was a 69-minute sample, so no equivalent-baseline improvement claim. |
| Paused | 0.63%; repeat 0.08% | First clean window exceeds 0.2% target; repeat passes. Variability unresolved, acceptance pending. Initial 0.38% excluded because footprint/leaks tooling inspected the process during that window. |
| Hidden | 0.00% | Clean repeat also 0.00%; idle wakeup counter not measured. |

Initial walking 0.75% was excluded because OS logs showed a full-screen suspension during its
measurement window. It must not be counted as moving performance. One separate paused-process
inspection measured **21.2 MB physical footprint**, peak 29.8 MB. `leaks` reported **417 objects /
20,016 bytes**, with three roots in Apple's `com.apple.linkd.autoShortcut` / AppIntents XPC
connections. This is a single snapshot; it does not establish zero app leaks or stable growth.
Retain the report alongside the historical M6 finding; a two-hour real-time leak delta is pending.

A separate five-second paused sample captured no PetRuntime/PhysicsStepper/frame-driver callback
stack; almost all samples waited in macOS event loops. A subsequent uninstrumented 60.02 s window
advanced cumulative CPU from 0.37 to 0.42 s (0.08%). This supports a quiescent simulation but does
not explain or erase the earlier 0.63% process measurement. No unrelated optimization was inferred
from a mostly-blocked stack. A separate Release build of an archived, unchanged HEAD `2f7f33f` was then launched with the
same paused arguments and 30 s warmup + 60.02 s sample. It stayed at 0.18 s cumulative CPU
(**0.00%** delta). The unexplained transient is therefore retained as an open measurement issue;
this control alone does not establish its cause or accept a regression.

### Optimized deterministic stress harness

A temporary executable compiled the actual Core sources with `swiftc -O -swift-version 6
-warnings-as-errors`. Seed 78, same screen geometry/current manifest, reusable events/snapshot,
432,000 steps at explicit 1/60 s, periodic Dock add/remove and explicit vertical jump requests
at three simulated-second intervals. Wall timing used `DispatchTime`; no sleeps or new runtime
scheduler. Body finiteness/host bounds were checked each step.

| Result | Measured |
|---|---|
| Duration | 2 **simulated** hours, 0.355 s wall time |
| Accepted launches / contacts / recoveries | 2,384 / 2,385 / 0 |
| Core step + snapshot p95 / maximum | 0.000459 / 0.075709 ms |
| Jump request p95 / maximum | 0.041084 / 0.880166 ms |

These microbenchmarks exclude AppKit, rendering, hit testing and display callbacks. Request
revalidation happens at launch; its cost is included in the sampled world step. Neither this
accelerated run nor package tests constitute a two-hour app soak. At the first engineering checkpoint, Release repeated-jump total CPU and real Idle CPU were
not measured; the V4 continuation below supplies separate runtime-harness measurements. Idle
wakeups, physical-state frame pacing/signposts, Energy Impact, full leak-growth and the manual
platform/visual matrix remain **not verified**. The overall AC-M7-15 / AC-M8-18 gates
remain open despite low measured Core costs and successful build/test gates.

## V4 revision 1 measurements (2026-10-18)

Same Apple M4 / macOS 27.0.1 / built-in 1470×956 @2x / bottom Dock. New pack: six clips,
32 unique runtime images, **10,616,832 decoded bytes (10.125 MiB)**, within the approved
16 MiB M8 V4 budget. The unchanged walk subset remains 2,654,208 bytes (≤3 MiB). All image
preloading occurs before display; the five original generated sheets are not decoded.

An optimized temporary executable linked the actual PetRuntime/Platform/Rendering/Core modules,
used real AppKit overlays/display callbacks/hit masks, actual V4 CharacterLoader and in-memory
preferences. It excludes the SwiftUI menu shell. Explicit jump requests every 2.5 wall seconds
are a development harness command source, not a new production scheduler. Each scenario used
30 s warmup + 60 s cumulative process CPU delta. A five-second snapshot monitor confirmed
`running` throughout (no full-screen suspension), walking position changes and live Idle frames.
Footprint inspection happened **after** each CPU window; RSS was not used as physical memory.

| Release Runtime harness | CPU average (% of one core) | Physical footprint after window | Observed demand |
|---|---|---|---|
| Walking | 1.28% | 25 MB | 60 fps, walk frames and position advancing |
| Animated Idle | 0.63% | 25 MB | 30 fps, idle frames advancing at fixed position |
| Repeated vertical jumps + walking return | 1.23% | 30 MB | 60 fps; 35/35 explicit requests accepted across the entire warmup/run |

These short harness samples are not equivalent to the earlier full-app walk-only 0.83% window
or historical 69-minute M6 2.06% sample. No improvement/regression attribution follows from that
comparison. Animated Idle is active presentation, not paused/held Idle; the earlier unexplained
paused-process variability remains open. Frame pacing, wakeups, Energy Impact, cold/warm launch,
complete same-baseline comparison, two-hour real-time app soak and leak-growth delta remain
unmeasured for V4. No screenshot/typing/click-through or artistic acceptance follows from CPU
and image-byte results. AC-M7-15 / AC-M8-18 remain open.

### Full app with V4

The production Release executable (SwiftUI menu + actual bundled pack) was launched separately
with command-line paused/hidden overrides set false, without changing saved preferences. After
30 s warmup, the 60.03 s CPU window measured **1.80%**, with **32 MB physical footprint** measured
afterward (RSS 92.4 MiB is a different metric). Logs confirm 6 clips / 10,616,832 decoded bytes,
spawn on the bottom Dock, `paused=false hidden=false`, and no full-screen/suspension event.
This is within the movement/footprint limits, but higher than the earlier 0.83% walk-only window;
a resource-only paired control follows to assess that difference. Broader acceptance remains open.

A subsequent resource-only control used a temporary copy of the **same Release executable**
(binary SHA-256 identical), replacing only its copied cat resource folder with the HEAD `2f7f33f`
walk-only manifest/original walk files. Project assets and saved preferences were untouched.
Control then V4 repeat each received 30 s warmup + 60 s CPU delta; inspection followed the window.
Logs confirm one clip / 2,654,208 decoded bytes for the control, six / 10,616,832 for V4,
bottom-Dock spawn, no pause/hide and no suspension/full-screen event.

| Same-binary full-app walk comparison | CPU | Physical footprint |
|---|---|---|
| Walk-only resource control | 1.80% | 23 MB |
| V4 repeat | 1.85% | 33 MB |

The observed CPU delta is approximately **2.8% relative**, below the 20% review threshold for
this resource comparison. The earlier 0.83% result is not reproduced by the current walk-only
control, so this experiment does not attribute the cross-session difference to V4. It does not
establish its cause, eliminate longer-term variability or accept the earlier paused-energy issue.
The 9–10 MB footprint increase accompanies 24 extra decoded images (+7,962,624 decoded bytes),
within the explicitly approved V4 budget and unchanged 100 MB process limit. These are short
samples, not a two-hour soak, leak-growth test or complete performance acceptance.

## M9 real-time integration soak (2026-10-18)

A temporary Release-linked Runtime/Core/Platform/Rendering harness ran with seed 42 for 7,206.27
active wall seconds and 7,201.82 simulated seconds. It used an injected offscreen screen and a
real-time test frame driver to keep overlays out of the visible desktop while exercising actual
Runtime stepping, snapshots, frame demand and loaded cat frames. Across 1,435 samples it made 689
activity decisions, reached every activity and the rest/expression/airborne phases, and produced no
non-finite position, velocity or energy. Requested frame demands included 4 Hz for 1,199 s, 30 Hz
for 2,385 s and 60 Hz for 3,456 s. Process CPU time was 93.03 s (~1.29% over the run); RSS ranged
from 27.6 to 47.0 MiB and ended at 28.3 MiB.

This harness did not use the SwiftUI menu shell, physical display link or visible screen; it does
not establish visual quality, native callback cadence or the installed app's resource profile.
The ordinary native app was correctly suspended by the full-screen-space detector in this session.
A single restricted `leaks` snapshot reported 417 allocations / 20,016 bytes, with visible roots
appearing in Apple `LNDaemonApplicationInterface` / AppIntents XPC connection cycles. macOS allowed
only a partial read-only report, and there was no ending snapshot; leak growth and PetScape-owned roots
are therefore not established. No native UI/login-item result is claimed. See the [M9 execution record](../planning/m9-implementation.md#execution-record-2026-10-18).

## M10 measurement plan and limited result

The [M10 plan](../planning/m10-implementation.md#acceptance-risk-and-regression-matrix) defines paired
baseline/new Release scenarios: idle, walking, pet sleep, press, held/drag, paused, hidden and
suspended; 30 s warmup +≥60 s windows ×3. Keep OS/hardware/Dock/prefs/art constant and measure
WindowServer/GPU cost of the bounded input-panel candidate, input latency, event volume,
steady allocations, token/window leak growth and ≥2 h installed-app footprint delta.
Existing absolute limits remain; proposed pack budget≤16 MiB at reference 2× and event→visible
drag p95≤33.4 ms/max≤50 ms. >20% paired regressions need explanation/owner acceptance.
Planning-time baseline build/tests did not establish runtime input latency, cadence, focus or resource
success. A later limited same-Mac Release sample recorded only app CPU and resident memory for three
60 s windows per build; its results and strict limitations are in the [M10 implementation
record](../planning/m10-implementation.md#limited-release-cpurss-comparison--2026-10-18). It does
not close the broader performance or native gates.
