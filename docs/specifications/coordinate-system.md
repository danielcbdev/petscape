# Coordinate System

Decision: [ADR-0008](../decisions/0008-coordinate-system.md).

## Canonical space

**All domain positions use the AppKit global screen space**:

- Unit: **points** (never pixels).
- Origin: bottom-left corner of the **primary screen** (`NSScreen.screens.first`, the one with the
  menu bar at origin) — *not* `NSScreen.main` (the screen of the key window).
- Y axis points **up**.
- Other screens may have negative coordinates (left of or below the primary screen).

Rationale: it is the space of `NSScreen.frame`, `NSWindow.frame` and `NSEvent.mouseLocation`, and
its y-up orientation matches the layer coordinates of a non-flipped `NSView`, so most values need no
conversion at all.

Types: Core uses CoreGraphics' `CGPoint`, `CGSize`, `CGRect`, `CGVector` — imported explicitly, because
the macOS 27 SDK's Foundation no longer re-exports the CoreGraphics Swift overlay (`==`, `.zero`,
`contains`) — (no custom geometry
wrappers) plus `Segment`. **Any `CGPoint`/`CGRect` outside a Platform adapter is canonical global**
unless its name says otherwise (`overlayPoint`, `localRect`, `quartzRect`).

## Spaces in play

| Space | Used by | Origin | Y | Unit |
|---|---|---|---|---|
| AppKit global (**canonical**) | `NSScreen`, `NSWindow.frame`, `NSEvent.mouseLocation`, Core | primary screen bottom-left | up | points |
| Quartz global | `CGWindowListCopyWindowInfo`, AX (`kAXPositionAttribute`), `CGEvent.location`, `CGDisplayBounds` | primary display top-left | down | points |
| Window local | `NSView` (non-flipped) | window content bottom-left | up | points |
| Overlay-local | `OverlayContentView` and its layers (non-flipped; panel origin = screen origin, also for bottom-band overlays) | overlay bottom-left = screen bottom-left | up | points |
| Texture / image | `CGImage`, hit masks | image top-left (CGImage rows) | down | pixels |
| Normalized canvas | manifest `anchor` | canvas bottom-left | up | 0…1 |

## Conversions (the only allowed ones)

Let `H` = height of the primary screen frame (`NSScreen.screens[0].frame.height`).

| From → To | Formula | Lives in |
|---|---|---|
| Quartz point → global | `(x, H − y)` | `CoordinateConverter` (Core) |
| Quartz rect → global | `(x, H − y − h, w, h)` | `CoordinateConverter` |
| Global → Quartz | inverse of the above | `CoordinateConverter` |
| Global → overlay-local (screen S) | `p − S.frame.origin` | `CoordinateConverter` |
| Overlay-local (screen S) → global | `p + S.frame.origin` | `CoordinateConverter` |
| Normalized anchor → layer anchor | identical (`CALayer.anchorPoint` is also unit-normalized, bottom-left origin in a non-flipped view) | `PetLayer` |
| Global → frame mask cell | `local = (p − petOrigin) / size` → flip x if mirrored → `row = (1 − local.y) × rows` | `PetHitTester` |
| Points → pixels | `× backingScaleFactor` of the target screen | texture sizing only |

Rules:

1. Quartz values are converted **inside the Platform adapter that reads them** and never escape it
   (wrapped as `QuartzRect` until converted).
2. Every conversion goes through `CoordinateConverter`; no ad-hoc `H − y` arithmetic elsewhere.
3. `CoordinateConverter` is built from a `[ScreenDescriptor]` snapshot and rebuilt when screens change.
4. `NSView.convert`/`CALayer.convert` are not used for domain math (keeps Core testable).

## Screen descriptors

```text
ScreenDescriptor (Sendable)
  id: ScreenID              // CGDirectDisplayID for the session
  frame: CGRect             // global, points
  visibleFrame: CGRect      // global, points (excludes menu bar and Dock reservation)
  backingScale: Double      // 1.0, 2.0, …
  isPrimary: Bool
```

The Platform `ScreenProvider` produces them; Core never touches `NSScreen`.

## Pixels, Retina and snapping

- Simulation and layout are in points; Core Animation composites at each screen's backing scale.
- Texture pixel size is chosen from the **maximum** backing scale among connected screens.
- Sprite positions are not pixel-snapped while moving (snapping causes stutter at low speeds);
  stationary sprites may be snapped to `round(p × scale) / scale` to avoid soft edges — to be
  decided visually in M5.

## Configuration changes

On `NSApplication.didChangeScreenParametersNotification` (resolution, scaling, arrangement,
connect/disconnect, Dock changes): rebuild descriptors → rebuild converter → re-layout overlays
(new frames) → update surfaces → pets re-project their attachments. If a pet's screen disappears,
it is respawned on the Dock screen.

## Unit tests (T3.1)

- Single screen 1440 × 900: quartz ↔ global round-trips for points and rects (top, bottom, corners).
- Two screens side by side; secondary to the **left** (negative x) and **above/below** (negative y,
  y greater than H): round-trips and global → overlay-local for each.
- Secondary screen taller than primary (H must come from the primary, not the tallest).
- Mixed backing scales (1× + 2×): points unaffected; pixel sizing picks 2×.
- Mirrored sprite hit mask lookup: a point on the left paw hits the correct mask cell in both facings.
- Property test: random rects within screen bounds round-trip exactly (within 1e-9).
