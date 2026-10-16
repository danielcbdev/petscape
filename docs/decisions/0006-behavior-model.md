# ADR-0006: Hierarchical FSM for execution + utility-based activity selection

- Status: Proposed
- Date: 2026-10-16
- Related: [behavior-engine.md](../architecture/behavior-engine.md), [state-machines.md](../specifications/state-machines.md)

## Context

Pets must act autonomously based on state, environment, energy, curiosity, personality, events and
time, be interruptible (drag, surface lost), and be deterministic in tests. LLM control is forbidden.

## Problem

Choose the behavior model.

## Alternatives

Flat FSM; hierarchical FSM; behavior trees; utility AI; GameplayKit (`GKStateMachine`,
`GKRuleSystem`); combinations.

## Decision

Two layers: a **hierarchical FSM** executes activities (each state = clip + motion mode + interrupt
threshold), and a **utility-based `ActivitySelector`** chooses the next activity using needs,
personality, availability, cooldowns and novelty, with weighted randomness from an injected
`RandomSource`. The MVP uses only a two-state FSM (`walking`, `turning`). GameplayKit is not used
(class-based, not `Sendable`, couples domain to a game framework).

## Rationale

The HSM makes "what is the pet doing" explicit, maps 1:1 to animations, and handles global
interrupts at parent states. Utility scoring expresses personality naturally ("a tired, lazy cat
prefers sleeping") without a large tree. Behavior trees add machinery not needed for ~15 states.

## Consequences

- Tuning lives in data (`BehaviorTuning`), adjusted by playtesting.
- Each transition has a unit test; scenarios run with seeded randomness.

## Risks

| Risk | Mitigation |
|---|---|
| HSM grows unwieldy | Parent-level handlers; state catalogue reviewed per milestone |
| Behavior feels repetitive or random | Novelty factor, cooldowns, playtest notes in M9 |
