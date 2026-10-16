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
- AC-M7-01: Pets falling at terminal velocity onto 1-pt-thick segments never tunnel (property test, 10k random drops).
- AC-M7-02: Hiding the Dock makes the cat fall and land on the screen bottom within 1 s; no respawn teleport.
- AC-M7-03: Same seed + inputs ⇒ identical trajectories (determinism test).

### M8 — Jumps
- AC-M8-01: Jump solver lands within 1 pt of target for targets within max jump range.
- AC-M8-02: Takeoff happens on the `takeoff` frame; landing animation starts on contact (tests + owner review of recording).

### M9 — Behaviors & Settings
- AC-M9-01: Seeded scenario tests: tired lazy cat sleeps within N decisions; startled sleeping cat wakes; no activity repeats more than 3× in a row.
- AC-M9-02: Sleeping renders at ≤ animation fps (measured).
- AC-M9-03: Settings changes apply live and persist; "Restore defaults" resets all keys.
- AC-M9-04: Launch at login toggles correctly and reflects system state.

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
