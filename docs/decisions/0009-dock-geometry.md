# ADR-0009: Dock geometry from public-API heuristics + manual offset

- Status: **Accepted** (owner, 2026-10-16) — confirmed by PoC E3 (constant +1.0 pt offset for Dock sizes 22–45; every
  Dock change notified; auto-hide reserves 0 pt). See [proof-of-concept.md](../planning/proof-of-concept.md#dock-test-procedure-e3--t14-owner-changes-the-settings)
- Date: 2026-10-16
- Related: [surface-detection.md](../specifications/surface-detection.md)

## Context

The first visual goal is a cat walking on the bottom Dock. macOS offers no public API that returns the
Dock's rectangle. Private APIs are forbidden; the MVP must not require Accessibility.

## Problem

How to locate the Dock's top edge (and its position/auto-hide state) reliably enough.

## Alternatives

| Option | Accuracy | Cost / constraints |
|---|---|---|
| **`NSScreen.frame` vs `visibleFrame` insets** | Reserved area, not the exact shelf | Public, no permission, notification-driven |
| `com.apple.dock` preferences (`orientation`, `autohide`, `tilesize`) | Indirect | Undocumented; keys absent at defaults (observed); unavailable in sandbox |
| `CGWindowListCopyWindowInfo` for the Dock process | Unknown — the Dock's windows may not match the shelf | Needs validation; may need Screen Recording for some fields |
| AX tree of the Dock process | Exact shelf frame | Requires Accessibility (not in MVP) |
| Private SPI (`CoreDock…`) | Exact | Forbidden |

## Decision

Use the `visibleFrame` inset heuristic (`DockGeometryEstimator`, pure and tested) with:
a minimum inset threshold to detect auto-hide, fallback to the screen bottom when the Dock is hidden
or on the left/right, a user/debug `dockOffsetAdjustment`, and full-screen-width walking. The AX-based
exact frame is a post-MVP enhancement behind the same provider interface.

## Rationale

It is public, permission-free and cheap, and its error is a near-constant vertical offset that a
manual adjustment fixes.

## Consequences

- The cat walks the full width of the screen, including beyond the shelf's ends.
- With auto-hide, the cat walks on the screen's bottom edge.

## Risks

| Risk | Mitigation |
|---|---|
| `visibleFrame` changes not notified when the Dock is resized/moved/auto-hidden | PoC E3; fallback re-reads on Space change/resume or 0.5 Hz while running |
| Reserved height ≠ shelf top by a version-dependent amount | `dockOffsetAdjustment`; measured default per macOS major if stable |
| Cat walking "in the air" beyond the shelf ends looks odd | Accept for MVP; AX enhancement later |
