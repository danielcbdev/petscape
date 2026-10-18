# Changelog

All notable user-visible changes. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/). Release process: [release.md](docs/development/release.md).

## [Unreleased] — v0.1.0 (MVP, not tagged)

### Added

- Menu bar app (no Dock icon, no window) with Show/Hide Pet, Pause/Resume and Quit PetScape.
- A blue-grey cartoon cat that walks back and forth on top of the bottom Dock, turning at the screen edges,
  drawn in a transparent overlay that lets every click outside the cat's pixels through.
- Dock detection from public API only: the cat walks on the Dock top, or on the screen bottom when the Dock
  hides automatically or sits on the left or right; it follows Dock and display changes without polling.
- Data-driven animation from `character.json` (frames, fps, anchor, speed, events) with a placeholder and a
  menu status line when the character cannot be loaded.
- Pause, hide and the Dock offset are remembered across launches.
- Rendering stops completely while paused, hidden, in a full-screen Space, asleep, locked or with the display
  off.

### Known limitations

- The cat walks the full screen width, beyond the ends of the Dock shelf (no public API for the shelf width).
- With auto-hide, the cat stays on the screen bottom and the revealed Dock slides over it.
- Hiding or showing the Dock moves the cat straight down or up (falling arrives with physics in v0.2.0).
- The Dock offset adjustment is only in Debug builds until the Settings window (v0.3.0).
- Single display tested; external displays are planned for v1.0.0 (M14).
