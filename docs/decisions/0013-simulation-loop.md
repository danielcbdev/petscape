# ADR-0013: Fixed-timestep simulation driven by the display frame

- Status: Proposed — **frame driver amended by [ADR-0015](0015-core-animation-renderer.md)** (see
  "Amendment" below); fixed timestep decision unchanged
- Date: 2026-10-16
- Related: [physics-engine.md](../architecture/physics-engine.md), [data-flow.md](../architecture/data-flow.md)

## Amendment (2026-10-16, ADR-0015)

With SpriteKit removed, there is no `SKScene.update(_:)`. The frame driver is a `CADisplayLink`
obtained from the Dock screen's overlay view (`NSView.displayLink(target:selector:)`, macOS 14+),
wrapped as `DisplayLinkFrameDriver` behind the same `FrameDriver` protocol. Pausing the simulation
pauses the display link (`isPaused = true`); the adaptive render rate uses
`preferredFrameRateRange`. Everything else below (fixed `dt`, accumulator, clamps, reset on resume)
still applies. References below to the scene callback are historical.

## Context

Animation FPS (9–12) differs from render FPS (60, or 120 on ProMotion); physics needs determinism;
energy requires zero activity when nothing changes.

## Problem

What drives the simulation, and with which step.

## Alternatives

| Driver | Notes |
|---|---|
| `Timer` | Not display-synchronized; drift and jitter; separate wakeups |
| `CVDisplayLink` | Deprecated in favor of display links on `NSView`/`NSScreen` (macOS 14+) |
| `NSView/NSScreen.displayLink` (`CADisplayLink`) | Display-synced, independent of SpriteKit |
| **`SKScene.update(_:)` of the overlay scene** | Display-synced; stops automatically when `SKView.isPaused`; one clock for sim + render |

Step: variable `dt` vs **fixed `dt` with accumulator**.

## Decision

- MVP: the frame driver is the Dock screen's `PetScene.update(_:)`, abstracted as a `FrameDriver`
  protocol in Runtime. M14 (multiple overlays) may switch to `NSScreen.displayLink` behind the same
  protocol so only one clock drives the world.
- Fixed step `dt = 1/60 s`; accumulator with `maxStepsPerFrame = 5`; real frame delta clamped to
  0.25 s; accumulator reset on resume (no catch-up after pause/sleep).
- Rendering interpolation deferred until judder is measured at 120 Hz.

## Rationale

Using the scene's own callback avoids a second display-synced clock in the MVP; a fixed step makes
physics and behavior deterministic and testable regardless of display rate.

## Consequences

- The simulation can only run while a scene is rendering — consistent with "stop when paused".
- `preferredFramesPerSecond` changes alter how many steps run per frame, not the simulation outcome.

## Risks

| Risk | Mitigation |
|---|---|
| Multi-screen with several scenes double-stepping | Exactly one `FrameDriver` registered; asserted in DEBUG |
| 30 fps render while sleeping → 2 steps per frame | Cheap; acceptable |
