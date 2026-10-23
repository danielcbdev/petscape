# Architecture Decision Records

ADRs capture decisions that are expensive to reverse. Each has: Context, Problem, Alternatives,
Decision, Rationale, Consequences, Risks.

## Status values

`Proposed` → `Accepted` (owner approval) → optionally `Superseded by ADR-NNNN` or `Deprecated`.
ADRs marked *pending PoC* are confirmed or revised with the PoC results
([proof-of-concept.md](../planning/proof-of-concept.md)).

## Index

| ADR | Title | Status |
|---|---|---|
| [0001](0001-platform-baseline.md) | Platform baseline: macOS 14+, Swift 6, Apple silicon first | Proposed |
| [0002](0002-project-structure.md) | Xcode app shell + local Swift package with four modules | Proposed |
| [0003](0003-overlay-window-strategy.md) | Per-screen transparent overlay panels with dynamic mouse pass-through | Accepted (PoC-confirmed; level Dock − 1, full-screen rule) |
| [0004](0004-spritekit-as-renderer.md) | SpriteKit as renderer only | Superseded by 0015 |
| [0005](0005-kinematic-physics.md) | Custom kinematic physics instead of SpriteKit physics | Proposed |
| [0006](0006-behavior-model.md) | Hierarchical FSM + utility-based activity selection | Superseded by 0018 (2026-10-18) |
| [0007](0007-character-packs.md) | Data-driven character packs (JSON + PNG) | Proposed |
| [0008](0008-coordinate-system.md) | Canonical AppKit global coordinate space | Proposed |
| [0009](0009-dock-geometry.md) | Dock geometry from public-API heuristics + manual offset | Accepted (PoC-confirmed) |
| [0010](0010-distribution-no-sandbox.md) | Developer ID distribution, Hardened Runtime, no App Sandbox | Proposed |
| [0011](0011-tooling-and-dependencies.md) | No third-party dependencies; Swift Testing; bundled swift-format | Proposed |
| [0012](0012-concurrency-model.md) | Concurrency model: MainActor engine, Sendable values | Proposed |
| [0013](0013-simulation-loop.md) | Fixed-timestep simulation driven by the display frame | Proposed (driver amended by 0015) |
| [0014](0014-ai-agent-instructions.md) | AGENTS.md as the single source of agent instructions | Proposed |
| [0015](0015-core-animation-renderer.md) | Core Animation renderer (supersedes 0004) | Accepted |

## 2026-10-18 planning additions (design accepted; runtime unvalidated)

| ADR | Title | Status |
|---|---|---|
| [0016](0016-physics-state-and-recovery.md) | Single-owner kinematics, fixed steps and bounded recovery (D1–D9) | Accepted (2026-10-18); retain 0015, incompatible literal SpriteKit clause resolved by approval |
| [0017](0017-simulation-driven-jumps.md) | Simulation-timed jump phases and animation presentation (D7/D8) | Accepted (2026-10-18); replaces older planned frame-triggered takeoff |
| [0018](0018-simple-weighted-behaviors.md) | HSM with simple weighted M9 selection (D10) | Accepted (2026-10-18); supersedes 0006 |

Original ADR IDs/decision text are preserved; 0006 status now records its successor. The owner
approved the completed planning on 2026-10-18, including the renderer wording correction. Runtime
behavior remains unvalidated until implemented/tested. D1–D10 compatibility and original blocked
renderer wording are recorded in [technical review](../planning/m7-m8-technical-review.md).

## Template

```markdown
# ADR-NNNN: Title

- Status: Proposed | Accepted | Superseded by ADR-XXXX
- Date: YYYY-MM-DD
- Related: links

## Context
## Problem
## Alternatives
## Decision
## Rationale
## Consequences
## Risks
```

Rules: never edit the decision of an Accepted ADR in place; write a new ADR that supersedes it.
Typos and links may be fixed.

## M10 planning additions (2026-10-18, all Proposed)

| ADR | Title | Status |
|---|---|---|
| [0019](0019-cursor-observation.md) | Shared cursor sampling with event-driven routing | Accepted by owner authorization; native delivery validation pending |
| [0020](0020-selective-input-and-focus.md) | Bounded selective input, alpha hit testing and nonactivation | Proposed; would amend 0003 only after native comparison/owner approval |
| [0021](0021-interaction-authority-and-recovery.md) | World-owned pickup, priorities, release/recovery and V5 presentation | Accepted by owner authorization; native validation pending |
| [0022](0022-window-tracking-consent-and-sources.md) | Window tracking source and permission boundary | Accepted by explicit owner decision (2026-10-22); native validation incomplete |

No accepted ADR decision text was changed. Production architecture remains governed by existing
accepted records; native behavior and M10 implementation are not claimed by these proposals.
