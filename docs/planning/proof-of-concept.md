# Proof of Concept — Overlay, Click-through, Dock

- **Goal:** validate assumptions A1–A5 ([scope.md](../product/scope.md)) before building the real app.
- **Status:** **Done (2026-10-16)** — all assumptions confirmed or resolved; see "Conclusion" at the end.
  Open checks carried into later milestones: resolution change evidence (M3 matrix), external displays (M14),
  macOS 14 (M14).
- **Timebox:** 2–3 days. If an experiment exceeds its timebox, record the partial result and move on.
- **Code location:** branch `spike/overlay-poc`, a separate minimal Xcode project. **Not merged**;
  only this document and ADR updates are merged. Code quality is "spike" level (no architecture),
  but no private APIs.
- **Out of scope:** physics, behavior, the final module structure, settings.

## Environment to record for every result

macOS version, Mac model, display(s) (resolution, scaling, refresh rate), Dock settings
(position, size, magnification, autohide), Stage Manager on/off, appearance (light/dark).

## Experiments

### E1 — Transparent overlay with SpriteKit (A1)

Setup: `NSPanel` `[.borderless, .nonactivatingPanel]`, `isOpaque = false`, `backgroundColor = .clear`,
`hasShadow = false`, level `CGWindowLevelForKey(.dockWindow) + 1`, frame = main screen frame; content
`SKView(allowsTransparency: true)`, scene `backgroundColor = .clear`; sprite `walk_01.png` at 96 pt.

Success: no visible background/border/shadow; sprite edges clean on light and dark wallpapers
(note any halo — audit F7); sprite crisp on Retina.

### E2 — Click-through (A2)

Strategies (switchable from the menu): **A** always ignore; **B** never ignore (WindowServer alpha
hit-testing); **C** dynamic toggle from an alpha mask using `NSEvent.mouseLocation` per frame, plus a
global `.mouseMoved` monitor while paused.

Procedure: click/double-click/right-click/drag/scroll on 20 points around and on the sprite, over
Finder desktop icons, a Safari window, the Dock and the menu bar.

Success (C): 100% of events outside the sprite reach the underlying target; events on the sprite are
received by the PoC; toggle latency ≤ 1 frame (timestamps in logs); no permission prompts.
Record B's behavior for reference (do not rely on it).

### E3 — Dock placement (A3, A4)

Procedure: place the paws at `visibleFrame.minY`; screenshot at Dock sizes small/default/large,
magnification on/off; toggle autohide; move the Dock left/right; log whether
`didChangeScreenParametersNotification` fires for each change and what `visibleFrame` reports.

Success: offset between paws and the shelf top is constant (± 2 pt) across Dock sizes, so a single
`dockOffsetAdjustment` default works; autohide detectable by inset threshold; change notifications
fire (or the fallback strategy is chosen). Owner judges the cat's size against the Dock (A4).

### E4 — Interaction with the pet

Procedure: with strategy C, click the sprite and drag it horizontally.
Success: the PoC receives mouse down/drag/up; the frontmost app stays frontmost and keeps keyboard
focus; no PetScape activation; drag stays smooth (no lost events at fast moves).

### E5 — Resolutions and displays

Procedure: change scaling ("Larger Text" ↔ "More Space"), connect/disconnect an external display,
rearrange displays (secondary left/above, negative coordinates), mixed Retina/non-Retina.
Success: overlay re-lays out to the correct screen frame within 1 s; sprite size constant in points.

### E6 — Spaces, Mission Control, Stage Manager, fullscreen, lock

Success: overlay visible on all desktop Spaces and stays put during Space switches; not shown as a
window in Mission Control/App Exposé; clicks pass through with Stage Manager on; **absent** over
fullscreen apps; hidden behind the lock screen; screen saver covers it.

### E7 — Energy baseline (A5)

Procedure: release build outside Xcode; animate 8 frames at 9 fps while moving at 40 pt/s, 60 fps
render. Measure 60 s each: walking, paused (`SKView.isPaused`), hidden (ordered out).
Success: walking ≤ 5% CPU; paused/hidden ≈ 0% CPU and ≤ 1 wakeup/s. If walking exceeds the target,
build a CALayer variant (contents swap + position updates) and compare (ADR-0004).

### E8 — Non-interference with Dock and system UI

Procedure: with the overlay above the Dock, hover to magnify, click apps, right-click Dock menus,
drag a file onto a Dock icon, open menu bar menus and Control Center over the overlay, trigger a
notification banner and a system alert (e.g. Bluetooth/permission dialog in another app).
Success: all behave exactly as without PetScape; system UI appears above the overlay.

## Implementation notes

- Spike code: branch `spike/overlay-poc`, folder `poc/OverlayPoC` (local worktree `.worktrees/overlay-poc`).
- Deviation from T1.1: a SwiftPM executable wrapped into an ad-hoc signed `.app` (`LSUIElement`,
  Hardened Runtime) by `scripts/make-app.sh`, instead of an Xcode project — avoids hand-written
  `project.pbxproj` for throwaway code; behavior is that of a real bundled accessory app.
- Builds with zero warnings in Swift 6 language mode (Xcode 27.1 / Swift 6.4); SpriteKit and AppKit
  APIs used needed no concurrency workarounds beyond `MainActor.assumeIsolated` in callbacks.

## Results

Environment (2026-10-16): macOS 27.0.1 (26A434), Apple silicon, built-in Retina display
1470 × 956 pt @2x, single display, Dock at the bottom (default size, magnification and autohide as
configured by the owner; `visibleFrame` bottom inset 65 pt, menu bar 33 pt), dark appearance.

| Exp | Result | Notes / evidence |
|---|---|---|
| E1 | **Confirmed** | Screen capture of the Dock region: no background, border or shadow; sprite crisp at 96 pt; drawn above app windows and the Dock. Overlay reported by the window server at layer 21 (Dock 20, menu bar 24), full-screen bounds, on-screen. `SKView` is backed by `CAMetalLayer`. |
| E2 | **Confirmed (strategy C)** | Cursor warp test: body → interactive, transparent corner → pass-through, each toggle within one frame. Owner's manual session (log 15:18–15:20): real mouse movement toggled interactivity with **0.9 / 3.8 / 9.1 ms** latency after the first global mouse-moved event over the sprite (≤ 1 frame) — so the global mouse-moved monitor **delivers events without any permission**; 7 click/drag sequences on the cat received; **no `BLOCKED` events** (no click on a transparent pixel was swallowed). Owner confirmed that clicks around the cat reached the apps underneath normally. Second owner session: strategy C 0 blocked events (latency 5.4 ms); **strategy B blocked 427 events** — the window server does not pass clicks through transparent pixels of this (Metal-backed) overlay, so relying on it (strategy B) is ruled out. Strategy A not exercised (trivially passes everything). |
| E3 | **Confirmed** | Dock test procedure below (8 steps + 5b): shelf top edge at a **constant +1.0 pt** below `visibleFrame.minY` for tile sizes 22–45 (insets 42–65 pt), magnification does not change it; auto-hide gives a reservation of exactly 0 pt; left/right Docks give a 49 pt side inset. **Every** size/position/auto-hide change posted `didChangeScreenParametersNotification` (0.01–0.97 s before the 1 Hz check). Revealing an auto-hidden Dock posts nothing → overlay level lowered to `dockWindow − 1` (test 5b). |
| E4 | **Confirmed (strategy C)** | Owner dragged the cat repeatedly (e.g. x 749 → 904, 1304 → 1335 pt): every mouseDown/mouseUp logged `PoC active=false panel key=false frontmost app=Claude` — the frontmost app kept focus and PetScape never activated. Interactivity stayed on for the whole drag and was released after mouseUp. A drag ending at y = 0 (screen bottom) shows the cursor can leave the sprite mid-drag without losing the drag. |
| E5 | **Partial** | Single built-in Retina display only. Resolution change: owner reports OK, but no screen-frame change was logged (S8) → re-check in M3. External displays, negative coordinates and mixed DPI not tested (no hardware) → M14. |
| E6 | **Confirmed (with fix)** | Spaces, Mission Control, App Exposé, Stage Manager, lock and display sleep behave as expected and post usable events (S1–S4, S6, S7). Full-screen apps are **not** excluded by the collection behavior → Dock-window rule (S5) hides the overlay ~1 s after entering a full-screen Space. |
| E7 | **Done → Core Animation adopted ([ADR-0015](../decisions/0015-core-animation-renderer.md))** | See "E7 measurements" below. Walking 40 pt/s while animating: SpriteKit ~115 MB and 5.7% CPU (fails both targets); Core Animation ~19 MB and ~1.0% CPU; both 0% CPU when paused. WindowServer CPU delta similar for both (coarse). |
| E8 | **Confirmed** | Dock magnification and clicks (Dock test 4), Dock context menus, drag-and-drop onto Dock icons, menu bar menus, Control Center, notification banners and alerts all work with the overlay running (S10–S14); no events swallowed outside the cat. |

Additional findings:

- The Dock process exposes a single window at layer 20 whose bounds are the **whole screen**, so
  `CGWindowList` cannot locate the Dock shelf (supports ADR-0009).
- `CGWindowListCopyWindowInfo` returned window bounds and layers of other processes from a plain
  command-line tool on this machine; whether that holds without any Screen Recording grant must
  still be checked on a clean setup (T12.1).
- A window is not immediately visible to `CGWindowListCopyWindowInfo` right after `orderFrontRegardless()`
  (registration is asynchronous); query later when diagnostics need it.

## E7 measurements (2026-10-16)

Method: unbundled release binary, one variant at a time (strategy A, sprite at 20% of the width,
geometry poll off), `footprint -p` after 6–8 s (30 s for the settling check), CPU = mean of 5 `top`
samples at 2 s. Footprint is the process's own memory; window-server memory is not included for
either renderer.

| Variant | Footprint | IOSurface | GPU (unmapped graphics) | CPU |
|---|---|---|---|---|
| SpriteKit, full screen, 512 px, static | 110–117 MB | 55 MB | 29 MB | 0.8% |
| SpriteKit, full screen, 288 px, static | 108 MB | 55 MB | 29 MB | 0.7% |
| SpriteKit, 300 pt band, 512 px, static | 80 MB | 36 MB | 11 MB | 0.8% |
| SpriteKit, 300 pt band, 288 px, static | 72 MB | 36 MB | 11 MB | 0.7% |
| SpriteKit, 300 pt band, 288 px, animating 60 fps | 106 MB | 18 MB | 59 MB | 1.7–1.9% |
| SpriteKit, same, 30 fps | 106 MB | 18 MB | 59 MB | 1.5% |
| SpriteKit, same, after 30 s | 106 MB | 18 MB | 59 MB | 1.7% |
| SpriteKit, 150 pt band, 288 px, animating | 120 MB | 36 MB | 54 MB | 1.7% |
| SpriteKit, 300 pt band, 288 px, animating, runtime atlas | 105 MB | 18 MB | 59 MB | 1.8% |
| SpriteKit, full screen, 512 px, animating | 172–174 MB | 55 MB | 77 MB | 1.8% |
| SpriteKit, 300 pt band, paused | 72 MB | 36 MB | 11 MB | 0.0% |
| **Core Animation**, full screen, 512 px, static | 16 MB | — | — | 0.4% |
| **Core Animation**, full screen, 512 px, animating 60 fps | 23 MB | — | — | 0.5% |
| **Core Animation**, full screen, 288 px, animating | 19 MB | — | — | 0.5% |
| **Core Animation**, 300 pt band, 288 px, animating | 19 MB | — | — | 0.5% |
| **Core Animation**, paused display link | 16 MB | — | — | 0.0% |
| SpriteKit, 300 pt band, 288 px, animating + walking 40 pt/s | 115 MB | 26 MB | 59 MB | **5.7%** |
| **Core Animation**, full screen, 288 px, animating + walking 40 pt/s | **19 MB** | — | — | **1.0%** |
| **Core Animation**, 300 pt band, 288 px, animating + walking 40 pt/s | 19 MB | — | — | 1.0% |

WindowServer CPU (coarse, busy desktop with the owner's SpriteKit PoC instance still running):
~39% without a variant, ~40.6% with Core Animation walking, ~40.2% with SpriteKit walking — no
measurable shift of cost to the window server.

Interpretation:

- SpriteKit's cost is dominated by Metal drawables (scale with overlay area) plus ~30–45 MB of
  rendering resources that appear as soon as content changes every frame; texture count/size,
  atlases and frame rate barely matter. It does not settle over time.
- With Core Animation the window server composites layer contents; the process keeps only the
  decoded images. Visually verified: the CA variant renders the cat transparently and animates
  (two captures 350 ms apart show different frames).
- Both renderers reach ~0% CPU when their frame source is paused.
- Not yet covered: several pets, window-server-side memory,
  and effects that SpriteKit would provide (particles, shaders).

**Decision (owner, 2026-10-16, D-14):** Core Animation renderer behind the same snapshot boundary —
[ADR-0015](../decisions/0015-core-animation-renderer.md) supersedes ADR-0004. Particles remain
possible with `CAEmitterLayer`.

## Dock test procedure (E3 / T1.4, owner changes the settings)

PetScape agents do not change system settings; the owner performs each change below, and then
`swift scripts/dock-probe.swift` (in `poc/OverlayPoC`) is run and its RESULT line recorded. The
relaunched PoC (`open build/OverlayPoC.app`) also logs whether each change arrived with a
`didChangeScreenParametersNotification` or was only detected by its 1 Hz geometry poll.

| # | Dock setting (System Settings › Desktop & Dock) | Probe RESULT | Notification? |
|---|---|---|---|
| 1 | Current (baseline, tile size 45) | +1.0 pt, inset 65 pt | — |
| 2 | Size: minimum (tile size 22) | +1.0 pt, inset 42 pt; paws visually on the shelf | Yes (0.9 s) — also for intermediate sizes (insets 56/70/63/64) and a brief move to the left (inset l=49) and back |
| 3 | Size: maximum (slider at "Large"; macOS capped tile size at 44 because the Dock already spans almost the full 1470 pt width) | +1.0 pt, inset 64 pt | Yes (0.3 s) |
| 4 | Magnification on (large size 86) | +1.0 pt, inset 64 pt — magnification does not change the reservation | No change to notify (expected); owner: hover magnification and clicks unaffected by the cat, no `BLOCKED` events |
| 5 | Automatically hide and show the Dock: on | Reservation exactly 0 pt (not ~4 pt) → pet moves to the screen bottom (owner confirmed) | Yes (0.01 s) when toggling auto-hide; **revealing the hidden Dock posts nothing and does not change `visibleFrame`** → with the overlay above the Dock level, the cat is drawn over the revealed Dock and its pixels cover Dock icons (owner observation) |
| 5b | Auto-hide on, overlay level lowered to `dockWindow − 1` (19) via `POC_LEVEL_OFFSET=-1` | — | Owner: the revealed Dock slides **over** the cat, Dock icons above the cat are clickable, and the cat stays visible at the screen bottom when the Dock hides → **level 19 adopted** (ADR-0003 updated) |
| 6 | Position on screen: Left (auto-hide off) | Left inset 49 pt, bottom 0 → pet on the screen bottom (owner confirmed) | Yes (0.8 s when auto-hide turned off, 0.65 s when moved left) |
| 7 | Position on screen: Right | Right inset 49 pt, bottom 0 → pet on the screen bottom (owner confirmed) | Yes (0.8 s) |
| 8 | Back to bottom, original size (tile 44), auto-hide off, overlay level 19 | +1.0 pt, inset 64 pt; owner: cat back on the Dock, paws visible with the overlay below the Dock level | Yes (0.45 s) |

## Spaces, displays and system UI procedure (E5 / E6 / E8, owner performs the actions)

Run the PoC as the walking Core Animation demo (cat walks on the Dock, mirrors at the edges):

```bash
open --env POC_RENDERER=ca --env POC_ANIMATE=1 --env POC_MOVE=1 --env POC_TEXTURE_PX=288 poc/OverlayPoC/build/OverlayPoC.app
```

After each step, the PoC log shows what the system reported (Spaces, sleep, lock, occlusion, geometry):

```bash
/usr/bin/log show --last 2m --predicate 'subsystem == "io.github.danielcbdev.petscape.poc"' | grep -E "system event|occlusion|geometry changed|BLOCKED"
```

| # | Exp | Action | Expected | Result |
|---|---|---|---|---|
| S1 | E6 | Create a second desktop (Mission Control → "+") and switch with Ctrl+→ / Ctrl+← | Cat visible and walking on both desktops; `activeSpaceDidChange` logged | Log: 4 switches, `activeSpaceDidChange` each time; overlay occlusion goes `visible=false` for ~0.2–0.6 s during the transition and back to `true` (overlay follows to every Space). ✅ Owner: cat visible and walking on both Spaces — **but the second Space was a full-screen app**: the overlay showed over it (see S5) and the cat floated at the Dock height because `visibleFrame` is unchanged in a full-screen Space (no Dock there) |
| S2 | E6 | Open Mission Control (F3 or three-finger swipe up), then close it | Cat stays put, is not shown as a window thumbnail; Mission Control clicks work | ✅ Owner: cat stays put, Mission Control works. Log 16:10:42: snapshot with 26 on-screen windows and several menu-bar windows (Mission Control), overlay present |
| S3 | E6 | App Exposé (Ctrl+↓) on any app | Same as S2 | ✅ Owner |
| S4 | E6 | Turn on Stage Manager (Control Center), use the stage strip, turn it off | Cat visible; strip and windows clickable | ✅ Owner: cat visible, stage strip and windows clickable (no log signal for Stage Manager) |
| S5 | E6 | Put an app in full screen (green button), look at the bottom, exit full screen | Cat **not** shown over the full-screen app; back on the desktop afterwards | ❌ → ✅ The collection behavior alone does **not** exclude full-screen Spaces on macOS 27 (cat seen floating over a full-screen app, `visibleFrame` unchanged). Space snapshots: full-screen Spaces have **no on-screen Dock window** (4–6 windows), desktops always have the Dock's layer-20 window (15–18 windows), also with Dock auto-hide on; "window covers the screen" does not work (full-screen windows exclude the menu-bar strip). Rule implemented in the PoC (read twice, 400 ms apart, after `activeSpaceDidChange`): owner confirmed the cat **disappears in the full-screen Space** and returns on the desktop, ~1 s after each switch |
| S6 | E6 | Lock the screen (Ctrl+Cmd+Q), unlock | Cat not on the lock screen; `screenIsLocked`/`screenIsUnlocked` logged; cat still there after unlock | ✅ Owner + log: explicit lock 16:07:26 `screenIsLocked` → 16:07:29 `screenIsUnlocked`; also observed with display sleep (S7) |
| S7 | E6 | Display sleep: run `pmset displaysleepnow`, wake with a key | `screensDidSleep`/`screensDidWake` logged; cat resumes | ✅ Owner + log: `screensDidSleep` → `com.apple.screenIsLocked` (display sleep locked the screen) → `screensDidWake` → `com.apple.screenIsUnlocked`, then overlay occlusion false→true; all events arrive without permissions |
| S8 | E5 | System Settings › Displays: switch to a different resolution ("More Space" or "Larger Text"), then back | Cat keeps 96 pt size and stays on the Dock; `geometry changed` logged | ⚠️ Owner reports OK, but **no screen-frame change was logged** while the PoC was running, so the re-layout is not evidenced; re-check in the M3 manual matrix |
| S9 | E5 | (Optional, needs an external display) connect, arrange it left/above, move the Dock there, disconnect | No crash; cat stays on the Dock screen | Not run (no external display available) → multi-display validation moves to M14 |
| S10 | E8 | Right-click a Dock icon near the cat | Dock menu opens above the cat and works | ✅ Owner |
| S11 | E8 | Drag a file from Finder onto a Dock app icon (e.g. an image onto Preview) | Drop works, also when passing over the cat's area | ✅ Owner |
| S12 | E8 | Open a menu bar menu and Control Center | Both appear above the overlay | ✅ Owner |
| S13 | E8 | Trigger a notification: `osascript -e 'display notification "teste" with title "PetScape"'` | Banner appears above the overlay | ✅ Screen capture 1.2 s after triggering: banner drawn normally at the top right over all windows while the full-screen overlay was running |
| S14 | E8 | Show an alert: `osascript -e 'display alert "teste"'` and click OK | Alert appears and is clickable (note: an overlay at level 19 sits above normal dialogs; only the cat's own pixels could cover a button) | ✅ Alert shown, OK clicked (`button returned:OK`); no occlusion change, no `BLOCKED` events |

## Manual click matrix (E2, to be run by the owner)

With the PoC running (paw icon in the menu bar), for each strategy A, B and C:

1. Click, double-click, right-click and scroll on points **around** the cat (between the legs, under
   the tail, above the back) over a Finder window, the desktop, the Dock and another app.
2. Click and drag **on** the cat.
3. Choose **Log status** from the menu and note `spriteEvents`, `blockedEvents` and the toggle latency.

Expected: A — everything passes through, the cat receives nothing; B — note whether transparent
pixels block (`BLOCKED` lines); C — no `BLOCKED` lines, the cat receives clicks/drags, the frontmost
app keeps focus.

## Conclusion (T1.9)

| Assumption | Result |
|---|---|
| A1 Transparent overlay above the desktop/Dock | ✅ Confirmed (E1) |
| A2 Click-through by toggling `ignoresMouseEvents` from a hit test, no permissions | ✅ Confirmed (E2: 0.9–9.1 ms, 0 swallowed clicks; strategy B ruled out) |
| A3 `visibleFrame` as Dock edge estimate | ✅ Confirmed (E3: constant +1.0 pt, every change notified) |
| A4 Cat looks acceptable at ~96 pt | ✅ Owner accepted it during the Dock tests |
| A5 Animated sprite costs < 5% CPU | ✅ With Core Animation (~1% walking); ❌ with SpriteKit (5.7%) |

Changes to the architecture caused by the PoC (all already reflected in the docs):

1. Renderer: Core Animation instead of SpriteKit ([ADR-0015](../decisions/0015-core-animation-renderer.md)).
2. Overlay level: `dockWindow − 1` instead of `+ 1` (ADR-0003).
3. Full-screen app Spaces: Dock-window rule hides the overlay (ADR-0003, task T3.10, risk R-16).
4. Dock change detection: notification only, no polling (surface-detection.md, R-03 retired).

**Recommendation: go for M2.** Carried-over checks: resolution change evidence (M3 manual matrix),
external/multiple displays (M14), macOS 14 VM pass (M14), Stage Manager has no log signal (manual only).

## Decision rules

- E2-C fails (events lost/stolen) → evaluate per-pet small windows (ADR-0003 alternative 2) within
  the remaining timebox; if both fail, stop and escalate to the owner.
- E3 offset not constant → keep heuristic + manual offset, and plan the AX Dock frame earlier.
- E7 fails for SpriteKit but passes for CALayer → supersede ADR-0004.
- E6 shows the overlay over fullscreen apps → adjust collection behavior and re-test.
