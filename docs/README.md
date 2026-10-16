# Documentation Index

Each topic has exactly one owning document; others link to it.

| Area | Document | Owns |
|---|---|---|
| Product | [vision.md](product/vision.md) | Why, principles, visual identity |
| | [requirements.md](product/requirements.md) | FR/NFR IDs, constraints |
| | [scope.md](product/scope.md) | MVP in/out, assumptions |
| | [roadmap.md](product/roadmap.md) | Releases, art dependencies |
| Architecture | [overview.md](architecture/overview.md) | System shape, layering, decision summary |
| | [modules.md](architecture/modules.md) | Repo layout, modules, dependencies |
| | [data-flow.md](architecture/data-flow.md) | Frame pipeline, events, run state, persistence |
| | [animation-system.md](architecture/animation-system.md) | Playback model, loading, caching, memory |
| | [pet-engine.md](architecture/pet-engine.md) | World/pet model, step order, lifecycle |
| | [physics-engine.md](architecture/physics-engine.md) | Kinematic motion, landing, jumps |
| | [behavior-engine.md](architecture/behavior-engine.md) | HSM + utility selection |
| | [macos-integration.md](architecture/macos-integration.md) | Overlay windows, click-through, Spaces, system events |
| | [window-tracking.md](architecture/window-tracking.md) | Other apps' windows (M12+) |
| Specifications | [asset-format.md](specifications/asset-format.md) | Image rules, pack layout, **asset audit** |
| | [animation-schema.md](specifications/animation-schema.md) | `character.json` schema v1, validation |
| | [state-machines.md](specifications/state-machines.md) | States, events, priorities, transitions |
| | [coordinate-system.md](specifications/coordinate-system.md) | Canonical space and conversions |
| | [surface-detection.md](specifications/surface-detection.md) | Surfaces, Dock estimation |
| | [permissions.md](specifications/permissions.md) | Permission matrix and flows |
| | [performance.md](specifications/performance.md) | Targets, protocol, measurements |
| Planning | [implementation-plan.md](planning/implementation-plan.md) | Strategy, sequencing, working agreement |
| | [milestones.md](planning/milestones.md) | Milestones M0–M15 and **status** |
| | [task-breakdown.md](planning/task-breakdown.md) | Tasks T0.1… |
| | [acceptance-criteria.md](planning/acceptance-criteria.md) | Verifiable criteria per milestone |
| | [proof-of-concept.md](planning/proof-of-concept.md) | PoC experiments and results |
| | [risks.md](planning/risks.md) | Risk register, open decisions, questions to validate |
| Decisions | [decisions/README.md](decisions/README.md) | ADR index and template |
| Development | [setup.md](development/setup.md) | Toolchain, project settings, commands |
| | [conventions.md](development/conventions.md) | Code style and rules |
| | [testing.md](development/testing.md) | Test strategy, manual matrix |
| | [debugging.md](development/debugging.md) | Logging, debug overlays, profiling |
| | [release.md](development/release.md) | Versioning, signing, notarization, CI/CD plan |
