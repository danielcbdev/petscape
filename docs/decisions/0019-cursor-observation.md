# ADR-0019: Shared cursor sampling with event-driven routing

- Status: **Accepted by explicit owner authorization (2026-10-18); native event-delivery validation remains open**
- Date: 2026-10-18
- Related: [ADR-0013](0013-simulation-loop.md), [ADR-0015](0015-core-animation-renderer.md),
  [interaction architecture](../architecture/interaction-system.md),
  [contract](../specifications/interaction.md)

## Context

CursorSampler already reads NSEvent.mouseLocation/buttons once per existing display frame and
observes global mouseMoved when visible without frames. M9 sleep can request 4 Hz; using only
that cadence for acquisition creates long routing gaps. Global monitoring excludes our own app.

## Problem

Observe proximity without another scheduler, while preserving prompt mouse routing and keeping
paused/hidden/suspended simulation stopped.

## Alternatives

1. Poll cursor at 60 Hz with a timer: independent wakeups and duplicated clock.
2. Use frame samples only: minimal, but sleep/held idle can miss quick cursor crossings.
3. Use only global mouse events: misses local events and stationary cursor under a moving cat.
4. Share existing frame reads plus mouse-only local/global movement callbacks for direct routing.

## Decision

Adopt option 4. Extend existing CursorSampler and its injected monitor seam, retain immediate
routing updates and existing per-frame re-hit-testing. Use 10 Hz active/2 Hz pet-sleeping behavioral
interpretation from existing time/sample inputs, zero behavioral work in inactive RunState.
Local movement observer returns original events unmodified; down/drag/up remain native responder
input. Pressed/held uses 60 Hz existing driver for button recovery and simulation; no polling timer.
Read primary-button bit separately from any-button state. Remove tokens/caches on teardown or
unavailability. Monitor failure disables direct acquisition, without requesting permissions.

## Rationale

This reuses established seams and separates behavior cadence from event routing latency. Pointer
location and mouse-only monitoring have existing permission-free project evidence; Apple's API
semantics distinguish key-event privilege and local/global coverage. Sources are linked in the
architecture document; native delivery on target systems remains a PoC obligation.

## Consequences

Add local monitor lifecycle tests and primary-button metadata with source-compatible initializer
defaults. No cursor history persistence or key masks. No permission flow, CGEventTap, event
suppression/reposting or new scheduler. Event traffic may still be high; cache only latest sample,
no formatting/allocation per sample after warmup. Paused visible legacy routing never steps world.

## Risks

Global events arrive asynchronously; callback-to-toggle time is not crossing-to-toggle time.
Queued ordering, high-rate devices, monitor refusal and sleeping-cat acquisition need native tests.
If permission-free delivery fails, preserve passive awareness/fallback and revise design; do not
request Input Monitoring/Accessibility as an automatic repair.
