# ADR-0020: Bounded selective input, coarse alpha hit testing and nonactivation

- Status: **Proposed — native PoC and owner approval required; ADR-0003 still governs production**
- Date: 2026-10-18
- Would amend: [ADR-0003](0003-overlay-window-strategy.md), input topology only
- Related: [ADR-0015](0015-core-animation-renderer.md), [ADR-0019](0019-cursor-observation.md),
  [native PoC](../planning/m10-native-poc.md), [architecture](../architecture/interaction-system.md)

## Context

Production uses a screen-sized nonactivating NSPanel, dynamically interactive over the current
coarse alpha mask, latched until up. PetHitTester already returns the topmost PetID with mirroring
and scale. This is not a new pixel-perfect requirement. Window-wide event acceptance and stale
samples can intercept transparent clicks; a view returning nil cannot route a selected event to
another application. Historic native evidence does not cover all M10 sequences.

## Problem

Limit interception, preserve Dock and focus, and select one native routing strategy based on
observable underlying-app behavior rather than transparent appearance.

## Alternatives

1. Extend current dynamic full-screen gate: few changes, broad physical capture when active.
2. Resize render panel around pet: no extra window, but changes rendering origin/driver lifecycle.
3. Keep static render panel always ignoring mouse and add a bounded nonactivating input panel.
4. Rectangle-only hit testing / visual alpha / view hitTest: cannot satisfy transparent regions.

Hit policies considered: full canvas rectangle (cheap, false positives), inset rectangle (misses
poses/tail, blocks holes), geometric shapes (maintenance per pose), existing reduced alpha mask
(load-time cost already paid, matches actual frames, handles scale/flight). Retain the last.

## Decision

Propose option 3 as preferred candidate, **not approved topology**. First test option 1 as control,
then compare 3 in T10.0. Select 3 only if transparent holes, rapid entry/exit, Dock, sequence
continuity outside bounds, focus and resource gates pass and owner approves amendment.
If 1 alone passes all requirements and 3 has unacceptable cost, record evidence and obtain owner
approval for retaining it; do not silently discard the bounded-capture objective. If neither passes,
no-go for direct-interaction engineering until revised design.

Reuse coarse alpha≥128, 4×4 decoded-pixel cells with one-cell dilation; do not expand capture to
perception radius. Re-hit-test down against rendered frame and latch one PetID/InteractionID.
Never capture an already-held external mouse drag. Rendering owns any input panel; Runtime's
existing MousePassthroughController remains sole event-acceptance writer.

Use fixed construction-time borderless/nonactivating style, never key/main, acceptsFirstMouse,
AX exclusion, Dock−1 level, existing Space behavior and full-screen gate. No activate/makeKey,
no dynamic nonactivating-style mutation, no global click cancellation, no synthesized clicks.

## Rationale

Reuse existing geometry/masks while minimizing the physical event rectangle without moving the
render window every frame. NSPanel policy supports nonactivation by documented design; actual
focus preservation and transparent routing must be observed in the PoC.

## Consequences

Candidate adds one input window only for the current single cat, no duplicate renderer/driver.
It follows snapshot canvas and closes before target destruction. Future targeting uses IDs and
stable topmost order, without implementing multiple pets. Public native down/drag/up is used,
not NSPasteboard drag-and-drop. Accepted ADR-0003 remains unchanged until this proposal is accepted.

## Risks

Transparent holes and toggling races remain even in a small rectangle. Small windows may increase
WindowServer work or lose drag/up when moved/occluded. Dock occlusion, gestures involving scroll
or secondary buttons, inactive-app clicks and Space transitions can differ by OS. Any observed
swallowed unrelated click or focus theft is a PoC failure, not a tolerable implementation detail.
