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
Status: **Done by owner acceptance (2026-10-22); documented evidence limits accepted at closeout.** Original IDs retained. AC-M10-01 historically
required release velocity; current planning brief explicitly defers throwing. Initial scope is
preserved-offset pickup and **zero-impulse** drop through existing physics. AC-M10-02 retains
AC-14/21 and adds explicit click correctness. [Exact thresholds, scenarios and task ownership](m10-implementation.md#acceptance-risk-and-regression-matrix).
A = deterministic automated, N = native/manual, P = measured performance.

| ID | Acceptance | Method |
|---|---|---|
| AC-M10-01 | Cursor dwell/hysteresis/finite interest and preserved-offset drag, zero-impulse release | A + N |
| AC-M10-02 | One valid primary click reaction; no click for drag; AC-14 and AC-21 retained | A + N |
| AC-M10-03 | Transparent regions pass click/right/scroll/external drags, ≥20 points +100 rapid sweeps | N |
| AC-M10-04 | No focus/key/main/typing theft, 50 cat sequences with two foreground apps | N |
| AC-M10-05 | Bottom/side Dock, auto-hide and magnification remain usable | N |
| AC-M10-06 | Cursor respects sleep/flight/transitions/energy; bounded saved-context return | A |
| AC-M10-07 | No repeated reaction loop, per-event RNG or competing behavior engine | A |
| AC-M10-08 | <4 pt press versus ≥4 pt pickup; primary only, no externally started drag acquisition | A + N |
| AC-M10-09 | Offset/target correct within 1e-9 before clamp, scaled/mirrored/negative origins | A + N |
| AC-M10-10 | Final up target consumed once; zero velocity then existing gravity; stale moves rejected | A |
| AC-M10-11 | First valid landing or bounded existing recovery, no invisible/stuck/no-surface loop | A + N |
| AC-M10-12 | Lost primary up ends once by next delivered frame, native target≤50 ms; secondary release safe | A + N |
| AC-M10-13 | Gates/teardown cancel ownership; no inactive simulation/catch-up | A + N |
| AC-M10-14 | Dock/display/Space/resolution changes remain safe; no implicit cross-display handoff | A + N |
| AC-M10-15 | Existing clips preserved, held visible, physics independent of art/events | A + N |
| AC-M10-16 | Missing/invalid V5 and pack fallbacks safe; Reduce Motion supported | A + N |
| AC-M10-17 | Both settings work live/after relaunch; v3 migration/restore/future keys; VoiceOver controls | A + N |
| AC-M10-18 | Relevant tests/lint/Debug/Release pass, warnings and limitations explicitly recorded | A |
| AC-M10-19 | Native PoC/topology approval before adoption; public APIs/no new permission | N + review |
| AC-M10-20 | Paired performance, latency, footprint/allocation/leak/soak gates measured and reviewed | P |

Automated results are recorded per task in the [M10 implementation record](m10-implementation.md).
The owner confirmed all tests approved and directed closure on 2026-10-22. Specific native/performance
measurement values were not supplied in that message; see the [owner closeout](m10-implementation.md#owner-m10-closeout--2026-10-22)
for accepted evidence limits. Existing baseline check results are separately recorded in the
[M10 planning verification](m10-implementation.md#current-baseline-verification-2026-10-18).

### M11 — Climbing
- **Status:** Done by owner acceptance (2026-10-22). The owner confirmed the cat climbed and approved the visual result; automated tests cover both wall directions, mirrored alignment, top exit and continuous fall. No quantitative native paw-offset measurement was reported.
- AC-M11-01: The cat climbs both screen edges with paws aligned to the edge (±3 pt) and transitions back to the floor without teleporting.
  Verify both sides at the bundled 96 pt display size, including the mirrored left-wall pose,
  top exit, valid support contact and a continuous fall trajectory; unit alpha/anchor tests alone do
  not satisfy the native visual criterion.

### M12 — Window detection
- AC-M12-01: Without the feature enabled, no AX calls are made and no permission is requested.
- AC-M12-02: With permission, window top surfaces match real window frames within 2 pt for ≥ 10 common apps (Finder, Safari, Mail, Xcode, Terminal, Notes, System Settings, Preview, a Catalyst app, an Electron app).
- AC-M12-03: Tracking adds ≤ 1% CPU idle.

### M13 — Window interaction
- AC-M13-01: The cat stays on a window being dragged slowly (≤ 1 frame lag visually) and falls when the window is closed/minimized.
- AC-M13-02: With autonomy and window interaction enabled, the cat sometimes selects a visible window at random, jumps to an exposed vertical side below the top (never directly to the top), climbs onto the top, walks there for a bounded random interval, then jumps back to Dock. With several eligible windows, each is selectable; unavailable or unsafe routes are skipped without teleporting or getting stuck.

Owner closeout (2026-10-23): the owner validated and accepted M13. The documented ≤2 Hz tracker cadence
does not establish AC-M13-01's one-frame target; the owner accepts this evidence limitation for the
milestone closeout. See the [M13 closeout](milestones.md#m13-owner-closeout--2026-10-23).

### M14 — Stabilization
- AC-M14-01: 8 h soak: no crash, memory growth < 10 MB. **Dispensado pelo proprietário em 2026-10-23; não executado e não aprovado por medição.** This does not establish NFR-03 or continuous stability/memory targets.
- AC-M14-02: Manual matrix passes on macOS 14 (VM) and current macOS. **Not run; evidence gap accepted by the owner for M14 closeout on 2026-10-23.**
- AC-M14-03: The cat moves between two displays correctly (both arrangements, mixed DPI). **Native validation not run; evidence gap accepted by the owner for M14 closeout on 2026-10-23.**

Owner exception: the continuous 8-hour soak in AC-M14-01/T14.5 is explicitly waived. It must be
reported as **dispensado pelo proprietário**, never as executed/passed; accelerated runs are not a
substitute. T14.5 still requires separate short leak, memory and overlay lifecycle checks. See the
[M14 verification record](m14-implementation.md).

Owner closeout (2026-10-23): the owner approved the documented M14 results and authorized milestone
closure with the evidence limits above. AC-M14-01 remains waived, not run, and not measurement-approved;
AC-M14-02 and AC-M14-03 remain unverified. This closeout does not represent any unrun criterion as
passed and does not establish NFR-03 or long-term stability.

### M15 — Animation quality

These are acceptance checks, not passing results. Frame counts below are proposals in the
[M15 inventory](m15-implementation.md); revise them only with a documented visual/timing reason.

- AC-M15-01 [Auto, review]: Inventory every clip referenced by the cat's runtime manifest with ordered frame count, FPS, duration, events, visual diagnosis, target count, rationale and production state.
- AC-M15-02 [Man]: Each proposed additional frame is a distinct authored pose with genuine transparent RGBA art; the existing cat identity, canvas/scale, anchor/contact registration, silhouette margin and lighting remain consistent. No duplicated, interpolated or artifact-producing deformed frames.
- AC-M15-03 [Auto, Man]: Manifest frame count and FPS preserve each intended total duration; event entry times, fallbacks, anchors, alignment and `displaySize` remain correct. The schema validator accepts the manifest and every referenced image exists.
- AC-M15-04 [Auto]: Existing pack/manifest tests, lint and Debug build pass; original source assets and their recorded hashes remain unchanged.
- AC-M15-05 [Man]: Play and inspect each changed clip and its transitions at manifest timing; record fluency, registration, scale, alpha/crop, timing and event results. A generated still or contact sheet alone does not pass.
- AC-M15-06 [Review]: The M15 record documents accepted assets and their provenance, or clearly identifies the remaining owner action. M16–M20 remain planning-only during M15.

- AC-M15-07 [Auto, Man, owner follow-up]: With autonomy enabled, supported rest/expression states share a five-second stop budget, followed by a walking interval; automatic jumps/Dock returns resume walking. Rest becomes infrequent. Speed remains configurable through 0.5–4, with synchronized paw cadence/ground motion and unchanged approved art. User pause, holding and disabled autonomy remain explicit exceptions.

### M16 — New behaviors and animations

Contract: [M16 implementation](m16-implementation.md). These are criteria; their evidence is
recorded separately. **M16 was closed by explicit owner acceptance on 2026-10-24** after the owner
reported all behavior working. The [closeout](m16-implementation.md#owner-m16-closeout--2026-10-24)
preserves the inherited V8 QA failure and unmeasured permission/performance/VoiceOver limits;
acceptance is not a fabricated pass for unrun checks.

- AC-M16-01 [Review]: Track tasks and define sessions, unavailable states, timing, precedence, landing provenance and art dependency before code.
- AC-M16-02 [Auto]: Confidence hysteresis confirms start/stop, tolerates short silence/oscillation, rejects invalid samples and rearms only after a confirmed stop.
- AC-M16-03 [Auto]: One automatic dance per session; repeat only after stop/start; deterministic inclusive 5–30 s bounds, duration expiry while music continues and immediate confirmed-stop exit.
- AC-M16-04 [Auto]: Manual dance requires no audio, has a finite 5–30 s bound, replaces automatic once; automatic never replaces manual and repeated manual requests cannot prolong it. Owner follow-up: Stop Dance exits either dance immediately, preserves the consumed music session, and is disabled outside dancing.
- AC-M16-05 [Auto]: Pause/hide/suspend, hold, support loss, physical phases and autonomy off cannot be overwritten; cancellations recover without pending replay.
- AC-M16-06 [Auto]: Exactly one cleanup after stable descending contact on Dock from above; owner follow-up adds held release from above onto Dock or screen ground. Exclude same-Dock/upward jumps, walking, placement without a fall, window landings and resume; ordinary non-release floor landings remain unchanged.
- AC-M16-07 [Auto, Man]: Opt-in public system-output tap only on supported OS; no forbidden permission, microphone, network, file recording or sensitive logs. Native consent, denial, revocation and output-route changes tested separately.
- AC-M16-08 [Auto, Man]: Capture/analyzer resources and callbacks stop on off, pause/hide/suspend, unavailable pet/autonomy and quit; stale results ignored; failures recover safely. Native resource verification remains required.
- AC-M16-09 [Auto, Man]: Normal menu/Settings offers bounded manual dance, explains ineligibility and pending art; keyboard/VoiceOver and consent verified with the installed app.
- AC-M16-10 [Review, Man]: Complete per-clip prompts and paths; unchanged images and valid existing manifest. M16 cannot be Done until owner art integration and visual QA.
- AC-M16-11 [Auto, Review]: Record lint, package/UI, Debug/Release and asset validator results; preserve M15 V8 exception and all unverified evidence.

### M17 — Portuguese and English localization

- AC-M17-01 [Review]: Every user-visible product string is inventoried, including menu, Settings, M16 music/dance and permission copy, M18 character states, accessibility text, debug UI, and localized Info.plist values. Logs and developer-only diagnostics are identified separately.
- AC-M17-02 [Auto]: Every shipped source string has a nonempty English source and Brazilian Portuguese (`pt-BR`) translation; no M17-introduced dead or duplicate catalog keys remain. English is the source language.
- AC-M17-03 [Auto]: Language selection respects the ordered macOS preferred languages and uses the first supported language; English and English regional variants select English, `pt` variants including `pt-PT` select `pt-BR`, and no supported match falls back to English.
- AC-M17-04 [Auto, Man]: The selected locale reaches MenuBarExtra, Settings, consent/status/errors and all M18 UI. Product messages are not materialized using the process-default locale outside the views.
- AC-M17-05 [Review, Man]: Audio-capture and Accessibility permission explanations and privacy descriptions are accurate and understandable in both languages; the native audio usage-description is localized.
- AC-M17-06 [Auto]: Placeholders and interpolated values preserve meaning and use locale-aware number, plural and unit formatting where applicable.
- AC-M17-07 [Auto]: Localized catalogs and Info.plist resources are present in the app bundle in Debug and Release; source language and supported regions match the catalog.
- AC-M17-08 [Auto, Review]: Existing M15/M16 behavior and M18 character-selection behavior are preserved; the M18 second-real-character criterion remains deferred and no M19/M20 feature is introduced.
- AC-M17-09 [Man]: Menu and Settings fit and remain legible in English and Brazilian Portuguese; no clipped text or unusable controls in the longer Portuguese copy.
- AC-M17-10 [Man]: Keyboard and VoiceOver labels, hints, statuses, consent sheets and character selection are reviewed in both locales; any unexecuted native evidence is recorded as pending.
- AC-M17-11 [Auto, Man]: A running app updates its SwiftUI locale after a supported system locale-change notification; if macOS does not deliver a language-preference change during the process, the restart limitation and user indication are documented.

M17 was closed by explicit owner acceptance on 2026-10-24 with AC-M17-09 (native layout),
AC-M17-10 (native keyboard/VoiceOver review), and the native portion of AC-M17-11 (live system
language-change behavior) unverified and accepted as evidence limits. These criteria are not
recorded as passed; see the [M17 closeout](milestones.md#owner-m17-closeout--2026-10-24).

### M20 — Settings redesign & multiple active characters

- AC-M20-01 [Review, Man]: The Settings screen has a substantially redesigned, coherent native macOS information architecture and visual hierarchy. It remains legible at supported window sizes and long English/pt-BR copy does not clip or hide controls.
- AC-M20-02 [Auto, Review, Man]: Every pre-M20 Settings capability remains available with its control, permission, persistence, status/error handling and global scope preserved: character discovery/import; size/speed; pause/hide/wake; autonomy, jumping, resting and expressions; manual Dance/Stop Dance; music-dance consent/status/retry; login item; window interaction; cursor reaction; click/drag; Dock offset; language guidance; and Restore Defaults. Autonomous activity cadence follows AC-M20-13.
- AC-M20-03 [Auto, Man]: The active roster supports empty, one-pet and multiple-pet states and presents stable character names/source labels clearly. The user can add any valid inactive bundled or installed character and remove any individual active pet, including one in an active behavior/interaction phase, without removing or disturbing another. When both packs are available, manual verification activates Cat and Dimas together.
- AC-M20-04 [Auto]: At most one active pet exists for each stable character ID. Add is disabled or otherwise safely rejected for an already-active ID, including concurrent/late requests and after relaunch.
- AC-M20-05 [Auto]: Existing `petscape.selectedCharacterID` migrates to the new roster without losing a valid saved selection. Missing, unknown, invalid and duplicate persisted IDs recover according to documented fallback rules; restart and Restore Defaults behavior are tested.
- AC-M20-06 [Auto]: Adding one pet does not replace, teleport, reset, interrupt, or change settings/animation/interaction of existing pets. Removing one pet in any behavior/interaction/physics phase safely releases only its identity, capture, subscriptions, async loading and render resources; remaining pets continue correctly.
- AC-M20-07 [Auto]: Pet-specific state is independent: two pets may simultaneously occupy different states, positions/surfaces, animation frames, movement and activity timings. Seeded random choices/timers are independent per pet; an action or cancellation on one pet does not mirror onto or mutate another pet.
- AC-M20-08 [Auto, Review]: Existing global preferences retain their documented semantics and apply consistently to eligible pets. A music-start signal reaches each eligible pet as it does today, while each pet advances its own behavior/timing state; manual Dance and Stop Dance always target an explicit pet and never silently target `pets.first` when several are active.
- AC-M20-09 [Auto]: Each active pet renders with its own validated character definition, clip availability, display size, frame count and behavior-family resources; hit testing and interaction routes resolve to the correct PetID. Late async results for a removed pet cannot respawn it or affect another pet.
- AC-M20-10 [Auto, Review]: Active-pack asset loading/release and aggregate memory/CPU are evaluated against existing limits. Any concurrency cap is based on evidence, localized, accessible and tested; absent such evidence, distinct valid catalog entries are not arbitrarily capped. Measurements include environment and method.
- AC-M20-11 [Auto, Man]: All new or changed product copy is present in English and pt-BR, with source/source labels and errors localized. Keyboard navigation, focus order, control labels/hints, dynamic roster updates and VoiceOver are reviewed for add/remove and per-pet actions.
- AC-M20-12 [Auto, Review]: `make lint`, `make test-core`, `make test`, Debug and Release builds, and relevant pack validation complete and are reported accurately. Existing M15 V8 pixel-QA failures are neither hidden nor reclassified as M20 failures/passes. Native visual, VoiceOver and performance checks not actually run remain explicitly unverified.
- AC-M20-13 [Auto, Man]: Default autonomous choices expose Jump and eligible WindowExcursion more often while remaining seeded and bounded; window excursions land in the lower third of the available side span, climb to the top, dwell for 7–19 simulated seconds, return safely to the Dock, and observe a 20-second cooldown. Existing states and clips are used; no new art, animation state, or permission is introduced. Seeded distribution/trajectory tests pass; the owner manually tested the revised variation and confirmed it worked on 2026-10-25.

### M21 — Release pipeline
- AC-M21-01 [Auto, Review]: A clean Release build can be packaged locally and by GitHub Actions using ad-hoc signing and no paid Apple account, Developer ID certificate, Apple credentials, or notarization service.
- AC-M21-02 [Auto]: The produced app bundle passes code-signature integrity verification and is clearly identified as ad-hoc signed. Documentation and logs never represent this signature as Developer ID identity, Apple verification or notarization.
- AC-M21-03 [Auto]: The release package contains the expected app, version/release notes and SHA-256 checksum. The checksum validates after download/extraction; documentation explains it detects accidental corruption but does not independently authenticate a release if the package and checksum are both replaced.
- AC-M21-04 [Auto]: The local script and CI use the same documented version, archive, package and checksum steps. Invalid version inputs fail before packaging; repeated builds do not alter source files or require untracked developer credentials.
- AC-M21-05 [Auto, Review]: GitHub Actions runs relevant checks, uses a supported standard macOS runner and least-privilege token permissions, pins third-party actions to reviewed immutable references, and never exposes or requires Apple signing/notarization secrets. CI dry-run uploads an artifact but does not create/publish a release.
- AC-M21-06 [Auto, Review]: Any workflow path that creates a GitHub release has explicit opt-in publication, defaults to dry-run/no publication, and is not exercised during this implementation without separate owner authorization. No tag, push or public release is created by implementation verification.
- AC-M21-07 [Man, Review]: English installation documentation explains that macOS may warn that the developer is unidentified or that Apple cannot check the app; it never promises warning-free first launch or a passing `spctl --assess`. It gives accurate, cautious steps for a user who has independently chosen to trust the source, and does not instruct disabling Gatekeeper or removing quarantine metadata.
- AC-M21-08 [Auto, Man, Review]: A clean supported macOS environment records the actual package/install/first-launch flow and checksum validation. Results distinguish a successful user-approved launch from Apple verification; existing M15 V8 test failure remains visible and is not weakened, hidden or claimed to pass.

M21's criterion-by-criterion local evidence and unverified components are recorded in
[m21-implementation.md](m21-implementation.md). M21's local delivery was closed by owner direction
on 2026-10-25 with these evidence limits retained. AC-M21-01/05/08 still have unverified hosted or
clean-machine components; closure does not turn them into passed checks. Existing failed quality
gates remain a release blocker; no exception is silently converted into a pass.

The subsequent v1.0.0 publication instruction explicitly authorizes a bounded exception for the
known V8 failure only, recorded in [release-exceptions.json](../development/release-exceptions.json).
The full failed test remains in reports; every other gate must pass. Universal DMG/ZIP and per-slice
integrity are now part of publication validation. Native Intel and clean-machine Gatekeeper evidence
are not inferred from cross-compilation or milestone closure. See the [publication follow-up](m21-implementation.md#v100-publication-follow-up--2026-10-25).

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

## M18 — Bundled character selection

Status: **Done by explicit owner acceptance**, 2026-10-24, with retained exceptions. Generic
implementation is delivered; only one real character ships. **AC-M18-08 remains unmet and deferred**
by the owner, rather than passed. Native keyboard/VoiceOver/visual execution and performance remain
unverified; the existing V8 exception is unchanged. Synthetic test fixtures are never shipping
options. At M18 closeout, M17 had not yet been implemented; it was subsequently authorized and
closed separately with native evidence limits recorded. See the [owner closeout](milestones.md#owner-m18-closeout--2026-10-24)
and [engineering evidence](milestones.md#m18-engineering-evidence--2026-10-24).

| ID | Objective criterion | Verification |
|---|---|---|
| AC-M18-01 | Only immediate bundled packs with valid schema, clips, decodable resources and unique manifest IDs appear; malformed/duplicate packs excluded with informative status | Runtime catalog fixtures and actual built bundle |
| AC-M18-02 | Zero/one/many Settings states are honest; native picker marks active character, supports keyboard/VoiceOver; no generated preview art or debug UI | Model tests, native UI assertions; full VoiceOver manual |
| AC-M18-03 | First run selects cat then lexical valid-ID fallback; saved ID restores; removed/unknown ID repairs after successful application; zero valid retains preference and uses placeholder | Isolated preference/selection tests |
| AC-M18-04 | Two valid test packs swap atomically at a supported safe boundary, preserving position/facing/surface and global preferences; physical/held/climbing/incompatible geometry reject without mutation | Core/Runtime deterministic tests |
| AC-M18-05 | Failed candidate/changed identity never replaces current pet or preference; stop/cancellation/late load cannot commit | Injected loader tests |
| AC-M18-06 | Old frames, masks, snapshots, events and lazy completion cannot update the replacement or stopped runtime; paused/hidden gates remain intact | Runtime tests and identity guards |
| AC-M18-07 | Existing M16 behavior/art and M15 closeout/V8 exception preserved; no external discovery, new dependencies or translations; Git integration only under separate owner authorization | Diff, lint, package/UI/build checks; docs |
| AC-M18-08 | User can select between at least two real, complete bundled characters; owner reviews visual/native swap | **Unmet; deferred by owner at closeout: second real pack absent**; test fixtures do not satisfy this criterion |

## M19 — Character pack discovery and installation

| ID | Acceptance | Verification |
|---|---|---|
| AC-M19-01 | Settings offers a native folder picker for a local folder whose root contains `character.json`; the app requests no new privacy permission, keeps no bookmark and accepts no archive/network source | UI flow, file-access review, permissions matrix |
| AC-M19-02 | The selected tree is bounded and inspected without following symlinks; aliases and special files are rejected; unreferenced regular files are ignored and never copied or executed | Temporary directory tests including symlink, alias/special-file fixture where supported, excessive depth/count, and copy inventory |
| AC-M19-03 | The existing schema-v1 decoder and validator govern metadata, clips, events, fallbacks and all declared image paths; unsafe, ambiguous, duplicate-normalized, missing, malformed, non-PNG, multi-image, oversized or over-budget content is rejected with localized actionable copy | Runtime/Rendering tests for each rejection family, source-image format/dimensions/frame-count/byte/decoded-budget checks |
| AC-M19-04 | Import snapshots and validates the source, writes only the manifest and referenced PNGs to same-volume staging, revalidates staging, then exclusively promotes atomically to `<id>`; cancellation/failure leaves installed packs and selection unchanged; existing destinations are never overwritten | Installer tests for validation, copy, staging, promotion, duplicate race and failure cleanup |
| AC-M19-05 | Startup combines valid bundled and immediate installed folders with stable order and visible origin; bundled IDs cannot be shadowed; conflicting/duplicate/corrupt installed packs are omitted without blocking other entries or startup | Catalog tests with real bundled root and isolated user-root fixtures |
| AC-M19-06 | Installed packs use the existing M18 selector and transactional runtime swap; ID-only persistence stays unambiguous under catalog-wide uniqueness; failed load, cancellation, busy state, incompatible geometry or late work preserves the active character and preference | Selection/runtime deterministic tests, including bundled preference preservation, stop, stale completion and lazy-load guards |
| AC-M19-07 | Missing/removed/corrupt persisted user selection follows M18 fallback: only successful application updates the saved ID; if no valid candidate exists the placeholder appears and the prior preference is retained | Isolated preference/catalog tests for removal, corruption and empty catalog |
| AC-M19-08 | Settings identifies bundled versus installed sources and presents empty/loading/success/invalid/duplicate/error states with accessible controls; every new string is translated in English and pt-BR | String Catalog validation, both-locale model/UI assertions, keyboard and VoiceOver review |
| AC-M19-09 | M19 has no update/overwrite, network, archive or in-app removal. External folder changes are discovered on restart; deleting a pack is documented to happen while PetScape is quit | Documentation review and duplicate/restart tests |
| AC-M19-10 | M15/M16/M17/M18 behavior, closeouts, V8 exception and deferred AC-M18-08 remain unchanged; lint, relevant package/UI tests, Debug/Release builds and manifest/assets validation results are recorded honestly. Done additionally requires a real external pack and manual install/select review; fixtures alone do not satisfy that gate | Diff/doc review, automated gates, exact manual evidence and owner acceptance |
