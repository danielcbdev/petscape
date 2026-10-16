# ADR-0002: Xcode app shell + local Swift package with four modules

- Status: Proposed
- Date: 2026-10-16
- Related: [modules.md](../architecture/modules.md), [overview.md](../architecture/overview.md)

## Context

The app needs an `.app` bundle (Info.plist, `LSUIElement`, signing, resources) and a domain that
must stay free of UI frameworks and be testable quickly from the command line, including by AI agents.

## Problem

How to structure targets so that layering is enforced, builds/tests are fast, and the project file
stays small and merge-friendly.

## Alternatives

| Option | Pros | Cons |
|---|---|---|
| Single Xcode app target with folders | Simplest | Layering by convention only; tests need the app host; slow CLI tests |
| Multiple Xcode framework targets | Enforced layering | Large `project.pbxproj`, merge conflicts, more build settings to keep in sync |
| Generated project (XcodeGen/Tuist) | Diff-friendly | Extra tool dependency (rejected by ADR-0011) |
| Pure SwiftPM executable | No Xcode project | Poor fit for a signed `.app` with Info.plist, resources, UI tests |
| **Xcode app target + one local package (`PetScapeKit`) with 4 library targets** | Compiler-enforced layering; `swift test` runs domain tests in seconds; small Xcode project | Two build systems to understand; resource bundling across the boundary needs care |

## Decision

- `PetScape.xcodeproj` contains the app target (`PetScape`), the UI test target and nothing else.
  It uses Xcode's folder-synchronized groups to minimize `project.pbxproj` churn.
- `Packages/PetScapeKit` contains `PetScapeCore`, `PetScapePlatform`, `PetScapeRendering`,
  `PetScapeRuntime` and their test targets, with dependencies as in [modules.md](../architecture/modules.md).
- Package targets use `swiftLanguageModes: [.v6]`; Platform, Rendering and Runtime use
  `.defaultIsolation(MainActor.self)`; Core stays nonisolated.

## Rationale

Four modules map to four different dependency sets (pure / AppKit+AX / rendering — Core Animation since ADR-0015 / orchestration);
that is the smallest split where the compiler enforces "Core never imports AppKit" and "Rendering
never touches AX". Further splitting (one module per engine) adds overhead without enforcing
anything new.

## Consequences

- Domain changes are tested with `swift test --package-path Packages/PetScapeKit`.
- App-level changes require `xcodebuild`.
- Character pack resources belong to the app bundle (not the package), see ADR-0007.

## Risks

| Risk | Mitigation |
|---|---|
| Xcode and SwiftPM settings drift (e.g. warnings-as-errors) | Settings documented in [setup.md](../development/setup.md); CI builds both |
| Agents editing `project.pbxproj` by hand | Rule in AGENTS.md: avoid manual pbxproj edits; prefer synchronized folders |
| Package-level `defaultIsolation` semantics change | Pinned to Swift 6.2 semantics (ADR-0001) |
