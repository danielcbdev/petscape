# ADR-0023: Window interaction update cadence

- Status: Proposed; owner approval required before any AX concurrency change
- Date: 2026-10-23
- Related: [ADR-0012](0012-concurrency-model.md), [ADR-0022](0022-window-tracking-consent-and-sources.md),
  [window tracking](../architecture/window-tracking.md), [M13](../planning/task-breakdown.md#m13--window-interaction)

## Context

M13 feeds visible window surfaces into the existing world and re-projects attached pets between
simulation steps. The current `CompositeWindowTracker` takes a CG snapshot on a 1 s timer and gates
refreshes to at most 2 Hz. Its AX observer watches the frontmost app's focused window and uses AX
notifications only to request that same throttled CG snapshot. AX IPC is synchronous and configured
with a 0.25 s timeout on MainActor. This source cannot support the ≤1 display-frame visual lag in
AC-M13-01. No native drag cadence or query-cost measurement has been captured.

## Problem

Choose the smallest safe update path for the window a pet is riding, while keeping opt-in, Accessibility
trust and D-11's no-CG-only rule. A change must not put potentially blocking AX IPC on the frame path.

## Alternatives

1. **Keep ≤2 Hz snapshots.** Safe with current architecture, but does not satisfy one-frame lag.
2. **Refresh CG snapshots on every AX move event.** Small code change and no new AX query, but still
   scans the whole window list, misses non-focused ridden windows, and has no proven event cadence or
   CPU cost. It cannot alone guarantee the criterion.
3. **Observe the ridden window and deliver coalesced geometry values through a dedicated serialized
   tracking worker.** Query only the attached window, keep AX work off MainActor, and apply the latest
   Sendable geometry between world steps. If notifications are coalesced, use a bounded attached-only
   refresh on that worker. This may satisfy cadence while preserving permission boundaries, but it
   changes ADR-0012's background-work rule and needs a measured prototype, timeout/cancellation design,
   and owner approval before implementation.

## Recommendation

First measure native AX move delivery and CG snapshot cost while dragging a ridden window. Prototype
option 2 only as a bounded diagnostic comparison if it does not introduce additional AX IPC. If events
are not continuous or event-triggered CG scans exceed the CPU budget, approve an ADR-0012 amendment
and prototype option 3. Until then, keep the current safe ≤2 Hz behavior and mark AC-M13-01 unverified.

## Consequences

- Accessibility remains explicitly opt-in and required; no prompt, permission-state change or CG-only
  fallback is introduced.
- The 240 pt/s ride guard and 1.5 s stale-sample guard are safety policy, not a substitute for visual
  latency evidence.
- Manual tests must use the owner's existing opt-in and trust state. No titles, names, content or frame
  histories are needed or allowed.

## Risks

- AX notifications may be coalesced or absent for some apps, and the public API has no AX-window to
  CGWindowID mapping.
- A worker design may still be limited by AX IPC behavior; the configured messaging timeout is not a
  real-time guarantee.
- CPU, event latency and update cadence must be measured on the current OS and hardware before
  accepting the AC.
