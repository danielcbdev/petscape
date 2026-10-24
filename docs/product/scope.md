# Scope

## MVP (release v0.1.0)

The MVP proves the hardest platform assumptions (transparent overlay, click-through, Dock placement,
energy cost) with one cat walking back and forth on the Dock.

**In scope:** FR-01 to FR-18 in [requirements.md](requirements.md).

| User-visible capability | Requirement IDs |
|---|---|
| Menu bar app with Show/Hide, Pause/Resume, Quit | FR-01, FR-02, FR-11, FR-12, FR-13, FR-18 |
| Transparent click-through overlay | FR-03, FR-14 |
| Cat rendered with data-driven walk animation | FR-04, FR-05, FR-06, FR-15 |
| Autonomous horizontal walk with turnaround | FR-07, FR-08, FR-09 |
| Placement on the bottom Dock with fallbacks | FR-10, FR-17 |
| No permissions needed | FR-16 |

**Explicitly out of scope for the MVP:**

- Physics beyond constant-speed horizontal walking (no gravity, jumps, falls).
- Climbing, window detection, window interaction.
- Multiple pets, pet-to-pet interaction, character selection.
- Cursor reactions and dragging (the PoC validates that interaction is *possible*; the MVP does not ship it).
- Fullscreen app spaces (the overlay does not appear over fullscreen apps).
- Settings window (the menu is the only UI). Size/speed settings come in M9.
- Launch at login.
- Signed/notarized distribution (M20). MVP builds run locally from Xcode.
- Dock on left/right edges as a surface (fallback to the screen bottom is in scope).
- Multi-display behavior beyond "the pet lives on the display that has the Dock".

## Assumptions

| # | Assumption | Validation |
|---|---|---|
| A1 | A borderless, non-activating, transparent window above the Dock level can host per-pixel transparent content (validated with SpriteKit and Core Animation). | PoC E1 ✅ |
| A2 | Click-through can be achieved with `ignoresMouseEvents` toggled by a pet hit test, without permissions. | PoC E2 ✅ |
| A3 | `NSScreen.visibleFrame` is a good-enough estimate of the Dock's top edge when the Dock is at the bottom and visible. | PoC E3 ✅ (+1.0 pt) |
| A4 | The cat's walk cycle looks acceptable at ~96 pt tall. | PoC E3 ✅ (owner, visual) |
| A5 | Rendering one animated sprite at 60 fps costs < 5% of one CPU core on Apple silicon. | PoC E7 ✅ with Core Animation (~1%); SpriteKit 5.7% ❌ |
| A6 | The provisional bundle identifier `io.github.danielcbdev.petscape` is acceptable until distribution. | Owner decision before M20 |

PoC experiments are defined in [proof-of-concept.md](../planning/proof-of-concept.md).

## Non-goals (permanent)

- Manipulating other apps' windows (moving, resizing, closing).
- Private APIs, code injection, SIP-dependent tricks.
- Network features of any kind.
- Mac App Store distribution (not precluded forever, but not designed for; see ADR-0010).
