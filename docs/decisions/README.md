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
| [0003](0003-overlay-window-strategy.md) | Per-screen transparent overlay panels with dynamic mouse pass-through | Proposed (pending PoC) |
| [0004](0004-spritekit-as-renderer.md) | SpriteKit as renderer only | Superseded by 0015 |
| [0005](0005-kinematic-physics.md) | Custom kinematic physics instead of SpriteKit physics | Proposed |
| [0006](0006-behavior-model.md) | Hierarchical FSM + utility-based activity selection | Proposed |
| [0007](0007-character-packs.md) | Data-driven character packs (JSON + PNG) | Proposed |
| [0008](0008-coordinate-system.md) | Canonical AppKit global coordinate space | Proposed |
| [0009](0009-dock-geometry.md) | Dock geometry from public-API heuristics + manual offset | Proposed (pending PoC E3) |
| [0010](0010-distribution-no-sandbox.md) | Developer ID distribution, Hardened Runtime, no App Sandbox | Proposed |
| [0011](0011-tooling-and-dependencies.md) | No third-party dependencies; Swift Testing; bundled swift-format | Proposed |
| [0012](0012-concurrency-model.md) | Concurrency model: MainActor engine, Sendable values | Proposed |
| [0013](0013-simulation-loop.md) | Fixed-timestep simulation driven by the display frame | Proposed (driver amended by 0015) |
| [0014](0014-ai-agent-instructions.md) | AGENTS.md as the single source of agent instructions | Proposed |
| [0015](0015-core-animation-renderer.md) | Core Animation renderer (supersedes 0004) | Accepted |

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
