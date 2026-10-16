# Proof of Concept — Overlay, Click-through, Dock

- **Goal:** validate assumptions A1–A5 ([scope.md](../product/scope.md)) before building the real app.
- **Status:** In progress — E1, E2, E4, E7 done (renderer → Core Animation, ADR-0015); E3/T1.4 tooling
  ready, Dock setting changes pending (owner); E5, E6, E8 not started.
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
| E2 | **Confirmed (strategy C)** | Cursor warp test: body → interactive, transparent corner → pass-through, each toggle within one frame. Owner's manual session (log 15:18–15:20): real mouse movement toggled interactivity with **0.9 / 3.8 / 9.1 ms** latency after the first global mouse-moved event over the sprite (≤ 1 frame) — so the global mouse-moved monitor **delivers events without any permission**; 7 click/drag sequences on the cat received; **no `BLOCKED` events** (no click on a transparent pixel was swallowed). Owner confirmed that clicks around the cat reached the apps underneath normally. Strategies A/B not exercised (reference only; C is the chosen design). |
| E3 | **First data point** | With the current Dock (bottom inset 65 pt): shelf top edge at `visibleFrame.minY` +1.0 pt (`scripts/dock-probe.swift`; manual pixel check: 0 pt); lowest paw pixels within ≤ 1.5 pt. Other Dock sizes, magnification, auto-hide, left/right and change notifications pending — they need the owner to change Dock settings (see "Dock test procedure" below). |
| E4 | **Confirmed (strategy C)** | Owner dragged the cat repeatedly (e.g. x 749 → 904, 1304 → 1335 pt): every mouseDown/mouseUp logged `PoC active=false panel key=false frontmost app=Claude` — the frontmost app kept focus and PetScape never activated. Interactivity stayed on for the whole drag and was released after mouseUp. A drag ending at y = 0 (screen bottom) shows the cursor can leave the sprite mid-drag without losing the drag. |
| E5 | — | Not started (T1.6). |
| E6 | — | Not started (T1.6). |
| E7 | **Done → Core Animation adopted ([ADR-0015](../decisions/0015-core-animation-renderer.md))** | See "E7 measurements" below. Walking 40 pt/s while animating: SpriteKit ~115 MB and 5.7% CPU (fails both targets); Core Animation ~19 MB and ~1.0% CPU; both 0% CPU when paused. WindowServer CPU delta similar for both (coarse). |
| E8 | — | Not started (T1.8). |

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
| 1 | Current (baseline) | +1.0 pt, inset 65 pt | — |
| 2 | Size: minimum | | |
| 3 | Size: maximum | | |
| 4 | Magnification on (hover over the Dock while probing is not needed) | | |
| 5 | Automatically hide and show the Dock: on | | |
| 6 | Position on screen: Left | | |
| 7 | Position on screen: Right | | |
| 8 | Back to bottom, original size | | |

## Manual click matrix (E2, to be run by the owner)

With the PoC running (paw icon in the menu bar), for each strategy A, B and C:

1. Click, double-click, right-click and scroll on points **around** the cat (between the legs, under
   the tail, above the back) over a Finder window, the desktop, the Dock and another app.
2. Click and drag **on** the cat.
3. Choose **Log status** from the menu and note `spriteEvents`, `blockedEvents` and the toggle latency.

Expected: A — everything passes through, the cat receives nothing; B — note whether transparent
pixels block (`BLOCKED` lines); C — no `BLOCKED` lines, the cat receives clicks/drags, the frontmost
app keeps focus.

## Decision rules

- E2-C fails (events lost/stolen) → evaluate per-pet small windows (ADR-0003 alternative 2) within
  the remaining timebox; if both fail, stop and escalate to the owner.
- E3 offset not constant → keep heuristic + manual offset, and plan the AX Dock frame earlier.
- E7 fails for SpriteKit but passes for CALayer → supersede ADR-0004.
- E6 shows the overlay over fullscreen apps → adjust collection behavior and re-test.
