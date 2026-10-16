# PetScape

A native macOS app that turns your desktop into a place where small, expressive, autonomous pets
live — walking on the Dock, climbing screen edges, hopping between windows, napping and playing —
without ever getting in the way of your work.

> **Status:** planning complete, awaiting approval to start implementation (proof of concept first).
> There is no runnable app yet.

<p align="center"><img src="assets/characters/cat/walk/walk_preview.gif" width="160" alt="Prototype walk cycle of the cat"></p>

## Highlights (planned)

- Menu bar app; transparent overlay; clicks pass through everything that isn't a pet.
- Data-driven animations: swap art by editing a JSON manifest — no code changes.
- Believable behavior: hierarchical state machine + utility-based activity selection.
- Energy-conscious: rendering stops completely when paused, hidden or the Mac sleeps.
- 100% native: Swift 6, SwiftUI, AppKit, Core Animation. No third-party dependencies. No network, no telemetry.

## Requirements

- macOS 14 Sonoma or later (Apple silicon primary; Intel best-effort).
- To build: Xcode 26 or later (developed with Xcode 27.1 / Swift 6.4).

## Documentation

| Topic | Link |
|---|---|
| Vision, requirements, scope, roadmap | [docs/product/](docs/product/vision.md) |
| Architecture | [docs/architecture/overview.md](docs/architecture/overview.md) |
| Specifications (assets, schema, coordinates, permissions, performance) | [docs/specifications/](docs/specifications/animation-schema.md) |
| Decisions (ADRs) | [docs/decisions/](docs/decisions/README.md) |
| Plan, milestones, tasks, acceptance criteria | [docs/planning/](docs/planning/implementation-plan.md) |
| Development setup, conventions, testing, debugging, release | [docs/development/](docs/development/setup.md) |
| Full index | [docs/README.md](docs/README.md) |

## Working with AI agents

[AGENTS.md](AGENTS.md) is the canonical instruction file for Codex, Claude Code and Cursor;
[CLAUDE.md](CLAUDE.md), [CODEX.md](CODEX.md) and `.cursor/rules/` add tool-specific details.

## License

Source code: [MIT](LICENSE). The license for the character art is still to be decided (open
decision D-08 in [risks.md](docs/planning/risks.md)); until then the art is not covered by the MIT
license.
