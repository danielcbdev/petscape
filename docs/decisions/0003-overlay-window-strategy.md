# ADR-0003: Per-screen transparent overlay panels with dynamic mouse pass-through

- Status: Proposed (pending PoC E1, E2, E4, E6)
- Date: 2026-10-16
- Related: [macos-integration.md](../architecture/macos-integration.md), [proof-of-concept.md](../planning/proof-of-concept.md)

## Context

Pets must be drawn above the desktop, the Dock and other windows, and the user must be able to click
anything that is not a pet. `NSWindow.ignoresMouseEvents` is a per-window switch, and visual
transparency does not reliably imply event transparency for layer/Metal-backed content.

## Problem

Choose the window topology and the click-through mechanism.

## Alternatives

1. One large overlay per screen, permanently click-through → pets can never be interacted with.
2. One small window per pet, moved every frame → window-server work per frame, N Metal views for
   N pets, transparent margins still block clicks.
3. **One large overlay per screen, click-through by default, made interactive only while the cursor
   is over a pet's opaque pixels** (hybrid).
4. Rely on the window server's per-pixel alpha hit-testing → behavior not guaranteed; not relied on.

## Decision

Option 3: `OverlayPanel` (`NSPanel`, `.borderless` + `.nonactivatingPanel`, clear, no shadow,
never key/main), level `dockWindow − 1` (revised from `+ 1` after PoC Dock test 5b: a revealed auto-hide
Dock must cover the pet, and its reveal is not observable through public API), collection behavior
`[.canJoinAllSpaces, .stationary, .ignoresCycle]`, frame = `screen.frame`, one per screen hosting
pets (MVP: the Dock screen). `MousePassthroughController` toggles `ignoresMouseEvents` from alpha-mask
hit tests using `NSEvent.mouseLocation` per frame and a global mouse-moved monitor while paused.

## Rationale

It keeps movement cheap (sprites move inside a static window), scales to multiple pets with one view
per screen, needs no permissions, and makes click-through deterministic.

## Consequences

- Cross-screen movement requires handing pets between overlays (M14).
- The pass-through state machine must keep interactivity during drags and release it reliably.

## Risks

| Risk | Mitigation |
|---|---|
| Latency between cursor entering the pet and the window accepting events | Measure in PoC; ≤ 1 frame expected |
| Global mouse-moved monitor needs a permission on some macOS version | Fallback: 10 Hz timer only while paused and visible |
| Overlay level interferes with Dock interactions | Resolved by placing the overlay just below the Dock level (PoC Dock tests 4 and 5b) |
| Behavior in fullscreen Spaces/Stage Manager differs from expectation | PoC E6; adjust collection behavior |
| If PoC E2 fails | Fall back to option 2 (small window per pet) and supersede this ADR |
