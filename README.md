# PetScape

A native macOS app that turns your desktop into a place where small, expressive, autonomous pets
live — walking on the Dock, climbing screen edges, hopping between windows, napping and playing —
without ever getting in the way of your work.

> **Status:** MVP (v0.1.0) in review: a menu bar app with one cat walking on top of the Dock. Not yet
> released; build it from source (below). Physics, jumps, behaviors and window interaction come later
> ([roadmap](docs/product/roadmap.md)).

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

## Usage (v0.1.0)

Build and launch from a clone (Xcode 26+ installed):

```bash
make run
```

- PetScape lives in the menu bar (paw icon); it has no Dock icon and no window.
- A cat walks back and forth on top of the Dock and turns around at the screen edges. Clicks anywhere except
  on the cat's own pixels go to whatever is underneath; clicking the cat never takes focus.
- **Hide Pet / Show Pet** removes or restores the cat; **Pause / Resume** freezes it in place. Both choices are
  remembered after relaunch. **Quit PetScape** (⌘Q) exits.
- With the Dock set to hide automatically, or placed on the left or right, the cat walks on the bottom edge of
  the screen instead. It follows Dock size and position changes and display changes within about a second.
- The cat disappears while a full-screen app is in front, and nothing is drawn while the Mac sleeps, the
  screen is locked or the display is off.
- No permissions are requested; nothing is sent over the network.
- If the paws float above or sink into the Dock on your Mac, Debug builds have **Debug › Dock offset** to shift
  the cat up or down (−40…+40 pt); a Settings window follows in a later version.

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
