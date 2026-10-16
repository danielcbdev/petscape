# Development Setup

> Until M2 there is no Xcode project; this document describes the target setup. T2.9 replaces the
> "planned" markers with verified commands.

## Toolchain

| Item | Requirement | Observed on the owner's machine (2026-10-16) |
|---|---|---|
| macOS | 14+ to run; latest recommended for development | macOS 27.0.1 (Apple silicon, arm64) |
| Xcode | 26 or later (Swift 6.2+) | Xcode 27.1 (27A9275) |
| Swift | 6.2+ language features only (ADR-0001) | Swift 6.4 (swiftlang-6.4.0.34.1) |
| SDK | macOS SDK from Xcode | macOS 27.0 SDK |
| swift-format | Bundled with the toolchain (`swift format`) | Present at `xcrun --find swift-format` |
| SwiftLint / SwiftFormat / XcodeGen / Tuist | Not used (ADR-0011) | Not installed |
| GitHub CLI | Optional (PRs, releases) | Installed |
| Python + Pillow | Optional, only for ad-hoc asset inspection | Python 3 with Pillow 11.3 |

No package manager installs are required. Do not add Homebrew dependencies to the workflow.

## Getting started (planned, after M2)

```bash
git clone git@github.com:danielcbdev/petscape.git
```

```bash
cd petscape && make build && make test
```

Open `PetScape.xcodeproj` in Xcode and run the `PetScape` scheme. The app appears only in the menu bar.

## Project settings (to be created in T2.1)

| Setting | Value | Where |
|---|---|---|
| `PETSCAPE_BUNDLE_ID` | `io.github.danielcbdev.petscape` (provisional, ADR-0010) | `Config/Base.xcconfig` |
| `PRODUCT_BUNDLE_IDENTIFIER` | `$(PETSCAPE_BUNDLE_ID)` | `Config/Base.xcconfig` |
| `MACOSX_DEPLOYMENT_TARGET` | `14.0` | `Config/Base.xcconfig` |
| `SWIFT_VERSION` | `6.0` (Swift 6 language mode) | `Config/Base.xcconfig` |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` (app target) | `Config/Base.xcconfig` |
| `ENABLE_HARDENED_RUNTIME` | `YES` | `Config/Base.xcconfig` |
| App Sandbox | off (no entitlement) | — |
| `SWIFT_TREAT_WARNINGS_AS_ERRORS` | `YES` in Release/CI | `Config/Release.xcconfig` |
| `INFOPLIST_KEY_LSUIElement` | `YES` | `Config/Base.xcconfig` |
| Code signing (Debug) | "Sign to Run Locally" or a personal Apple Development identity | Xcode |

Signing note: keep a **stable development signing identity** once Accessibility work starts (M12);
macOS ties Accessibility grants to the code signature, and switching identities forces re-granting.

## Canonical commands (planned)

| Command | Runs |
|---|---|
| `make test-core` | `swift test --package-path Packages/PetScapeKit` |
| `make test` | `make test-core` + `xcodebuild test -project PetScape.xcodeproj -scheme PetScape -destination 'platform=macOS'` |
| `make build` | `xcodebuild build -project PetScape.xcodeproj -scheme PetScape -configuration Debug` |
| `make lint` | `swift format lint --recursive --strict PetScape Packages` |
| `make format` | `swift format --in-place --recursive PetScape Packages` |
| `make run` | build, then `open` the Debug app from DerivedData |

## Repository hygiene

- `.DS_Store` files are ignored; 5 were committed before the `.gitignore` existed. Untrack them with
  `git rm --cached` (task T0.2, pending approval).
- Never commit signing material (`.p12`, profiles), `.env`, or `DerivedData`.
- Branches: `main` (releases), `develop` (integration), `feature/T<id>-<slug>`, `fix/…`, `spike/…`, `docs/…`.
