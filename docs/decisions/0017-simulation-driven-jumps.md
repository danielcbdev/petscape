# ADR-0017: Simulation-timed jump phases and animation presentation

- Status: **Accepted** (owner planning approval, 2026-10-18; engineering implemented/In review; visual calibration and full acceptance pending).
- Date: 2026-10-18
- Related: [ADR-0005](0005-kinematic-physics.md), [ADR-0007](0007-character-packs.md),
  [ADR-0013](0013-simulation-loop.md), [ADR-0016](0016-physics-state-and-recovery.md)
- Specifies: [Jump System](../architecture/jump-system.md),
  [Assets V4](../specifications/animation-assets-v4.md).

## Context

Older plans T8.4, AC-M8-02 and schema prose said an art-frame takeoff applies velocity. No consumer
implements that at HEAD. D8 now requires trajectories independent of frame counts. PetState is an
existing flat enum and RunState is separate. CharacterDefinition already resolves variable frames,
fallbacks and semantic clip requests.

## Problem

Represent preparation/ascent/descent/contact/settle, including walk/idle return, without a second
machine, asset-controlled physics, stale targets or missing-art deadlocks.

## Alternatives

1. Frame-event-driven impulse — rejected by D8 and art-independent M7/M8 safety.
2. Fully separate activity and locomotion FSM frameworks — unnecessary duplicated machinery now.
3. **Refine PetState into grounded/airborne cases and simulation timers**, saving return intent.

## Decision

Propose option 3. Runtime operational state stays independent; Core HSM handles locomotion and
bounded phase timers, while a stored return intent distinguishes walking and idle. JumpSolver
returns a bounded plan verified through the exact M7 stepper/sweep. Preparation deadline consumes
the plan once and applies impulse; velocity sign emits apex; physical sweep emits contact; Landing
ends by simulation duration. Frame events are optional presentation observations, never force inputs.
No automatic `next` phase chaining. Reuse existing animation priority/interrupt/fallback mechanisms;
critical phase entry requests cannot be blocked by authored noninterruptibility.

Canonical new requests are `idle`, `jump-start`, `jump`, `fall`, `landing`; support legacy
`jump-air`/`land` on resolution. The requested label `jump_start` is normalized in documentation
only because v1 identifiers exclude underscores. No original rename, schema/manifest edit now.
These semantics supersede the **planned** art-triggered takeoff/animation-finished landing in the
older task/state prose; the old criterion's ID is retained with revision history.

## Rationale

Simulation time can be deterministic across missing or different art and suspension. One-shot
request IDs, captured geometry and saved return intent prevent duplicate launches or state oscillation.
The same physics solver/collision result defines both planning and execution tolerance.

## Consequences and limitations

New public world input/event cases require exhaustive caller updates in M8. No M9 selector,
window target, climbing or external dependency. Timings and numerical envelope are provisional;
owner must calibrate art and trajectories visually. Art may be cut/held to fit physical phases;
authors must review short flights, both facings and clips with different counts. v1 JSON event
structure stays compatible because there is no implemented physics consumer to migrate.

## Risks

Analytic/discrete disagreement → replay bounded solver through M7; lost target → cancel plan and
continue physical fall; animation refusal → critical entry requests; held fallback stopping frames
→ simulation work demand; stuck preparation/landing → finite simulation timers. No measurement or
owner visual approval has been claimed by writing this ADR.
