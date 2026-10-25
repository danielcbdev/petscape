# Changelog

All notable user-visible changes. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/). Release process: [release.md](docs/development/release.md).

## [Unreleased]

## [1.0.1] - 2026-10-25

### Fixed

- Installation guidance now identifies the Apple verification warning and puts the app-specific
  Privacy & Security → Open Anyway flow before first use, in English and Brazilian Portuguese.
- README adds MacDevClean's Terminal download/verify/open method, using HTTPS-only redirects and
  stopping before opening if a download/checksum fails; it requires no source checkout or Xcode.
- DMG/ZIP now include `INSTALL-FIRST.txt` for offline instructions in TextEdit, alongside `INSTALL.md`.

### Security and known limits

- Signature remains ad-hoc with no Developer ID or Apple notarization. The referenced MacDevClean
  release also has no Apple developer identity. Download method does not confer Apple approval;
  no quarantine attribute/global security policy is changed and warning-free launch is not promised.
- The owner separately authorized the unchanged 48-issue V8 pixel-QA exception for v1.0.1 only.
  Every other gate remains mandatory; native Intel and clean-machine approval/relaunch are unverified.

## [1.0.0] - 2026-10-25

First public distribution: universal macOS 14+ DMG and ZIP, installed by dragging PetScape.app to
Applications. No Xcode or project checkout is needed for installation.

### Added

- Autonomous pets with jumping, landing, climbing, resting and expression animations.
- Optional window interaction through Accessibility and local music detection with manual dance controls.
- Native Settings sections, English/Brazilian Portuguese localization and launch-at-login controls.
- Local character-pack installation and a persisted roster of independently simulated characters.
- Reproducible ad-hoc Release archives and universal DMG/ZIPs with release notes, bilingual install
  guidance, internal file inventory and an external SHA-256 checksum.
- Manual GitHub Actions packaging with strict quality gates and opt-in draft release creation for an
  existing version tag. No Apple signing credentials or notarization are required or provided.

### Security

- Distributed builds have an ad-hoc signature without identified-developer assurance or Apple
  notarization. Gatekeeper warnings/blocks are possible; opening is an explicit user trust decision.

### Known limitations

- The historical M15 V8 pixel-QA failure (48 issues) remains failed. The owner explicitly authorized
  a narrowly scoped exception for v1.0.0; all other release gates must pass.
- Clean-machine installation, actual Gatekeeper warnings and native Intel execution remain
  unverified; cross-built x86_64 and arm64 signatures are validated.
- Source code is MIT. The owner authorized art distribution in the app with rights reserved; see
  `ARTWORK-LICENSE.md`. Historical art/provenance records remain unchanged.

## MVP implementation history (unreleased, originally targeted v0.1.0)

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
