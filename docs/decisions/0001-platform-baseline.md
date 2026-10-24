# ADR-0001: Platform baseline — macOS 14+, Swift 6, Apple silicon first

- Status: Proposed
- Date: 2026-10-16
- Related: [requirements.md](../product/requirements.md) (NFR-09), [setup.md](../development/setup.md)

## Context

The development machine runs macOS 27.0.1 on Apple silicon, with Xcode 27.1 and Swift 6.4. The
project is a portfolio app that should reach a reasonable range of users without carrying legacy
cost. Apple has announced that macOS 26 is the last macOS release for Intel Macs.

## Problem

Choose the minimum macOS version, Swift language mode, concurrency checking level and CPU
architectures.

## Alternatives

| Option | Pros | Cons |
|---|---|---|
| macOS 13 | Wider reach | No `@Observable`, no `SettingsLink`, older SwiftUI `MenuBarExtra` quirks |
| **macOS 14** | `@Observable`, `SettingsLink`, `NSView/NSScreen.displayLink`, mature `MenuBarExtra`, `SMAppService` | Must test on an OS two+ versions old |
| macOS 15 | Fewer test targets | Excludes Sonoma users for little API gain |
| macOS 26/27 only | Newest APIs, easiest testing | Very narrow audience for an app with modest API needs |

## Decision

- Deployment target **macOS 14.0**.
- **Swift 6 language mode** in all targets (complete strict concurrency checking implied).
- Toolchain: Xcode 26 or later (Swift 6.2+) is required, because package targets use
  `defaultIsolation` (SE-0466). Development uses Xcode 27.1 / Swift 6.4. Language features newer
  than Swift 6.2 are not used unless this ADR is updated (keeps CI runners and contributors on
  older Xcode viable).
- Architectures: **Apple silicon primary.** Build a universal binary (arm64 + x86_64) when the
  toolchain still supports it; Intel is **best-effort and untested** (no Intel hardware available).
- `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` for Release and CI builds.

## Rationale

macOS 14 is the lowest version that provides everything the design uses without availability
checks, and it covers the large majority of active Macs. Swift 6 mode catches data races at compile
time, which matters for an app mixing AppKit callbacks, AX observers and async asset loading.

## Consequences

- No `#available` branches are expected for the MVP. Newer APIs are used only behind availability
  checks with a documented fallback.
- Testing on macOS 14 requires a VM (Virtualization framework / UTM) or a CI runner; manual test
  matrix lists it.

## Risks

| Risk | Mitigation |
|---|---|
| Behavior differences in window levels/Spaces between macOS 14 and 27 | Manual test matrix on a macOS 14 VM before each release |
| GitHub-hosted runners may lag behind Xcode 27 | Keep code compatible with Swift 6.2 / Xcode 26 |
| Intel builds break silently | Mark Intel as unsupported if the universal build cannot be validated by M20 |
