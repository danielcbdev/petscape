# Surface Detection

Surfaces are the walkable/climbable geometry pets interact with. Decision on the Dock:
[ADR-0009](../decisions/0009-dock-geometry.md). Windows: [window-tracking.md](../architecture/window-tracking.md).

## Model (Core)

```text
Surface (Sendable, Equatable)
  id: SurfaceID            // stable identity (e.g. "dock", "screen:<id>:bottom", "window:<id>:top")
  kind: SurfaceKind        // .dockTop, .screenBottom, .screenLeft, .screenRight, .windowTop
  segment: Segment         // two points in canonical global space
  orientation: .horizontal | .vertical
  walkableSide: .above | .left | .right   // where the pet stands relative to the segment
  isMoving: Bool           // hint for physics (windows)
  source: .estimated | .measured | .manual
```

`SurfaceMap` holds the current set and answers queries:

| Query | Used by |
|---|---|
| `surface(id)` | attachment re-projection |
| `highestWalkable(below: point, xRange:)` | landing, spawn |
| `crossed(from: p0, to: p1)` | swept landing test |
| `nearest(to: point, kind:)` | recovery, behavior targets |
| `walls(near:)` | climbing (M11) |

Updates are applied as **diffs** keyed by `SurfaceID` (added / moved / removed) at the start of a
step, so attached pets can ride moved surfaces and react to removed ones
([physics-engine.md](../architecture/physics-engine.md)).

## Providers

| Provider | Surfaces | Milestone |
|---|---|---|
| `DockSurfaceProvider` | `.dockTop` or fallback `.screenBottom` on the Dock's screen | M6 |
| `ScreenEdgeSurfaceProvider` | `.screenBottom` for every screen (always present — the floor of last resort); `.screenLeft/.screenRight` walls | M7 / M11 |
| `WindowSurfaceProvider` | `.windowTop` visible segments | M12–M13 |

## Dock geometry estimation

The Dock's real geometry is not exposed by public AppKit API. `NSScreen.visibleFrame` excludes the
area **reserved** for the Dock and the menu bar, which is an estimate, not the Dock's visible shape:
the modern Dock is a floating shelf narrower than the screen, and the reserved height may include
padding. Magnification does not change the reservation.

Algorithm (`DockGeometryEstimator`, pure Core, fed by `ScreenDescriptor`s):

1. For each screen compute insets: `bottom = visible.minY − frame.minY`,
   `left = visible.minX − frame.minX`, `right = frame.maxX − visible.maxX`.
2. Candidate = the largest of those insets across all screens. If it is ≥ `dockMinInset`
   (10 pt; PoC E3: visible Docks reserved 42–65 pt at the bottom or 49 pt on a side, auto-hide reserved
   exactly 0 pt), the Dock is visible on that screen and edge.
3. If no candidate: Dock is auto-hidden or absent → `.hiddenOrUnknown`.
4. Result: `DockEstimate { screenID, position: .bottom/.left/.right/.hiddenOrUnknown, thickness, edgeLine }`.

Surface selection:

| Estimate | Surface | Notes |
|---|---|---|
| `.bottom` | `.dockTop` at `y = visible.minY + dockOffsetAdjustment`, x from `frame.minX + halfPetWidth` to `frame.maxX − halfPetWidth` | MVP target. Full width because the shelf's horizontal extent is unknown |
| `.left` / `.right` | `.screenBottom` of that screen | Vertical Dock as climbable surface is FR-43 (future) |
| `.hiddenOrUnknown` | `.screenBottom` of the primary screen | Auto-hide: pet walks on the screen edge; the Dock appearing on hover is not tracked in the MVP |

`dockOffsetAdjustment` (points, default 0, range −40…+40) is a user/debug preference for visual
alignment with the shelf. Exposed in a DEBUG menu in the MVP and in Settings → Advanced in M9.

Change detection: recompute on `didChangeScreenParametersNotification`. PoC E3 (macOS 27.0.1)
confirmed that Dock resize, position change and auto-hide toggling all post it (within ~1 s), so
**no polling is needed**. Revealing an auto-hidden Dock posts nothing and does not change
`visibleFrame`; this is handled by placing the overlay below the Dock level (ADR-0003), not by
detection. Measured shelf edge: a constant +1.0 pt below `visibleFrame.minY` across Dock sizes →
`dockOffsetAdjustment` default stays 0.

Optional hints considered and rejected for the MVP: reading `com.apple.dock` preferences
(`orientation`, `autohide`, `tilesize`). They are undocumented, unavailable in a sandbox, and keys
are absent when at default values (observed on the development machine: `orientation` and
`autohide` not present), so absence carries no information. May be used later for diagnostics only.

More accurate alternative (post-MVP, opt-in): with Accessibility granted, the Dock process's AX
tree exposes the Dock list's frame (exact shelf rectangle). Considered in M12 as an enhancement
behind the same `DockGeometryProvider` interface.

## Tests

- Estimator: bottom Dock (inset 70), left/right Docks, autohide (inset 0–4), two screens with the
  Dock on the secondary, menu-bar-only inset at the top ignored, negative-coordinate screens.
- Surface selection for each estimate, including the offset adjustment and half-width margins.
- `SurfaceMap` diffs: moved surface keeps ID; removed surface emits removal; queries return the
  highest crossed segment.
