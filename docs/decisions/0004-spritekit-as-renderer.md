# ADR-0004: SpriteKit as renderer only

- Status: **Superseded by [ADR-0015](0015-core-animation-renderer.md)** (2026-10-16, after PoC E7:
  SpriteKit ~115 MB / ~5.7% CPU walking vs Core Animation ~19 MB / ~1.0% CPU). Kept for history.
- Date: 2026-10-16
- Related: [animation-system.md](../architecture/animation-system.md), [performance.md](../specifications/performance.md)

## Context

The app draws a few animated sprites on transparent overlays, 60 fps while moving, and must be cheap
when idle. The initial stack proposal names SpriteKit.

## Problem

Which rendering technology, and how much of it the domain may depend on.

## Alternatives

| Option | Pros | Cons |
|---|---|---|
| **SpriteKit** | Texture management, node graph, built-in diagnostics (`showsFPS`, `showsDrawCount`, `showsNodeCount`), particles/shaders for later effects (e.g. sleep "z"), transparent `SKView` | Continuous Metal rendering while running; framework receives little new investment; easy to leak domain logic into `SKAction`/`SKPhysicsBody` |
| Core Animation (`CALayer` contents swapping) | Very low CPU; compositing in the window server; simple movement could even be CA animations | Per-frame dynamic motion (physics, riding windows) still needs a display-link loop; fewer tools for effects; manual texture/atlas handling |
| SwiftUI `Canvas`/`TimelineView` | Declarative | Not designed for a 60 fps game loop in an overlay; less control over energy |
| Metal directly | Maximum control | Large effort, no benefit at this scale |

## Decision

Use SpriteKit **as a renderer only**: `PetScene` draws `RenderSnapshot`s. No domain timing via
`SKAction`, no `SKPhysicsBody`, no game logic in `update(_:)` beyond forwarding the frame to the
runtime. Rendering is isolated in `PetScapeRendering`, so a Core Animation renderer can replace it.

## Rationale

SpriteKit gives the most capability per line of code for sprites and future effects, and its
diagnostics help the MVP. Keeping it behind snapshots limits lock-in.

## Consequences

- PoC E7 measures CPU/energy for SpriteKit; if walking costs > 5% CPU or paused costs are not ~0,
  a CALayer prototype is measured and this ADR may be superseded.
- Textures must be sized explicitly (SpriteKit treats `CGImage` pixels as points).

## Risks

| Risk | Mitigation |
|---|---|
| SpriteKit stagnation/deprecation | Renderer isolated behind snapshots; CA fallback documented |
| Energy cost of continuous rendering | Adaptive `preferredFramesPerSecond`; stop rendering when paused/hidden/suspended |
| Transparent `SKView` composition issues on some macOS versions | PoC E1 on current macOS + macOS 14 VM |
