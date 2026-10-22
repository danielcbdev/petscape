# ADR-0021: World-owned pickup, deterministic release and interaction recovery

- Status: **Accepted by explicit owner authorization (2026-10-18); implementation and automated coverage complete, native validation remains open**
- Date: 2026-10-18
- Related: [ADR-0016](0016-physics-state-and-recovery.md),
  [ADR-0017](0017-simulation-driven-jumps.md), [ADR-0018](0018-simple-weighted-behaviors.md),
  [interaction contract](../specifications/interaction.md),
  [V5](../specifications/animation-assets-v5.md)

## Context

PetWorld is the sole Pet.position writer and existing HSM executes M9 activities. PhysicsStepper
computes body candidates; animation is presentation. Current pass-through dragging means input
capture only. Historical M10 prose requires throwing and suggests dragging while paused; the
current owner brief prioritizes predictable pickup/drop and defers throwing.

## Problem

Transfer motion authority, cancel safely and resume autonomy without competing machines,
residual launch velocities, animation-dependent physics or stuck mouse capture.

## Alternatives

1. Runtime changes layer position then synchronizes body: two sources of truth, rejected.
2. Independent drag physics/behavior service: duplicates world and recovery, rejected.
3. Typed session commands into existing PetWorld, one held phase, existing release gravity.

## Decision

Adopt option 3. Runtime InteractionController targets and reduces gestures; a press reservation
freezes the underlying pet until up/4 pt drag threshold. It stores remaining activity time, not
another body copy. Valid beginHold cancels activity/jump once, detaches support and enters held.
World clamps/commits pointer-minus-down-offset in global points; physics does not also integrate.
Release atomically consumes final target, sets zero velocity and enters existing falling. Contact,
landing timer, watchdog and exceptional recovery remain M7/M8. No fling estimator in initial M10.

Order operational guards before numeric art priorities: critical validity/host checks, RunState
permission/cancel, valid active drag, click, eligible cursor attention, autonomy. Cursor cannot
interrupt sleep/transitions/flight. Click may explicitly wake; pickup may interrupt a valid visible
pet. Keep existing weighted selector; return eligible saved activity after observation, and bounded
Idle/ordinary choice after pickup landing. No random sampling per input callback.

Cancel before hide/pause/suspend/Space/screen/panel replacement/settings/pet teardown. Session IDs
reject stale callbacks, duplicate up/cancel is harmless. Primary-button sampling on the existing
60 Hz pressed/held driver recovers lost up. Cancellation while stopped releases ownership but
never steps time; resume reconciles geometry and seeds accumulator. No-frame lifecycle callbacks
must also cancel immediately. Primary held forever is intentional unless availability is lost.

Three optional V5 semantic clips curious/picked-up/held use schema v1 and stable virtual foot
anchor. Missing clips hold idle/default pose; art never sets position, completes hold or starts
gravity. Existing fall/landing serve release. Preserve all originals and leave V5 production
separately authorized. No schema migration, SKAction or CAAnimation domain clock.

## Rationale

This extends the existing ownership, HSM and recovery model, makes authority boundaries testable
and works without art or privileges. Safe release is independent of input event density and FPS.

## Consequences

Add command/event/session values, held + reaction cases and exhaustive visibility/demand/log
updates. Public enum additions affect downstream switches; preference v3 is a separate tested
additive migration. M10 stays single-host; outside-host pointer clamps rather than migrating pets.
Update historical T10.4/AC-M10-01 scope notes, preserving IDs and deferred throwing requirement.

## Risks

Held omitted from validity/visibility/demand checks; stale commands after pet replacement; lost up
while frames stop; a restored absolute activity deadline causing immediate reselection; applying
queued movement after release; art fallback preventing simulation work. Each has explicit
unit/integration/manual tests in the task plan. New capture topology still depends on ADR-0020 PoC.
