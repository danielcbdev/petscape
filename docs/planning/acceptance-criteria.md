# Acceptance Criteria

Criteria are verifiable statements. **[Auto]** = covered by automated tests; **[Man]** = manual
check recorded in the PR (environment + result); **[Meas]** = measurement per
[performance.md](../specifications/performance.md).

## MVP (v0.1.0) — maps to FR-01…FR-18

| ID | Req | Criterion | Type |
|---|---|---|---|
| AC-01 | FR-01 | Launching the app shows no Dock icon, no window, and a menu bar icon within 1 s. | Man, UI |
| AC-02 | FR-02 | The menu contains Show/Hide Pet, Pause/Resume, Quit PetScape; labels reflect current state; all items reachable by keyboard and VoiceOver. | UI, Man |
| AC-03 | FR-03 | The overlay covers the Dock screen's full frame; no visible background, border or shadow on light and dark wallpapers. | Man |
| AC-04 | FR-04 | Exactly one cat is visible, at the configured display size (default 96 pt canvas), sharp on Retina. | Man |
| AC-05 | FR-05 | Changing the walk clip's `fps` or frame list in `character.json` changes playback after relaunch without code changes. | Man, Auto (loader) |
| AC-06 | FR-06 | At 60 Hz and 120 Hz stepping, an 8-frame 9 fps loop shows frame *n* at `floor(t × 9) mod 8` (±1 step). | Auto |
| AC-07 | FR-07 | The cat moves at `nominalSpeed` ±5% (measured over 10 s); no visible foot sliding (owner review). | Auto, Man |
| AC-08 | FR-08 | The cat's sprite never extends beyond the walkable segment ends (edge margin = half sprite width). | Auto, Man |
| AC-09 | FR-09 | At each end the cat stops ~0.15 s and walks back mirrored; 100 consecutive turns without drift or stuck states. | Auto |
| AC-10 | FR-10 | With the Dock at the bottom (small, default, large size; magnification on/off) the paws are within ±3 pt of the Dock shelf top after offset adjustment; with autohide, Dock left/right, the cat walks on the screen bottom. | Man, Auto (estimator) |
| AC-11 | FR-11 | Pause freezes animation frame and position; Resume continues from the same frame/position with no jump. | Auto, Man |
| AC-12 | FR-12 | Hide removes the cat and the overlay; Show restores it at its previous state. | Man |
| AC-13 | FR-13 | Quit exits within 0.5 s, leaves no process, produces no crash report; observers/monitors removed (verified by logs in DEBUG). | Man |
| AC-14 | FR-14 | Clicks, double-clicks, right-clicks, drags and scrolls outside the cat's opaque pixels reach Finder, desktop icons, the Dock, the menu bar and app windows; tested on ≥ 20 points around the cat (including between legs and under the tail). | Man |
| AC-15 | FR-15 | With the manifest missing, malformed, or a frame missing, the app does not crash, shows a menu status message, renders a placeholder or the fallback clip, and logs the error. | Auto, Man |
| AC-16 | FR-16 | A fresh install triggers no permission prompt; System Settings › Privacy shows no PetScape entries. | Man |
| AC-17 | FR-17 | Changing resolution/scaling, connecting/disconnecting a display, resizing/moving/hiding the Dock: the cat re-settles on the correct surface within 1 s, never off-screen. | Man |
| AC-18 | FR-18 | Pause and hidden states survive relaunch. | Auto (store), Man |
| AC-19 | NFR-01/02 | Walking ≤ 5% CPU; paused/hidden ≤ 0.2% CPU and ≤ 1 idle wakeup/s; memory ≤ 100 MB; launch ≤ 1 s warm. | Meas |
| AC-20 | NFR-02 | During system sleep, screen lock and display sleep, no frames are rendered (signpost log shows none). | Man, Meas |
| AC-21 | NFR-04 | Clicking the cat never activates PetScape or changes the frontmost app; typing continues in the frontmost app. | Man |
| AC-22 | NFR-03 | 2 h run with no crash and memory growth < 5 MB (8 h in M14). | Meas |
| AC-23 | NFR-11 | `make lint` clean; zero compiler warnings; all tests pass. | Auto |

## Per-milestone criteria

### M1 — PoC
- AC-M1-01: Every experiment E1–E8 has a recorded result with environment details.
- AC-M1-02: Each of assumptions A1–A5 is marked confirmed, refuted (with alternative chosen), or partially confirmed (with mitigation).
- AC-M1-03: ADR-0003, ADR-0004 and ADR-0009 are updated to Accepted or superseded.

### M2 — App skeleton
- AC-M2-01: Clean clone → `make build && make test && make lint` succeed on macOS with Xcode 26+.
- AC-M2-02: AC-01, AC-13 pass.
- AC-M2-03: `PetScapeCore` has no import of AppKit/SwiftUI/QuartzCore/SpriteKit (checked by `grep` in CI or review).

### M3 — Overlay
- AC-M3-01: CoordinateConverter tests cover all cases listed in coordinate-system.md.
- AC-M3-02: AC-03, AC-14 (with a debug rectangle as target), AC-16, AC-21 pass.
- AC-M3-03: RunStateController tests cover every combination of user intent × system state.
- AC-M3-04: Pass-through toggles within one frame of the cursor entering/leaving the target (DEBUG log timestamps).

### M4 — Animation system
- AC-M4-01: AC-05, AC-06, AC-15 pass; one test per validation code.
- AC-M4-02: Decoded cat textures ≤ 3 MiB total (288 px target).
- AC-M4-03: DEBUG preview plays `walk` at 9 fps with anchor at the paws (owner visual check).

### M5 — Walking
- AC-M5-01: AC-02, AC-04, AC-07, AC-08, AC-09, AC-11, AC-12, AC-18 pass on the screen-bottom surface.
- AC-M5-02: Clicking on the cat is detected (DEBUG log) and clicking 5 pt outside its silhouette passes through.

### M6 — Dock & MVP
- AC-M6-01: All MVP criteria AC-01…AC-23 pass, or deviations are explicitly accepted by the owner.

### M7 — Physics

All rows are **planned checks, not passing results**. Baseline/new contracts in
[Physics Engine](../architecture/physics-engine.md); task ownership below. Values provisional until
planning approval; formal acceptance requires shared build/lint/test gate and owner evidence review.

| ID | Criterion | Type | Task |
|---|---|---|---|
| AC-M7-01 | 10,000 seeded descending terminal-speed sweeps across zero/1-pt horizontal segments produce first valid contact, never tunnel; x evaluated at crossing, deterministic ties. No contact when ascending/from below/unsupported width. | Auto | T7.2, T7.8 |
| AC-M7-02 | Removing a bottom Dock at the documented 64 pt reservation makes the visible cat fall and land on the host floor within 60 fixed steps, same initial x/facing apart from physical vx; no respawn/random teleport. General fall duration follows height/gravity, not a universal 1 s cap. | Auto, Man | T7.4, T7.7 |
| AC-M7-03 | Identical seed, ordered inputs and fixed steps produce identical position/velocity/contact/state/events; replay is unaffected by surface input ordering when contacts tie. | Auto | T7.2, T7.7 |
| AC-M7-04 | PetWorld is sole stored position writer; walk intent/stepper/renderer do not own competing positions. Snapshot and hit tester equal committed foot position; runtime uses existing driver. Audit assignments and fake-driver test. | Auto, review | T7.4 |
| AC-M7-05 | Existing walking remains nominalSpeed × speedScale × scale ±5% over 10 s in both facings, 0.15 s turns and 100-turn no-drift/bounds checks pass; pose/tail change cannot change physical speed or edge guard. | Auto, Man | T7.4, T7.5 |
| AC-M7-06 | At h=1/60 from y=100 and rest, gravity 2400 gives vy=−40 and y=99⅓ within 1e-6; acceleration and terminal clamp verified. Invalid/nonpositive/>h+1e-9 dt leaves world/time/random/events unchanged; frame stalls execute ≤5 steps with remainder<h, resume first frame does zero steps. | Auto | T7.1, T7.4, T7.7 |
| AC-M7-07 | Swept contact commits exact y, valid SurfaceAttachment/parameter, zero velocity and one landed event; continuous grounded contact emits no repeated landings over 600 steps. | Auto | T7.2, T7.4 |
| AC-M7-08 | Unsupported contact/removal detaches once; narrow/zero-width/nonfinite surfaces do not invent support. Grounded/airborne contradictory attachment states recover; x-at-impact and exact boundary cases covered. | Auto | T7.2, T7.4, T7.5 |
| AC-M7-09 | Runtime world contains host floor plus optional Dock, deduplicated; spawn still prefers Dock, adding Dock never lifts a pet on surviving floor; builder handles negative coordinates, no-screen input and no non-host landing. | Auto | T7.3 |
| AC-M7-10 | Same-ID Dock size/offset reprojects and clamps through world; invalid body, removed host and >3 s airborne use the existing bounded recovery path, one event/incident; no surface means wait for notification without busy retry. | Auto, Man | T7.4, T7.7 |
| AC-M7-11 | With usable surfaces, pending placement/recovery/airborne/timed phases keep driver demand active even with hidden/still snapshots; actual RunStatus pause/hide/suspension stops driver. No demand resets accumulator; restarting/replacing driver has no catch-up. | Auto | T7.6, T7.7 |
| AC-M7-12 | Explicit 2f7f33f regression for BOTH left/right Dock: frames remain active from surface removal through falling/contact; cat reaches floor and walks. Reverse change retains floor attachment; screen boundaries turn, never randomly drop off-screen. | Auto, Man | T7.5, T7.6 |
| AC-M7-13 | Auto-hide setting removal produces fall; hover reveal remains below Dock with no polling. Paused geometry changes reconcile on resume; no fall/catch-up while paused/hidden/locked/sleeping/full-screen. Offset persistence and no-permission behavior retained. | Auto, Man | T7.6, T7.7 |
| AC-M7-14 | Walk-only current pack and placeholder complete fall/landing with bounded settle and no missing-frame crash; fall/landing fallback cannot stop physics frames. Deterministic fixtures use explicit time/seed and injected screens, no sleep or real Dock dependency. | Auto | T7.6–T7.8 |
| AC-M7-15 | Release movement CPU≤5%, paused/hidden≤0.2%, idle wakeups≤1/s, simulation step p95≤0.3 ms, process footprint≤100 MB; ≥60 s/scenario and 2 h soak/no app leaks, frame pacing per performance.md. >20% regression explained and owner accepted. Manual AC-03/10/14/16/21/menu VoiceOver retained, evidence/gaps recorded. | Meas, Man | T7.7, T7.8 |

### M8 — Jumps

Planned, **not verified**. [Jump System](../architecture/jump-system.md) owns tuning, target envelope
and interruption rules; [V4](../specifications/animation-assets-v4.md) owns art QA.
Historical AC-M8-02 required impulse on an art takeoff frame. The same ID is revised under D8 /
accepted ADR-0017: simulation causes motion; visual synchronization remains a manual obligation.

| ID | Criterion | Type | Task |
|---|---|---|---|
| AC-M8-01 | Every accepted vertical/short horizontal/floor↔Dock plan actually lands within 1 pt of target using the M7 stepper/sweep; unreachable/blocked/out-of-host plans rejected without mutation. Candidate replay is bounded (N≤120, ≤120 replay steps each). | Auto, Meas | T8.1, T8.3 |
| AC-M8-02 | Impulse applied once at 0.15 s preparation deadline (±one boundary step), independent of frame counts/markers; landed starts Landing in the same fixed step. Owner reviews takeoff/impact appearance in a recording/preview; no app screen-capture permission. | Auto, Man | T8.2, T8.4, T8.5 |
| AC-M8-03 | Vertical jump has unchanged x absent an environment correction, positive vy after launch, valid contact on return, no through-floor traversal. | Auto | T8.1, T8.2 |
| AC-M8-04 | Both facings perform short horizontal jumps within ≤80 pt displacement and ≤160 pt/s horizontal speed; accepted trajectories stay in host/ceiling bounds with max apex rise≤120 pt. | Auto | T8.1, T8.3 |
| AC-M8-05 | Rising has vy>0; transition at sign crossing to Falling emits exactly one apex event. Low arc apex/contact same-step order is apex then landed, final phase Landing. | Auto | T8.2 |
| AC-M8-06 | Falling uses M7 gravity/contact; Landing holds zero velocity and valid support for 0.10 s then exits, regardless of clip finished/loop/fallback. | Auto | T8.2, T8.4 |
| AC-M8-07 | Walking→PreparingJump→Rising→Falling→Landing→Walking preserves facing/valid support, restores walk rate/speed and edge behavior. | Auto, Man | T8.2, T8.4 |
| AC-M8-08 | Idle→same jump phases→Idle holds zero ground speed after return; cooldown/timers use simulated time. Real idle loop requests 30 fps (15 minimum), held idle stops frames, no lost time from the five-step cap at those rates. | Auto, Man | T8.2 |
| AC-M8-09 | Valid/invalid transition rows, duplicate requests/markers, priorities and timer boundaries tested; no request can recursively launch/reselect or oscillate phases. | Auto | T8.2, T8.4 |
| AC-M8-10 | Requests during Turning/recovery/flight/cooldown/paused/hidden/suspended rejected without position change; source/target change before takeoff cancels once, restores valid grounded intent or M7 fall. | Auto | T8.2, T8.3 |
| AC-M8-11 | Dock moved/hidden/left/right/resized/shown during flight invalidates target but preserves body/velocity; only real descending contact can attach. Host loss uses existing exceptional recovery; no mid-air target teleport or duplicate jump. | Auto, Man | T8.3, T8.6 |
| AC-M8-12 | Pause/hide/full-screen/sleep/lock/session/display sleep freeze body/phase/animation and cooldown; resume applies current geometry before next step and resets accumulator, no catch-up. Ordinary desktop Space preserves state. | Auto, Man | T8.2, T8.6 |
| AC-M8-13 | Preparation and Landing have finite timers, flight plan≤2 s and M7 watchdog≤3 s simulated; removed target/no usable surface does not cause infinite airborne/transition/retry loop. | Auto | T8.1–T8.3 |
| AC-M8-14 | Actual first-hit collision wins over desired target; terminal descent, exact boundary, raised surface, ceiling and narrow support cases never tunnel or snap from underneath. | Auto | T8.1, T8.3 |
| AC-M8-15 | Valid V4 clips preserve 96 pt display size, common anchor, identity, proportions, foot baseline±1 source px and bbox/margin rules in both facings/scales; recommended frame counts may vary. Owner approves appearance; data-only v1 additions. | Auto (data), Man | T8.5 |
| AC-M8-16 | 1/8/12/24/32-frame and missing/invalid clip/frame fixtures produce identical body trajectories/phase timing; current walk-only pack and placeholder remain usable. Legacy jump-air/land supported, no fallback cycles or missing-event deadlock. | Auto | T8.4, T8.5 |
| AC-M8-17 | AC-14 rerun on ≥20 transparent points around flight/landing silhouettes, including leg gaps/under tail; all event kinds/desktop target classes pass. AC-03/16/21, typing and menu VoiceOver retained; mask matches drawn snapshot after each cut. | Auto (masks), Man | T8.5, T8.6 |
| AC-M8-18 | Release walk/repeated jump/idle/paused/hidden tests meet M7 total/step/idle budgets, approved V4 image budget≤16 MiB, footprint≤100 MB, frame pacing protocol and 2 h soak/leaks; >20% changes require explanation/acceptance. Art budget change needs owner approval. | Meas, Man | T8.5, T8.6 |

### M9 — Behaviors & Settings
- AC-M9-01: Seed 42, energy 0.05 and laziness 1 enter sleep within two decisions; explicit wake exits through a ≤0.5 s waking phase. With eligible alternatives, no selected activity repeats more than 3× consecutively; forced safety/critical-energy and single-eligible-action fallback are bounded. Selection is replayable and never polled per frame.
- AC-M9-02: Sleeping renders at ≤ animation fps (measured).
- AC-M9-03: Settings changes apply live and persist; "Restore defaults" resets all known user-value keys,
  preserving schema version and unrelated/future keys.
- AC-M9-04: Launch at login toggles correctly and reflects system state.

Owner closeout (2026-10-18): M9 is **Done by explicit owner acceptance**. Package/UI tests pass; the owner accepts that native sleep cadence (AC-M9-02), real OS login-item registration/approval (AC-M9-04) and the ≥2-hour installed-app playtest (T9.10) remain unverified. This records accepted evidence gaps, not passing measurements.

### M10 — Cursor & drag
- AC-M10-01: Dragging the cat moves it under the cursor with the grab offset preserved; releasing throws it with the release velocity.
- AC-M10-02: AC-14 and AC-21 still pass (no click-through regressions).

### M11 — Climbing
- AC-M11-01: The cat climbs both screen edges with paws aligned to the edge (±3 pt) and transitions back to the floor without teleporting.

### M12 — Window detection
- AC-M12-01: Without the feature enabled, no AX calls are made and no permission is requested.
- AC-M12-02: With permission, window top surfaces match real window frames within 2 pt for ≥ 10 common apps (Finder, Safari, Mail, Xcode, Terminal, Notes, System Settings, Preview, a Catalyst app, an Electron app).
- AC-M12-03: Tracking adds ≤ 1% CPU idle.

### M13 — Window interaction
- AC-M13-01: The cat stays on a window being dragged slowly (≤ 1 frame lag visually) and falls when the window is closed/minimized.

### M14 — Stabilization
- AC-M14-01: 8 h soak: no crash, memory growth < 10 MB.
- AC-M14-02: Manual matrix passes on macOS 14 (VM) and current macOS.
- AC-M14-03: The cat moves between two displays correctly (both arrangements, mixed DPI).

### M15 — Release
- AC-M15-01: DMG from CI passes `spctl --assess --type install` and launches on a clean macOS VM without Gatekeeper warnings.

## M7/M8 evidence status (2026-10-18)

Automated engineering evidence is recorded per task in [task-breakdown.md](task-breakdown.md#execution-evidence-2026-10-18):
361 package tests and the full app/UI launch/status-item/Quit test pass, lint and Debug/Release builds pass.
Physics, contacts, ownership, frame demand, recovery, solver replay, execution, return intent and
art-independent phase timing are exercised. The owner subsequently confirmed completion of all
remaining tests and explicitly directed M7/M8 closure; both are **Done by owner acceptance**.
This does not convert missing quantitative evidence into independently measured passes.

Manual/visual portions are accepted by the owner's report of all remaining M7/M8 tests and
explicit closure instruction (2026-10-18). AC-M8-15 data/alpha/baseline/budget checks and visual
approval are recorded; AC-M8-16 synthetic/fallback/actual-art trajectory comparisons pass.
No per-point native event matrix, hardware details, frame-pacing/energy/wakeup readings, two-hour
duration or leak-delta record was supplied with that confirmation. Existing paused CPU variability
remains recorded. See [owner closeout](m7-m8-technical-review.md#owner-m7m8-closeout-2026-10-18),
[testing.md](../development/testing.md) and [performance.md](../specifications/performance.md)
for the distinction between milestone acceptance and independently recorded measurements.
M9 was subsequently reauthorized separately; no release/tag/commit is authorized by milestone acceptance.
