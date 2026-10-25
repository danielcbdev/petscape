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
| | [physics-engine.md](architecture/physics-engine.md) | M7 kinematic model/contact/recovery; links to M8 |
| | [jump-system.md](architecture/jump-system.md) | M8 solver, phase/target/interruption contracts |
| | [behavior-engine.md](architecture/behavior-engine.md) | M9 needs, HSM execution + simple weighted selection |
| | [macos-integration.md](architecture/macos-integration.md) | Overlay windows, click-through, Spaces, system events |
| | [interaction-system.md](architecture/interaction-system.md) | Proposed M10: inspected code map, cursor APIs, routing/focus architecture |
| | [window-tracking.md](architecture/window-tracking.md) | Other apps' windows (M12+) |
| Specifications | [asset-format.md](specifications/asset-format.md) | Image rules, pack layout, **asset audit** |
| | [animation-assets-v4.md](specifications/animation-assets-v4.md) | V4 clip briefs, QA, compatibility and production pipeline |
| | [animation-assets-v5.md](specifications/animation-assets-v5.md) | Proposed V5 minimum clips, art QA/fallback/pipeline |
| | [interaction.md](specifications/interaction.md) | Proposed M10 tuning, commands, gesture/state/lifecycle/release/settings contracts |
| | [animation-schema.md](specifications/animation-schema.md) | `character.json` schema v1, validation |
| | [state-machines.md](specifications/state-machines.md) | States, events, priorities, transitions |
| | [coordinate-system.md](specifications/coordinate-system.md) | Canonical space and conversions |
| | [surface-detection.md](specifications/surface-detection.md) | Surfaces, Dock estimation |
| | [permissions.md](specifications/permissions.md) | Permission matrix and flows |
| | [performance.md](specifications/performance.md) | Targets, protocol, measurements |
| Planning | [implementation-plan.md](planning/implementation-plan.md) | Strategy, sequencing, working agreement |
| | [m7-m8-technical-review.md](planning/m7-m8-technical-review.md) | Inspected baseline, D1–D10 compatibility, divergences and approval boundary |
| | [m10-implementation.md](planning/m10-implementation.md) | Proposed M10 tasks, contracts, baseline verification, acceptance/risk/regression matrix |
| | [m10-native-poc.md](planning/m10-native-poc.md) | Planned M10 isolated native routing experiments and go/no-go criteria |
| | [m5-m6-closeout.md](planning/m5-m6-closeout.md) | Separate MVP evidence/decision closeout and ≥20-point AC-14 procedure |
| | [milestones.md](planning/milestones.md) | Milestones M0–M21 and **status** |
| | [task-breakdown.md](planning/task-breakdown.md) | Tasks T0.1… |
| | [acceptance-criteria.md](planning/acceptance-criteria.md) | Verifiable criteria per milestone |
| | [proof-of-concept.md](planning/proof-of-concept.md) | PoC experiments and results |
| | [risks.md](planning/risks.md) | Risk register, open decisions, questions to validate |
| Decisions | [decisions/README.md](decisions/README.md) | ADR index and template |
| Development | [setup.md](development/setup.md) | Toolchain, project settings, commands |
| | [conventions.md](development/conventions.md) | Code style and rules |
| | [testing.md](development/testing.md) | Test strategy, manual matrix |
| | [debugging.md](development/debugging.md) | Logging, debug overlays, profiling |
| | [release.md](development/release.md) | Universal DMG/ZIP, ad-hoc signatures, checksums, release exception and publication |
| | [install.md](development/install.md) | English/pt-BR installation, upgrades and Gatekeeper guidance |
