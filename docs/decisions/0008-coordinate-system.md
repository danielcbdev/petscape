# ADR-0008: Canonical AppKit global coordinate space

- Status: Proposed
- Date: 2026-10-16
- Related: [coordinate-system.md](../specifications/coordinate-system.md)

## Context

AppKit (`NSScreen`, `NSWindow`, `NSEvent.mouseLocation`) uses a y-up global space anchored at the
primary screen's bottom-left; Quartz (`CGWindowList`, AX, `CGEvent`) uses a y-down space anchored at
the primary display's top-left; SpriteKit scenes are y-up and local to each view; images are y-down
pixels. Multi-monitor setups produce negative coordinates.

## Problem

Coordinate mistakes are the most likely source of subtle bugs (pets offset by the menu bar height,
mirrored hit tests, wrong screen after rearrangement).

## Alternatives

1. Let each module use its native space and convert ad hoc.
2. Use Quartz global space as canonical.
3. **Use AppKit global space as canonical; convert at the boundaries in one place.**
4. Introduce distinct wrapper types for every space.

## Decision

Option 3, with a light version of option 4 only at the boundary: Quartz values are wrapped
(`QuartzRect`) inside Platform adapters and converted by `CoordinateConverter` before leaving them.
Inside the app, every `CGPoint`/`CGRect` is canonical unless named otherwise (`overlayPoint`, …).
The primary screen is `NSScreen.screens.first`, never `NSScreen.main`.

## Rationale

AppKit global space is what most inputs already use and matches the y-up layer coordinates of non-flipped views, so most
values need no conversion. Wrapping only Quartz inputs prevents the riskiest mix-ups without
wrapper-type noise everywhere.

## Consequences

- `CoordinateConverter` has exhaustive unit tests (multi-screen, negative coordinates, mixed scales).
- Code review rule: any `H − y` arithmetic outside the converter is a defect.

## Risks

| Risk | Mitigation |
|---|---|
| Stale converter after display changes | Rebuilt on every screen-parameters notification |
| Confusing `NSScreen.main` with the primary screen | Lint-by-review rule; helper `ScreenProvider.primary` |
