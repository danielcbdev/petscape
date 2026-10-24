# PetScape

A native macOS app that turns your desktop into a place where small, expressive, autonomous pets
live — walking on the Dock, climbing screen edges, hopping between windows, napping and playing —
without ever getting in the way of your work.

> **Status:** M1–M9 accepted by the owner. M9 implementation and Settings UI automation pass; its
> owner closeout records unverified real login, native cadence and installed-app playtest checks.
> Build from source below; no release/tag has been published.
> V4 idle/jump/fall/landing art is integrated ([production notes](assets/characters/cat/v4/README.md)).
> Rest/expression states currently use held idle poses; window interaction comes later
> ([roadmap](docs/product/roadmap.md)).

<p align="center"><img src="assets/characters/cat/walk/walk_preview.gif" width="160" alt="Prototype walk cycle of the cat"></p>

## Highlights

- Menu bar app; transparent overlay; clicks pass through everything that isn't a pet.
- Data-driven animations: swap art by editing a JSON manifest — no code changes.
- Autonomous behavior: hierarchical state machine + weighted activities, energy and rest.
- Energy-conscious: rendering stops completely when paused, hidden or the Mac sleeps.
- 100% native: Swift 6, SwiftUI, AppKit, Core Animation. No third-party dependencies. No network, no telemetry.

## Requirements

- macOS 14 Sonoma or later (Apple silicon primary; Intel best-effort).
- To build: Xcode 26 or later (developed with Xcode 27.1 / Swift 6.4).

## Usage (working tree)

Build and launch from a clone (Xcode 26+ installed):

```bash
make run
```

- PetScape lives in the menu bar (paw icon); it has no Dock icon. **Settings…** opens its native
  preferences window.
- A cat walks on top of the Dock, turns at screen edges and chooses short jumps, idle, rest and
  ambient activities. Clicks anywhere except
  on the cat's own pixels go to whatever is underneath; clicking the cat never takes focus.
- **Hide Pet / Show Pet** removes or restores the cat; **Pause / Resume** freezes it in place. Both choices are
  remembered after relaunch. **Quit PetScape** (⌘Q) exits.
- With the Dock set to hide automatically, or placed on the left or right, the cat walks on the bottom edge of
  the screen instead. It follows Dock size and position changes and display changes within about a second.
- The cat disappears while a full-screen app is in front, and nothing is drawn while the Mac sleeps, the
  screen is locked or the display is off.
- Overlay and manual dance need no special permission. Window interaction asks for Accessibility only after opt-in. Optional music detection asks for system audio access on macOS 14.2+; audio is analyzed locally, never saved or sent. No Screen Recording or microphone permission is requested. See [permissions](docs/specifications/permissions.md).
- In **Settings…**, change pet size/speed and enable or disable autonomous activities, jumping, resting
  and expressions. Changes apply immediately and persist. **Wake Pet** exits sleep; **Restore Defaults**
  resets PetScape choices and disables its login item.
- If the paws float above or sink into the Dock, use **Settings › Advanced › Dock offset** (−40…+40 pt).
- **Launch at login** changes only when explicitly toggled. Its status reflects macOS; approval, when
  needed, is managed in System Settings › General › Login Items.

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
