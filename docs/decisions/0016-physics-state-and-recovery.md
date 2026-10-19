# ADR-0016: Single-owner kinematics, fixed steps and bounded recovery

- Status: **Accepted** (owner planning approval, 2026-10-18). Literal D4 wording was blocked
  during planning; owner approved the documented correction to retain Core Animation. Acceptance
  of design is not runtime validation. M7/M8 engineering is now implemented and In review;
  complete manual/performance acceptance remains open.
- Date: 2026-10-18
- Related: [ADR-0005](0005-kinematic-physics.md), [ADR-0008](0008-coordinate-system.md),
  [ADR-0009](0009-dock-geometry.md), [ADR-0012](0012-concurrency-model.md),
  [ADR-0013](0013-simulation-loop.md), [ADR-0015](0015-core-animation-renderer.md)
- Specifies: [Physics Engine](../architecture/physics-engine.md); evidence in
  [technical review](../planning/m7-m8-technical-review.md).

## Context

HEAD 2f7f33f has PetWorld/Pet.position, a fixed accumulator, single CADisplayLink, same-x resettle
and a runtime liveness fix for recovery after side Dock changes. It has no velocity, falling or
coexisting floor under a bottom Dock. The request approves custom kinematics and one source of
position truth (D1/D2), bounded time (D3), detached rendering (D4), swept contact (D5), stable foot
geometry (D6), separate state concerns (D7), simulation-driven animation (D8) and reused recovery
(D9). Its renderer references differ from the accepted ADR-0015 and actual code.

## Problem

Introduce physical flight without two position writers, invisible airborne pets, stopped recovery
frames, unstable contact, new polling, or an architectural renderer reversal.

## Alternatives

1. Separate PhysicsWorld position synchronized back to Pet — duplicates state, rejected by D2.
2. SpriteKit physics/trajectory animations — violates D1, pure Core and deterministic time.
3. **Pure Core candidate stepper, committed by the existing PetWorld**, with explicit contact/work demand.

## Decision

Propose option 3. Keep Pet.position, add velocity; reuse SurfaceAttachment and SurfaceMap.
Physics owns normal displacement computation; PetWorld applies it. Spawn, reprojection and exceptional
safe placement remain explicit mutations inside that same owner, coordinated by Runtime inputs.
Use semi-implicit Euler, swept descending foot crossing with x-at-impact and deterministic ties.
Separate logical dimensions from stable visual screen margin; no schema addition.
Keep accumulator 1/60, max 5 steps, 0.25 s clamp/remainder policy and CADisplayLink. Airborne/timed/
recovering work can require steps even when snapshot is still/hidden; RunStatus always gates it.
Merge floor plus Dock on the hosted screen; ordinary surface loss falls, Dock reappearance does not
lift a floor-attached pet. Keep existing recovery pipeline for invalid numbers, unavailable host and
out-of-bounds; bound retries and wait for notifications when no surface exists. D7/D8 phase detail
is in ADR-0017; D10 in ADR-0018. Full numeric contracts live in Physics Engine, not copied here.

### D4 literal renderer clause — planning incompatibility resolved by owner approval

The request says SpriteKit continues rendering. Actual PetRenderer/PetLayer use QuartzCore and
Makefile rejects SpriteKit imports; ADR-0015 superseded 0004 after PoC measured ~5× resource costs.
**Proposed minimum correction:** retain Core Animation and interpret D4 as renderer-independent
snapshot consumption, preserving its intent. No renderer migration is authorized or planned.
Owner confirmed this interpretation through planning approval on 2026-10-18. ADR-0015 remains
Accepted; the original literal SpriteKit wording is recorded as incompatible, not retroactively
claimed compatible. No renderer migration is included.

## Rationale

The existing ownership and timing boundaries already meet most constraints. Extending them avoids
state synchronization, another scheduler and a repeat of 2f7f33f's recovery liveness defect.

## Consequences and limitations

- Add readable velocity and new enum cases; audit exhaustive callers and test constructors together.
- Tighten world.step dt to bounded steps; migrate large-dt tests to equivalent fixed steps without
  weakening speed assertions. Owner approves the public contract change before implementation.
- Preserve current no-permission/full-width Dock heuristic. Real shelf ends and display-to-display
  flight are unknown/out of scope. Floor builder is Core geometry, not a second Platform observer.
- Missing art cannot block M7; default pose is safe. No performance success assumed until measured.
- Exceptional recovery may reposition after host loss; ordinary lost-support recovery must not respawn.

## Risks

Invisible flight and recovery stalls → explicit state visibility/demand and both-side regression;
tunneling → swept x-at-impact tests; floor-add detachment changes → coexistence fixtures;
per-frame allocations → reused buffers and signposts; numerical failure → finite guards and bounded
recovery. Full risk/test/recovery mapping is in the regression matrix.
