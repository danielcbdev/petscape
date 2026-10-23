# ADR-0022: Window tracking source and permission boundary

- Status: **Accepted by explicit owner decision (2026-10-22); native validation incomplete**
- Date: 2026-10-22
- Related: [ADR-0008](0008-coordinate-system.md), [ADR-0012](0012-concurrency-model.md),
  [window-tracking contract](../architecture/window-tracking.md), [D-11](../planning/risks.md)

## Context

M12 needs current geometry and z-order to build window-top surfaces. CGWindowList provides
front-to-back geometry snapshots; AX can notify about application/window changes but has no public
AX-element-to-CGWindowID mapping. CGWindowList enumeration cost, metadata availability on this OS
without Screen Recording, and AX move cadence during real drags have not been measured. Accessibility
is an explicit opt-in and no AX work may begin before it is enabled and trusted.

## Problem

Choose whether geometry-only CGWindowList tracking should operate when Accessibility is not granted,
and define a safe implementation path without introducing a surprise permission or privacy exposure.

## Alternatives

1. **Accessibility required (recommended):** toggle stays enabled only as an explicit pending
   preference until the user grants Accessibility; without trust, tracking remains stopped. Once
   trusted, combine CG snapshots with narrowly scoped AX observation and timeouts.
2. **Degraded CG-only mode:** after explicit feature opt-in, use only required geometry/PID/layer/
   alpha/window-ID fields from throttled snapshots, with no AX calls or additional permission.
   Movement response is limited by refresh cadence; performance and cross-version field behavior
   remain unmeasured.
3. **No tracking until trusted and no degraded mode:** same runtime behavior as option 1, with UI
   explaining that Accessibility is required.

Options 1 and 3 differ in product wording/permission semantics, not data source. The owner must select
whether to offer option 2 and whether explicit feature intent may be retained while permission is
pending.

## Decision

The owner chose **no CG-only degraded mode** on 2026-10-22. Require user opt-in followed by an explicit
confirmation before opening Privacy & Security › Accessibility. Keep all tracking stopped until
trusted. After trust, use required geometry metadata only, AX notifications as invalidation signals,
and bounded/coalesced snapshots. Do not rely on names, titles, window content, ScreenCaptureKit or
private APIs.

## Rationale

The degraded mode may be useful, but its movement lag, refresh cost, cross-version metadata behavior
and usability have not been observed. The owner decision resolves the product choice without claiming
those measurements. Using documented required geometry fields avoids depending on optional,
privacy-sensitive names.

## Consequences

- `TrackedWindow` and `WindowSurfaceBuilder` remain pure Core values/logic.
- Platform owns all CG/AX types and lifecycle.
- Permission checks happen only after explicit opt-in; the informational system prompt is only invoked
  after the user confirms opening Settings.
- Manual native tests and ≤1% idle CPU evidence remain required before M12 can close.

## Risks

AX calls are synchronous IPC and a timeout does not establish UI responsiveness. This proposal does not
authorize a new worker-thread/queue/unsafe isolation model; any such design requires a separate ADR
update. AX notifications may be coalesced, and PID/frame matching may be ambiguous.
