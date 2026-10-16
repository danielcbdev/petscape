# ADR-0015: Core Animation renderer (supersedes ADR-0004)

- Status: Accepted (owner decision D-14, 2026-10-16)
- Date: 2026-10-16
- Supersedes: [ADR-0004](0004-spritekit-as-renderer.md); amends the frame driver of [ADR-0013](0013-simulation-loop.md)
- Related: [animation-system.md](../architecture/animation-system.md), [proof-of-concept.md](../planning/proof-of-concept.md#e7-measurements-2026-10-16)

## Context

ADR-0004 chose SpriteKit as a renderer and made it conditional on PoC E7. The PoC measured both
renderers on macOS 27.0.1 / Apple silicon with the same overlay panel, sprite and hit testing
(release builds, `footprint` + `top`):

| Scenario (288 px frames) | SpriteKit | Core Animation |
|---|---|---|
| Animating in place, 60 Hz | ~106 MB, ~1.8% CPU | ~19 MB, ~0.5% CPU |
| Animating + walking 40 pt/s, 60 Hz | ~115 MB, ~5.7% CPU | ~19 MB, ~1.0% CPU |
| Paused frame source | ~72 MB, 0% CPU | ~16 MB, 0% CPU |

SpriteKit's cost comes from Metal drawables (scaling with overlay area) plus ~30–45 MB of rendering
resources once content changes every frame; texture size, atlases and frame rate barely changed it.
WindowServer CPU rose by a similar ~1–1.5 points with either renderer (coarse check on a busy desktop),
so Core Animation does not visibly shift cost to the window server.

## Problem

SpriteKit misses the memory target (≤ 100 MB) and, while walking, the CPU target (≤ 5%) in
[performance.md](../specifications/performance.md). Which renderer should the app use?

## Alternatives

1. Keep SpriteKit and accept the cost (or reduce features).
2. **Core Animation:** one `CALayer` per pet whose `contents` is the current frame `CGImage`,
   positioned from the snapshot, driven by a `CADisplayLink`.
3. Metal directly — more work than Core Animation for no measured benefit.

## Decision

Option 2. `PetScapeRendering` renders snapshots with Core Animation:

- `OverlayContentView`: layer-backed, non-flipped `NSView`, content of each `OverlayPanel`; receives
  mouse events while pass-through is disabled.
- `PetLayer` (one per pet): `contents` = frame `CGImage`, `contentsGravity = .resize`,
  `bounds` = manifest `displaySize × userScale`, `anchorPoint` = manifest anchor, mirroring via an
  affine transform `scaleX: -1` around the anchor. Implicit animations are disabled
  (`actions` set to `NSNull` / `CATransaction.setDisableActions(true)`) so changes are discrete and
  driven only by the simulation.
- `FrameImageStore`: decoded, downsampled `CGImage`s per frame (shared by layers and hit masks).
- Frame source: `CADisplayLink` from the overlay view (`NSView.displayLink(target:selector:)`,
  macOS 14+) wrapped by `DisplayLinkFrameDriver` in Runtime; pausing = `isPaused = true`; adaptive
  rate = `preferredFrameRateRange`.
- Debug visuals: `CAShapeLayer`s (`DebugOverlayLayer`) and signposts instead of SpriteKit statistics.
- Future effects: `CAEmitterLayer` for particles (e.g. sleep "z"), layer `filters` where needed.

The domain rules from ADR-0004 remain: rendering only displays snapshots; no animation timing or
physics lives in the renderer.

## Rationale

About 5× less memory and 3–6× less CPU for the same visual result, verified visually in the PoC
(transparent, sharp, animating). Core Animation is a stable, first-party framework with no
dependency on a game engine, and keeping the renderer behind snapshots preserves the option to
change again.

## Consequences

- No SpriteKit dependency; `PetScapeRendering` imports AppKit, QuartzCore and ImageIO.
- We own small pieces SpriteKit gave for free: debug statistics (signposts + DEBUG overlay) and
  texture batching (unnecessary at this scale).
- The simulation is driven by `CADisplayLink` instead of `SKScene.update(_:)` (ADR-0013 amended).
- Overlay-local coordinates replace "scene" coordinates (same math: global − screen origin).

## Risks

| Risk | Mitigation |
|---|---|
| Many pets/effects could change the balance | Re-measure in M14 (performance protocol); renderer stays isolated |
| Implicit Core Animation animations sneaking in (visual lag) | Disable actions on pet layers; review rule in AGENTS.md |
| Display link behavior on multi-display setups | One `FrameDriver`; verified in M14 |
