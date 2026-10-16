# ADR-0005: Custom kinematic physics instead of SpriteKit physics

- Status: Proposed
- Date: 2026-10-16
- Related: [physics-engine.md](../architecture/physics-engine.md)

## Context

Pets walk along, fall onto, jump between and climb surfaces that come from outside the app (Dock,
screen edges, other apps' windows), which move or disappear at any time and span several overlay
windows/screens.

## Problem

Use SpriteKit's physics engine or a custom controller?

## Alternatives

1. `SKPhysicsBody` with edge bodies for surfaces.
2. A third-party physics engine (e.g. Box2D bindings).
3. **A small custom kinematic controller in Core** (attachment along segments, gravity, swept
   landing, jump solver).

## Decision

Option 3. No rigid-body simulation; motion modes are `attached`, `airborne`, `climbing`, `dragged`.

## Rationale

SpriteKit physics bodies live in one scene and cannot follow a pet between overlays; external
surfaces would need re-creation every frame; walking along and climbing surfaces fights a rigid-body
solver; its variable step and scene dependency prevent deterministic unit tests. The custom
controller needed is small (hundreds of lines), fully testable, and models exactly the "platformer"
semantics desired. A third-party engine violates ADR-0011 for no gain.

## Consequences

- We own tuning (gravity, jump arcs) — values live in `PhysicsTuning`.
- No realistic collisions between pets; future pet interactions are behavioral, not physical.

## Risks

| Risk | Mitigation |
|---|---|
| Scope creep into a general physics engine | Motion modes fixed by this ADR; new modes need an ADR update |
| Tunneling at high speeds | Swept crossing test; terminal velocity clamp; tests |
