# ADR-0011: No third-party dependencies; Swift Testing; bundled swift-format

- Status: Proposed
- Date: 2026-10-16
- Related: [conventions.md](../development/conventions.md), [testing.md](../development/testing.md)

## Context

The project prioritizes native frameworks and must be easy to build for contributors and agents.
On the development machine, `swift-format` ships with the Xcode 27.1 toolchain
(`xcrun --find swift-format`); SwiftLint, SwiftFormat (Nick Lockwood), XcodeGen and Tuist are not
installed.

## Problem

Which dependencies, test framework, formatter/linter and build entry points to use.

## Alternatives

| Concern | Options considered |
|---|---|
| Runtime dependencies | none vs. utility libraries (collections, async algorithms) |
| Tests | Swift Testing, XCTest, both |
| Formatting/linting | `swift-format` (toolchain), SwiftFormat (Homebrew), SwiftLint (Homebrew/plugin) |
| Project generation | none, XcodeGen, Tuist |
| Entry points | raw `xcodebuild`/`swift` commands, Makefile, scripts |

## Decision

- **No third-party runtime or build dependencies.** Adding one requires owner approval and an ADR.
- **Swift Testing** (`import Testing`) for unit and integration tests in the package; **XCTest** only
  for UI tests (XCUITest) and `measure`-based performance tests.
- **`swift format`** (bundled) for formatting and `swift format lint` for style checks, configured by
  `.swift-format`. SwiftLint is not adopted initially; reconsider if review finds recurring issues
  that `swift-format` cannot express.
- **Makefile** with `build`, `test`, `test-core`, `lint`, `format`, `run` targets as the canonical
  commands for humans, CI and agents.
- No project generators.

## Rationale

Zero external tools means `git clone` + Xcode is enough. Swift Testing gives parameterized tests that
suit animation/geometry tables. The bundled formatter avoids version drift.

## Consequences

- Some lint rules (e.g. complexity) are enforced by review instead of tooling.
- CI only needs Xcode.

## Risks

| Risk | Mitigation |
|---|---|
| `swift format` CLI options change between toolchains | Pin config; Makefile wraps the command |
| Swift Testing gaps (no UI/perf) | XCTest for those cases |
