# Surface Detection

Surfaces are the walkable/climbable geometry pets interact with. Decision on the Dock:
[ADR-0009](../decisions/0009-dock-geometry.md). Windows: [window-tracking.md](../architecture/window-tracking.md).

## Current model and proposed extensions

At HEAD 2f7f33f Surface contains id/kind/horizontal segment; SurfaceMap implements lookup/diffs,
spawnSurface and highestWalkable(below: CGPoint). Orientation/walkableSide/isMoving/source and rich
queries in the target sketch below are **future design, not implemented API**. The M7/M8 working tree adds the
swept query and pure floor builder specified by [Physics Engine](../architecture/physics-engine.md);
no new Platform observer. Existing surface IDs/geometry/offset preference contract is reused.

## Target model (future beyond M6)

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
| Core `SurfaceMap.screenBottoms(for:)` (M7 proposal) | Pure descriptor→floor values, runtime merges host floor + Dock; no new observer/provider. Walls remain a separate M11 design | M7 / M11 |
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
| `.bottom` | `.dockTop` (ID `dock`) at `y = visible.minY + dockOffsetAdjustment`, spanning `frame.minX…frame.maxX` of the Dock's screen | MVP target. Full width because the shelf's horizontal extent is unknown; the half-pet-width margin is applied by the world's walkable range (FR-08), not baked into the segment |
| `.left` / `.right` | `.screenBottom` of that screen | Vertical Dock as climbable surface is FR-43 (future) |
| `.hiddenOrUnknown` | `.screenBottom` of the primary screen | Auto-hide: pet walks on the screen edge; the Dock appearing on hover is not tracked in the MVP |
| estimate for a screen that is gone | `.screenBottom` of the primary screen | Defensive; the next screen change re-estimates |

Ties between equal insets keep the first screen (primary first), then bottom before left before right.

### Implementation (M6)

| Piece | Where | Role |
|---|---|---|
| `DockEstimate`, `DockGeometryEstimator` | Core `Surfaces/` | Pure estimate and surface selection above (`minimumInset` 10 pt, `offsetAdjustmentRange` −40…+40, `clampedOffset`) |
| `DockSurfaceProvider` | Platform `Dock/` | Keeps the current estimate, offset and walkway; logs changes (category `dock`); owns no observer |
| `OverlayCoordinator` | Runtime | Calls `dock.update(screens:)` on every screen change and hosts the overlay on `dock.hostScreenID` (the Dock's screen, else the primary) |
| `PetRuntime` | Runtime | Feeds `dock.surfaces` to the world; `setDockOffsetAdjustment(_:)` persists the offset and moves the walkway |

Fallback re-read (ADR-0009 risk, no polling): when a suspension ends (wake, display wake, unlock, session
active again, leaving a full-screen Space) the coordinator reads the screens again and applies them only if they
differ, in case a change made meanwhile was not notified.

Pets and walkway changes: a resized Dock keeps the `dock` ID, so an attached pet is re-projected by parameter
and clamped (`edgeReached` fires on the next step if it hit an end). A Dock hidden, shown or moved to a side
swaps `dock` and a screen bottom: the pet goes through `recovering(surfaceLost)` and re-settles on the new
surface at the same x (clamped, same facing) when that surface spans its x, else it respawns at random (e.g.
its screen disappeared). M7 proposes falling for removed support (AC-M7-02), with floor retained when a Dock appears;
exceptional host loss/invalid body still uses the existing recovery path. Full rules, including
paused/airborne geometry changes and first-hit collision, are in Physics Engine. No M7 code exists yet.

`dockOffsetAdjustment` (points, default 0, range −40…+40) is a user/debug preference for visual
alignment with the shelf. Exposed in a DEBUG menu in the MVP (Debug › Dock offset: ±1/±5 pt, reset; Debug ›
Show walkway draws the surface as a green line) and in Settings → Advanced in M9. Persisted as
`petscape.dockOffsetAdjustment` and clamped on read and write; it moves only the Dock top, not the screen-bottom
fallback.

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
