# ADR-0018: Hierarchical execution with simple weighted action selection for M9

- Status: **Accepted** (owner planning approval, 2026-10-18; supersedes ADR-0006).
  M9 Core implementation and deterministic behavior validation added 2026-10-18 after explicit owner reauthorization; Runtime/Settings verification follows the implementation plan.
- Date: 2026-10-18
- Related: [ADR-0006](0006-behavior-model.md), [ADR-0016](0016-physics-state-and-recovery.md),
  [ADR-0017](0017-simulation-driven-jumps.md), [Behavior Engine](../architecture/behavior-engine.md).

## Context

ADR-0006 is Proposed and describes utility scoring with needs, top-k and novelty factors. D10
narrows the first M9 design to HSM execution and simple weighted choices. Current code already has
SeededRandomSource and state transitions, but no activity selector or live personality/needs.

## Problem

Prepare an autonomous behavior seam without implementing M9 or introducing utility-AI complexity.

## Alternatives

1. Full Behavior Trees — excessive execution machinery for this app.
2. Utility scoring/top-k/need curves from ADR-0006 — premature tuning and hidden interactions.
3. **Explicit HSM execution + availability/cooldown-filtered weighted random action choice.**

## Decision

Propose option 3 for M9. Choose only at decision boundaries using injected RandomSource and stable
candidate order. Invalid/nonfinite/negative weights are unavailable; zero total chooses Idle.
HSM emits typed activity/movement requests, never positions. Physics computes movement, world
commits, animation presents. Cooldowns and duration bounds use simulated time. Environment values
are read-only inputs; Runtime owns platform I/O, run permission and clock. Keep personality/energy
as future inputs, not newly serialized fields or placeholder code now.

## Rationale

This applies D10 while retaining ADR-0006's useful separation of choosing and executing actions.
Simpler weights and explicit guards make seeded tests and tuning easier to explain.

## Consequences and limitations

Owner approval on 2026-10-18 supersedes ADR-0006 in the index and its status; preserve its
original decision content for history. Future actions: Walk, Idle, Jump, Sit, Sleep, WakeUp, Observe, Explore.
The initial preparation added no runtime model. Subsequent M9 implementation adds Needs/Personality,
ActivitySelector and the same HSM execution; Settings/login integration is part of the current
[implementation plan](../planning/m9-implementation.md).
Energy is a future dynamic need; curiosity/playfulness/laziness are future traits. Existing manifest
personality DTO remains intact, including sociability; no new field contract approved here.

## Risks

Repetitive behavior → cooldowns, owner playtests, simple optional repeat cap in later M9 design;
random drift → seeded stable candidates; decision polling → boundary-only selection;
unsafe action → HSM/physics validate eligibility again at execution. Validate each in M9 tests.
