# ADR-0010: Developer ID distribution, Hardened Runtime, no App Sandbox

- Status: Proposed
- Date: 2026-10-16
- Related: [release.md](../development/release.md), [permissions.md](../specifications/permissions.md)

## Context

Distribution will be via GitHub Releases, outside the Mac App Store. Window interaction (M12+) needs
the Accessibility API to observe other apps. The bundle identifier cannot be assumed to be free if it
is based only on the app name.

## Problem

Decide sandboxing, signing/notarization approach and bundle identifier policy early, because changing
sandboxing later moves app data (`UserDefaults` → `~/Library/Containers/…`) and breaks permissions.

## Alternatives

| Option | Consequence |
|---|---|
| Mac App Store | Requires App Sandbox → AX observation of other apps not possible; overlay apps face review risk |
| Sandboxed, direct distribution | Same AX limitation; no benefit for this app |
| **Not sandboxed, Hardened Runtime, Developer ID signed, notarized** | Full public API access (AX), smooth Gatekeeper experience; requires a paid Apple Developer Program membership |
| Unsigned / ad-hoc signed | Free, but Gatekeeper blocks first launch; recent macOS requires going to System Settings › Privacy & Security › "Open Anyway"; Accessibility grants are fragile across builds |

## Decision

- **No App Sandbox. Hardened Runtime on**, with no exception entitlements.
- Release builds are **Developer ID–signed and notarized** (`notarytool`), packaged as a DMG
  (stapled). Until a Developer ID is available, pre-releases are ad-hoc signed with documented
  "Open Anyway" instructions.
- Bundle identifier is **provisional**: `io.github.danielcbdev.petscape`, defined once in
  `Config/Base.xcconfig` (`PETSCAPE_BUNDLE_ID`) so it can be changed before the first public release.
  Changing it after release resets users' preferences and permission grants.

## Rationale

The product's differentiating features need AX; sandboxing provides no user-facing benefit for a
local, network-free app, while notarization gives users a trustworthy install.

## Consequences

- Mac App Store distribution is not possible without a feature-reduced variant (not planned).
- Owner decision needed: enrol in the Apple Developer Program before M20.

## Risks

| Risk | Mitigation |
|---|---|
| No Developer ID → poor install experience | Clear README instructions; ad-hoc pre-releases |
| Bundle ID collides or is changed late | Decide before first public release (open decision D-03) |
