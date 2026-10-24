# Testing Strategy

## Owner M7/M8 acceptance update (2026-10-18)

The owner reports all remaining M7/M8 tests complete and explicitly requests closure; both
milestones are **Done by owner acceptance**. The records below distinguish prior automated
runs, agent observations and owner reports. Earlier “pending” entries are historical evidence
limits superseded for milestone approval by the [owner closeout](../planning/m7-m8-technical-review.md#owner-m7m8-closeout-2026-10-18).
No individual click-point count, hardware detail, numeric reading or two-hour duration is invented.
M2/M3/M5/M6 are also Done by explicit owner acceptance after the owner reported everything
working. Missing logs/hardware measurements remain evidence limits. M9 was subsequently explicitly
reauthorized and closed by owner acceptance; current results and accepted evidence limits are recorded in its [implementation plan](../planning/m9-implementation.md).

The final closeout rerun passed 361 package tests and strict lint. The UI runner failed before the
test body with “Timed out while enabling automation mode”; the original UI test is unchanged.
The earlier complete UI pass is retained separately, alongside owner test confirmation. No new
macOS permission was requested and no test was weakened to close the milestone.

Principle: test **behavior that can break**, with deterministic inputs. No tests written only for
coverage numbers; no deleting or weakening tests to get a green build.

## Layers

| Layer | Framework | Where | What | Runs |
|---|---|---|---|---|
| Unit | Swift Testing | `PetScapeCoreTests` (bulk), other package test targets for pure helpers | Geometry/conversions, manifest decoding/validation, animation timing, state machines, physics, Dock estimation, surface map, behavior scoring, run-state logic, pass-through state machine | `make test-core` (seconds) |
| Integration | Swift Testing | `PetScapeRenderingTests`, `PetScapeRuntimeTests`, `PetScapePlatformTests` | Image decoding with fixture PNGs, frame image store + hit masks, `PetLayer` configuration from snapshots without a window, character loader end-to-end with a fixture pack, preferences store with an isolated `UserDefaults(suiteName:)`, runtime with fake frame driver/screens | `make test` |
| UI | XCTest (XCUITest) | `PetScapeUITests` | Launch, menu items and state labels, Settings (M9) | `make test` |
| Performance | XCTest `measure` + signposts | Runtime tests / manual | Simulation step cost, decode time | on demand / M14 |
| Manual | Checklist | PR description | Overlay, click-through, Dock alignment, Spaces, multi-display, sleep/wake | per milestone |

## Determinism

- Time: tests drive `world.step(dt:)` explicitly or use `ManualClock`; never `Date()`/`sleep`.
- Randomness: `RandomSource` injected; tests use `SeededRandomSource(seed:)` or a scripted source.
- Environment: screens, Dock estimates and surfaces are values constructed in tests.
- Platform: protocol fakes (`FakeScreenProvider`, `FakeFrameDriver`, `FakeHitTester`,
  `InMemoryPreferencesStore`).

## What to test per area

| Area | Key tests |
|---|---|
| Coordinates | list in [coordinate-system.md](../specifications/coordinate-system.md#unit-tests-t31) |
| Manifest | one fixture per validation code; the real cat pack validates; unknown fields tolerated |
| Animation | parameterized frame counts (8/12/16/24/32) × stepping (60/120 Hz) × modes; per-frame durations; multi-frame steps emit ordered events; pause = no advance; `next` chaining; fallbacks |
| State machines | every transition row; priority thresholds; stuck detection; recovery |
| Physics | walking speed and edge events; landing without tunneling (property test); moving/removed surfaces; jump solver accuracy; determinism with seed |
| Surfaces / Dock | estimator table; re-projection; diffs |
| Behavior | seeded scenarios (tired → sleep, startled → wake, no 3× repetition) |
| Run state | all combinations user intent × system state; accumulator reset on resume |
| Pass-through | enter/leave/drag sequences; drag keeps interactivity until mouse-up |
| Preferences | defaults, persistence, version migration, restore defaults |

Fixtures: under each test target's `Fixtures/` folder (JSON manifests, tiny PNGs generated for the
purpose — never modified copies of original art beyond what the test needs).

## UI tests

`PetScapeLaunchTests` (T2.7) launches the app, waits for `app.statusItems.firstMatch`, checks that no
window is open, opens the menu, clicks "Quit PetScape" and expects the process to end. **Historical (2026-10-16):** early runs stopped before the test body with "Timed out while
enabling automation mode". The owner session on 2026-10-18 passed the UI launch/menu Quit test in Automation Mode (recorded
below). The M9 Settings UI test also passed on 2026-10-18 after fixing duplicate Settings menu-item
selection and querying native Toggle controls as switches. It changes autonomy and scale, restores
defaults, verifies login is off through the fake service, closes Settings and quits. This does not
exercise real OS login registration or native sleep frame cadence. Keep Automation Mode setup outside
the app; see [setup.md](setup.md#ui-tests-and-automation-mode).

## Manual test matrix (MVP)

Record environment (see [proof-of-concept.md](../planning/proof-of-concept.md#environment-to-record-for-every-result)) and pass/fail per row in the PR.

| # | Scenario | Expected |
|---|---|---|
| 1 | Dock bottom, default size | Cat on shelf (±3 pt after offset) |
| 2 | Dock small / large, magnification on | Same offset; walking unaffected |
| 3 | Dock autohide on | Cat on screen bottom; Dock reveal works normally |
| 4 | Dock left / right | Cat on screen bottom |
| 5 | Resize/move Dock while running | Cat re-settles within 1 s |
| 6 | Different scaling (More Space / Larger Text) | Correct size and placement |
| 7 | Retina + external non-Retina display; disconnect while running | Cat stays on Dock screen; no crash |
| 8 | Secondary display left/above (negative coordinates), Dock on secondary | Correct placement |
| 9 | Switch Spaces, Mission Control, App Exposé | Overlay stable; not listed as a window |
| 10 | Stage Manager on | Click-through intact |
| 11 | Fullscreen app | Cat not visible over it |
| 12 | Sleep/wake, lock/unlock, display sleep, fast user switching | No rendering while away; resumes without jumping |
| 13 | Click-through matrix (AC-14) | All events reach targets |
| 14 | Click cat; type in frontmost app | Focus unchanged (AC-21) |
| 15 | Missing/corrupt manifest (dev build) | Status message + placeholder; no crash |
| 16 | No permissions requested | Privacy panes have no PetScape entry |
| 17 | Quit from menu | Exits cleanly |

M6 run (2026-10-17, with owner follow-up on 2026-10-18, recorded in the [M6 block of milestones.md](../planning/milestones.md#m6--dock-integration--mvp-hardening)):
row 15 passed (logs: error + placeholder, no crash; owner later confirmed the menu status line); row 16 passed
(no PetScape entry in checked Privacy & Security panes); owner also confirmed Dock side fallback, auto-hide,
resize/move, full-screen and Space return, lock/unlock, display and system sleep/wake, user switching, Dock
click-through, typing focus, VoiceOver, light/dark wallpaper transparency, foot motion, anchor and clean Quit.
Rows 1, 3–5 are covered by estimator/provider/world tests and launch logs. Resolution-change log evidence and
external-display checks remain unavailable; the full AC-14 click-through matrix is still pending. The M2 UI launch
test passed in Automation Mode on 2026-10-18 (`make test`; 174 package tests plus 1 UI test).

Post-MVP milestones extend this matrix (drag, climbing, windows, multi-display).

### M13 native window matrix

| Scenario | Expected |
|---|---|
| Enable Interact with windows and autonomy; place a visible window above the Dock; wait through several activity choices | Cat occasionally jumps to a visible side below the top, climbs up, walks on the top, then jumps back to Dock |
| Open several eligible windows and observe repeated excursions | Destination varies across windows; covered or unreachable sides are skipped |
| Cover, move, minimize or close the selected window during the excursion | Cat detaches or falls safely; no window is moved or activated |
| Disable Interact with windows or autonomy during a Dock approach | No new climb starts; existing physical motion resolves safely |

Automated deterministic tests do not replace these native visual checks.

## M13 window interaction coverage

Deterministic package tests cover visible-segment construction and occlusion identities, logical-width
placement, window spawn and support loss, parameter re-projection during move/resize, teleport
classification, a single occlusion detach, swept landing and the existing discrete jump path to a
window. T13.7 tests cover window-side jump solving, climbing from the side to the top, timed walking,
Dock return and seeded selection across multiple windows. Tracker permission tests continue to assert
that disabled opt-in makes no trust/prompt call.
These tests do not establish native AX delivery cadence, frame lag, app hide/minimize behavior,
revocation, visible-side accuracy, the rendered climb, or CPU overhead; those require the manual M13
matrix and Release measurements below.


## M7/M8 regression matrix

Status: **Planned, not executed by this documentation change.** P/I = probability/impact (L/M/H).
Each row identifies cause, prevention, tests/evidence and recovery. Use existing test targets;
new test files are explicitly proposed in [task-breakdown.md](../planning/task-breakdown.md).
Manual procedures extend the MVP matrix; do not replace its historical results.

| Risk | Cause / impact | P/I | Prevention | Test / evidence / task | Recovery |
|---|---|---|---|---|---|
| RG-01 Double movement | Old walk plus new integrator both write position; speed doubles | M/H | PetWorld sole commit, policy emits intent | AC-M7-04/05, speed/rate and assignment audit; T7.4/5 | Reject invalid intent, normal world recovery |
| RG-02 Tunneling / wrong platform | Endpoint-only x or coarse overlap misses crossing | M/H | Swept x-at-hit, first lambda, stable ties | 10k terminal drops, diagonal/narrow/tie tests; T7.2 | Safe floor or bounded invalid-state recovery |
| RG-03 Invisible airborne | attachment nil interpreted as unplaced | H/H | State-based visibility, same snapshot for masks | World/render snapshot flight tests; T7.4; manual Dock hide | Continue physical frames, render valid airborne state |
| RG-04 Dock-side freeze (2f7f33f) | Still/hidden snapshot stops frames before placement/fall | H/H | Explicit physics/pending work demand | Both left/right parameterized runtime tests, assert driver through 60 steps; T7.6 | Finish fall/placement; wait for environment only without usable surfaces |
| RG-05 Auto-hide / raised Dock | Floor omitted or newly added Dock becomes forced spawn | M/H | Floor coexists; existing contact wins; no underside capture | Hide/show/reveal, same-ID resize/offset, floor retention tests; T7.3/7; manual rows 1–5 | Fall to floor, safe explicit jump later |
| RG-06 Catch-up after suspension | Timestamp backlog or new host driver shares old clock | M/H | Existing reset plus demand/host reset | Pause midair, lock/sleep/display/session/full-screen, new driver and 0/1st callback tests; T7.6/7, T8.2 | Freeze, refresh environment, restart timestamp |
| RG-07 Surface removed / resized / resolution | Stale attachment/JumpPlan points at old geometry | M/H | Between-step environment commit, launch revalidation, host floor | Synthetic negative/mixed-scale/removal tests; T7.7/T8.3; actual resolution logs C-02, external C-03 still missing | Same-ID grounded reprojection; airborne cancel plan/continue fall; host lost→existing exceptional placement |
| RG-08 Nonfinite/stuck body | Invalid input or phase combination, no lower surface | L/H | dt/geometry/body guards, 3 s watchdog, finite phase timers | NaN/Inf/invalid-contact/no-surface tests; T7.1/7, T8.2 | One bounded recovery, zero velocity, wait for notification without retry loop |
| RG-09 Jump duplication / oscillation | Repeated request/marker, callback phase recursion | M/H | Consumed ID, cooldown, one launch, bounded transitions | Duplicate request/marker and same-step surface loss/apex/contact; T8.2/4 | Cancel once, restore intent or fall |
| RG-10 Art controls trajectory | Event-driven impulse/finished controls landing | M/H | Simulation timer/velocity/contact authority | 1/8/12/24/32 and missing-event identical-trajectory tests; T8.4 | Hold fallback pose, physical phase continues |
| RG-11 Alignment / foot sliding / tail collisions | Pose-specific anchor/margin changes or changed nominalSpeed | M/M | Fixed logical dimensions and stable visual guard, walk unchanged | Scale/facing/anchor tests, owner ±3 pt Dock and no-slip review; T7.5/8, T8.5 | Reject art delivery; retain current pack/fallback |
| RG-12 Click-through / focus / typing | New poses/mirroring masks differ from drawn state or stopped sim loses cursor monitor | M/H | Snapshot then mask then cursor; effective driver/idle monitor policy, no window changes | Actual ≥20-point event/target matrix C-01 repeated on fall/landing; real-mask/mirror/scale tests; T7.6/T8.6. AC-21 typing, no key/main | Reset pass-through to transparent; fix mask/scheduling through existing controller |
| RG-13 Transparency / VoiceOver | Art alpha fringe or unrelated overlay/menu regression | L/M | Existing overlay levels/decorative AX exclusion, opaque V4 bodies | Light/dark/checkerboard, keyboard/VoiceOver menu, AC-03/02; T8.5/6 | Fall back to approved pack; preserve overlay/menu contracts |
| RG-14 Missing/invalid assets | Wrong regex, missing image, broken fallback or pack | M/M | Existing decode/validation/resolution and placeholder | Missing/malformed manifest, absent frame/clip, unsupported version, aliases; T7.8/T8.4/5 | Existing error UX + safe default pose; no physics dependency |
| RG-15 Energy / CPU / memory | Frame demand spins forever, per-step allocation, V4 preload growth | M/H | Demand stops on no work/system gate; linear scans/buffers/downsample | Release 60 s scenarios, p95 signposts/allocations/frame pacing, 2 h soak/leaks, V4 decoded bytes; T7.8/T8.6 | Bound recovery, stop when unavailable; profile and retune only with measured evidence |
| RG-16 Privacy / permissions | New window queries/capture/input monitoring introduced for physics | L/H | Existing value geometry, no new adapters needing permissions | Import/API/dependency review; fresh-install AC-16, no network/title/content reads; T7.8/T8.6 | Disable offending new feature; existing local fallback |
| RG-17 Full-screen exposure | Existing two-read delay shows pet briefly on launch/transition | M/M | Preserve detector; named owner release decision C-04 | Repeated owner launch/transition observation + logs; not solved by M7 | Existing suspend/hide once confirmed; separate hardening if deviation rejected |

### Deterministic test execution

For new runtime geometry tests, inject a screen reader through existing ScreenProvider with a
production default using NSScreen; do not call tests fully deterministic while their geometry is
read from the actual desktop. Keep the fake FrameDriver and in-memory preferences. Drive event
sequences and dt explicitly; seed 10k drop cases and log the seed on failure. Replay same inputs
with different clip counts. No real-time sleep for phase tests, no screen/click capture by the app.

Every transition row in Jump System gets a positive and rejected-precondition test; include exact
preparation/landing boundary, duplicate events, support lost at launch, target removed mid-flight,
no-screen wait, changed environment while paused and first frame after resume. Keep previous
walking/turn/offset/pass-through/store/loader assertions. When changed behavior makes an old respawn
assertion obsolete, replace it with stronger falling/contact and no-teleport checks, documenting why.

### Measurement and manual evidence

Use performance.md protocol, Release outside Xcode, hardware/OS/HEAD/Dock/settings recorded.
Measure baseline HEAD then M7 then M8/V4 on the same machine; existing 2.06% is historical, not a
substitute for new measurements. Collect simulationStep p95, total frame pacing, request-time jump
planning cost, CPU, wakeups, decoded frames/process footprint, 2 h soak and leak deltas. V4 budget
≤16 MiB is approved; total footprint≤100 MB stays required. Record cold/warm launch and
VoiceOver/menu/Quit where affected. External hardware and resolution-log gaps remain named until
actual evidence or explicit exception; synthetic tests complement, never replace platform evidence.

## M7/M8 execution record (2026-10-18)

`make test` passed 358 package tests (240 Core, 49 Runtime, 44 Rendering, 25 Platform) and the
app/UI launch/status-item/Quit test. Lint and Debug/Release builds passed. The intermediate
InstantView activation failure was retried successfully with the original UI test unchanged.
New physics tests use explicit dt/seeded randomness; runtime geometry uses synthetic descriptors
and fake frame callbacks. Existing platform/art/pass-through/manifest suites remain in place.

Review regressions now covered: held Idle after Dock loss/invalid body; new intervening support or
lowered visible-frame ceiling during preparation; all six permutations of epsilon-height chains;
unrelated surface changes preserving exact launch coordinates; nonzero walk frame through Turning;
normal animation priority after landing. 1/8/12/24/32-frame clips produce identical trajectories;
synthetic v1 loader phase packs render every phase, while invalid optional/default images retain
fallback/placeholder behavior. Real Idle loops at 15/30 Hz preserve simulation time.

| Manual/measurement gate | Evidence / remaining work |
|---|---|
| Native launch/status item/clean Quit | Automated UI test passed. Native Computer Use inspection timed out; no visual sign-off inferred. |
| Physical fall/jump visual quality and paw alignment | V4 real phases are integrated; actual PetWorld preview generated. Owner approved the delivered V4 visual result on 2026-10-18; native scale/Dock calibration remains pending. |
| ≥20 transparent flight/landing points, all event kinds, desktop targets; typing/VoiceOver | Not verified. Existing mask tests are retained; synthetic images are not V4 silhouettes. |
| Dock auto-hide/both sides/resizing, displays/Spaces/full-screen/sleep/lock | Synthetic interruption/demand tests pass. Full manual matrix and external-display/resolution evidence remain pending. |
| V4 identity/alpha/bbox/anchor/masks/byte budget | V4 revision 1 actual PNG containment, alpha, baseline/paw registration and 10.125 MiB decoded budget tests pass. Owner approved delivered identity/style on 2026-10-18; original walk unchanged. |
| M11 screen-edge climbing | Automated wall geometry, two-side transitions, 120 pt/s fixed-step travel, mirrored edge anchor and loss-of-wall fall are covered. Native left/right paw alignment (±3 pt), top exit and continuous return to Dock await the M11 playtest record. |
| Release CPU/memory, pacing, energy, idle wakeups, leaks/2 h app soak | Walking 0.83%, hidden 0.00%, paused 0.08–0.63% (one window above target), M6 paused control 0.00%; acceptance pending. Footprint 21.2 MB. Accelerated stress is not real-time soak/leak-growth evidence; details in performance.md. |

At that historical checkpoint, continuous engineering authorization had not accepted those
gates, and M7/M8 plus M5/M6 stayed In review. The owner later closed M7/M8 after confirming
all remaining tests. The owner subsequently closed M2/M3/M5/M6
and explicitly reauthorized M9. No release/tag is authorized.

## V4 production validation (2026-10-18)

The owner separately authorized production/integration. Revision 1 adds five clips / 24 frames.
`make test` passed **361 package tests** (240 Core, 52 Runtime, 44 Rendering, 25 Platform) and
the unchanged UI launch/status-item/Quit test. `make lint`, exporter strict-format lint, Debug
and Release builds passed with compiler warnings treated as errors. An earlier attempt timed
out while XCTest enabled Automation Mode; the complete retry passed without changing tests.

V4CharacterPackTests validate actual production-pack data: all five phases load without fallback,
shared 96 pt display/anchor, ≤16 MiB total, every PNG's 512 px dimensions, opaque body, all-alpha
8 px border, baseline and individual planted-paw drift ≤1 px. The original walk-only ≤3 MiB
assertion is retained separately. Actual production and walk-only definitions produce identical
state/position/velocity over 150 fixed steps through preparation, rise, fall, landing and Idle.
Independent review caught horizontal paw drift and faint border overflow; both failed new
assertions before correction. Production sources remain intact; export/QA/checksum metadata and
[previews](../../assets/characters/cat/v4/README.md) are retained.

Offline previews show light/dark backgrounds and opposite facings; the jump-cycle GIF renders
actual PetWorld snapshots, not desktop footage. The owner subsequently approved the delivered V4
visual result (“está aprovado”, 2026-10-18). No full ≥20-point flight/landing event/typing matrix
or other new native test evidence accompanied that V4 checkpoint. The owner later closed M7/M8
after confirming the remaining tests; missing native scale/Dock calibration, hardware combinations
and quantitative energy/soak readings remain documented evidence limits, not open milestone
approval requests. See [performance.md](../specifications/performance.md) for the separately measured
V4 runtime scenarios and same-binary full-app resource control.
Release resource hashes also match the workspace manifest and all 32 PNGs. A fresh export
reproduced all 24 V4 PNGs byte-for-byte; the exporter compiled in Swift 6 with warnings as errors.

## M10 planned tests and native gates

No M10 tests implemented or PoC executed by the planning request. The existing suite was rerun:
400 package tests +2 UI tests and lint passed; UI compilation emitted existing actor-isolation
warnings, documented in [baseline evidence](../planning/m10-implementation.md#current-baseline-verification-2026-10-18).

Canonical new test specification and task owners: [M10 tasks](../planning/m10-implementation.md).
Native matrix and zero-swallowed-input go/no-go: [M10.0 PoC](../planning/m10-native-poc.md).
Full acceptance/risk/regression matrix: [M10 verification](../planning/m10-implementation.md#acceptance-risk-and-regression-matrix).
Use explicit dt/seeded randomness, synthetic origins/scales, fake cursor/button/monitor/frame
sources and isolated preferences. Unit hit masks/flags never substitute for underlying-app native
input/focus tests. Include primary-up while secondary remains held, no-frame teardown, final up
before next frame, missing V5 identical physics, v3 migration and live disable/resize.
Installed ≥2 h interaction soak and paired CPU/WindowServer/allocations/leak measurement are future
M10 validation, not evidence supplied by baseline tests or M9's offscreen harness.

## M15 animation quality — 2026-10-23

The final package run passed 481 tests (309 Core, 88 Runtime, 50 Rendering, 34 Platform),
including six M15 tests. New checks compare all original key/event entry times and contracts
against an immutable baseline, validate 43 distinct alpha/registration-safe drawings, protect
original hashes, load all 93 references within 32 MiB and compare an actual seeded jump trajectory.
Historical pack-count and memory assertions run unchanged against a temporary baseline fixture.
A test first reproduced the enlarged wall-preview crop; native playback confirmed the fix.
Lint, Debug and Release builds passed. All ten native clips and the slow offline comparison
were inspected; details and owner aesthetic acceptance are in the
[M15 evidence](../planning/m15-implementation.md). The first three XCUITest attempts timed out
enabling macOS Automation Mode before test bodies. The owner-requested fourth run initialized
successfully: both UI tests passed, zero failures, in 17.631 s on 2026-10-23 at 16:33 local time
(`build/m15-ui-owner-retry.log`). Existing test code, entitlements and privacy permissions were
preserved. No UI-run action remains pending.

**V7 visually rejected by the owner (2026-10-23); V8 rework candidate.** The results above are
historical and are not visual acceptance. With V8 `walk`/`curious` integrated, the package run
passed 482 tests (309 Core, 89 Runtime, 50 Rendering, 34 Platform). The V7 key-preserving check now
covers only the clips still on V7. A new test locks every planted V8 paw to `nominalSpeed` per drawing
(seam included) and matches manifest timing to `v8/rig-report.json`. V8 drawings use a stricter
interior-seam opacity check instead of the 95% opaque-share rule (the source key itself is at 93.5%).
The full-pack ceiling is 42 MiB (131 frames), pending an owner budget decision. Details:
[M15 record](../planning/m15-implementation.md#v8-verification-so-far). Lint, Debug and Release
(warnings as errors) builds pass (`build/m15-rework-*.log`); UI tests were not rerun for V8.
