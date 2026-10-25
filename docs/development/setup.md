# Development Setup

> Verified on 2026-10-16 (T2.9) with Xcode 27.1 / Swift 6.4 on macOS 27.0.1, unless marked otherwise.

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

## Getting started

```bash
git clone git@github.com:danielcbdev/petscape.git
```

```bash
cd petscape && make build && make test && make lint
```

Or open `PetScape.xcodeproj` in Xcode and run the `PetScape` scheme. The app appears only in the
menu bar (paw print icon); quit it from its menu.

## Project layout

- `PetScape.xcodeproj`: the `PetScape` app target and the `PetScapeUITests` target. It uses
  folder-synchronized groups: files added under `PetScape/` or `PetScapeUITests/` are picked up
  without editing `project.pbxproj`. The shared scheme `PetScape` builds the app and runs the UI tests.
- `Packages/PetScapeKit`: `swift-tools-version: 6.2`, Swift 6 language mode, four library targets plus
  four test targets ([modules.md](../architecture/modules.md)). Core is nonisolated; Platform,
  Rendering, Runtime and their tests use `.defaultIsolation(MainActor.self)`. The app links
  `PetScapeRuntime`, `PetScapePlatform` and `PetScapeCore`.
- `Config/*.xcconfig`: shared build settings. `project.pbxproj` holds localization metadata and
  per-target values (`PRODUCT_NAME`; for UI tests the bundle ID, `TEST_TARGET_NAME`, isolation and
  Hardened Runtime).
- The Info.plist is generated (`GENERATE_INFOPLIST_FILE`) and merged with
  `Config/PetScape-Info.plist`. Resources include `PetScape/Resources/Assets.xcassets`,
  `Localizable.xcstrings` (English source, `pt-BR` translation), and `en.lproj/InfoPlist.strings` /
  `pt-BR.lproj/InfoPlist.strings` for the display name and system-audio consent description.

## Project settings

| Setting | Value | Where |
|---|---|---|
| `PETSCAPE_BUNDLE_ID` | `io.github.danielcbdev.petscape` (provisional, ADR-0010); also `Log.defaultSubsystem` | `Config/Base.xcconfig` |
| `PRODUCT_BUNDLE_IDENTIFIER` | `$(PETSCAPE_BUNDLE_ID)` (UI tests: `$(PETSCAPE_BUNDLE_ID).uitests`) | `Config/Base.xcconfig` / UI test target |
| `MACOSX_DEPLOYMENT_TARGET` | `14.0` (Info.plist `LSMinimumSystemVersion` follows it) | `Config/Base.xcconfig` |
| `SWIFT_VERSION` | `6.0` (Swift 6 language mode) | `Config/Base.xcconfig` |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor`; `nonisolated` in the UI test target (`XCTestCase` initializers are nonisolated; test methods are `@MainActor`) | `Config/Base.xcconfig` / UI test target |
| `ENABLE_HARDENED_RUNTIME` | `YES`; `NO` in the UI test target (see notes) | `Config/Base.xcconfig` / UI test target |
| App Sandbox | off (no entitlement) | — |
| `SWIFT_TREAT_WARNINGS_AS_ERRORS`, `GCC_TREAT_WARNINGS_AS_ERRORS` | `YES` in Release; always passed by the Makefile's `xcodebuild` calls | `Config/Release.xcconfig`, `Makefile` |
| `INFOPLIST_KEY_LSUIElement` | `YES` (no Dock icon, no app menu) | `Config/Base.xcconfig` |
| `INFOPLIST_KEY_CFBundleDisplayName` | `PetScape` | `Config/Base.xcconfig` |
| `CFBundleDevelopmentRegion` | `en` | `Config/PetScape-Info.plist`, `Config/Base.xcconfig` |
| `CFBundleLocalizations` | `en`, `pt-BR` | `Config/PetScape-Info.plist`; project regions in `project.pbxproj` |
| `LOCALIZATION_PREFERS_STRING_CATALOGS`, `SWIFT_EMIT_LOC_STRINGS` | `YES` | `Config/Base.xcconfig` |
| `ALWAYS_SEARCH_USER_PATHS` | `NO` (otherwise Xcode warns about traditional headermaps) | `Config/Base.xcconfig` |
| Code signing | `CODE_SIGN_IDENTITY = -` ("Sign to Run Locally"), automatic style, no team | `Config/Base.xcconfig` |

Notes:

- **Hardened Runtime with local signing.** Xcode prints `note: Disabling hardened runtime with ad-hoc
  codesigning`, so the setting is on but has no effect until the app is signed with a real
  identity (Developer ID for releases, M21). Local Debug builds therefore run without it.
- **UI test target.** With Hardened Runtime on, the test runner's library validation refuses to
  load the locally signed test bundle ("different Team IDs"). The UI test target never ships, so
  it turns Hardened Runtime off.
- **Signing identity.** Keep a **stable development signing identity** once Accessibility work
  starts (M12). macOS ties Accessibility grants to the code signature, and switching identities
  forces users to grant access again.
- The app target disables Xcode user-script sandboxing only for its manifest-driven character
  resource pruning phase. That phase reads `assets/characters` and its script, then replaces only
  the generated app bundle's `Contents/Resources/characters` directory; the UI test target keeps
  the default script sandbox setting.

## Canonical commands

| Command | Runs | Verified |
|---|---|---|
| `make test-core` | `swift test --package-path Packages/PetScapeKit -Xswiftc -warnings-as-errors` | M20 run: nonzero only for the existing M15 V8 pixel-QA test (48 issues); M20 package suites passed |
| `make test` | `make test-core`, then `xcodebuild … -configuration Debug test` (UI tests) | M20 run stops at the package V8 exception; separate XCUITest run passed 7/7 in Automation Mode |
| `make build` | `xcodebuild -project PetScape.xcodeproj -scheme PetScape -destination 'platform=macOS' -derivedDataPath build/DerivedData -configuration Debug build` with warnings as errors | Yes |
| `make lint` | `swift format lint --strict --recursive --parallel` over `PetScape`, `PetScapeUITests` and the package sources/tests, then a `grep` for forbidden imports (Core: no AppKit/SwiftUI/QuartzCore/SpriteKit/ApplicationServices/other PetScape modules; Rendering and Platform: no SpriteKit and not each other) | Yes |
| `make format` | `swift format --in-place --recursive --parallel` over the same paths | Yes |
| `make run` | `make build`, then `open build/DerivedData/Build/Products/Debug/PetScape.app` | Yes |

The Makefile builds into `build/DerivedData` (git-ignored), so `make run` knows where the app is.
Xcode itself keeps using its default DerivedData.

Expected tool output that is not a warning about our code: `appintentsmetadataprocessor … warning:
Metadata extraction skipped, no AppIntents.framework dependency found` (printed on every app build).

### UI tests and Automation Mode

XCUITest on macOS needs **Automation Mode**. Earlier runs on this Mac timed out while enabling it
when authentication was not completed. The 2026-10-18 M9 rerun passed in an authenticated Automation
Mode session. `make test` is the canonical local command; if the authentication prompt appears, finish
it interactively before retrying. Do not change app privacy permissions to run tests.

## Repository hygiene

- `.DS_Store` files are ignored; the 5 committed before the `.gitignore` existed were untracked in T0.2.
- Never commit signing material (`.p12`, profiles), `.env`, or `DerivedData`.
- Branches: `main` (releases), `develop` (integration), `feature/T<id>-<slug>`, `fix/…`, `spike/…`, `docs/…`.

## Continuous integration (T2.8)

The owner authorized closing M2 on 2026-10-18. `.github/workflows/ci.yml` runs lint/module-boundary
checks, package tests and the Debug app build on develop pushes/PRs, with read-only checkout
credentials and bounded concurrency/time. It uses Xcode 26.2 on macos-26, matching the minimum
Swift 6.2 compatibility requirement; selection follows the [official runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md).
The checkout action is pinned to its verified official v5 commit. UI tests remain local because
they require an interactive Automation Mode session. No hosted run is claimed before changes
are pushed under a separate owner instruction.

## M16 audio development

Builds keep macOS 14.0 deployment support; automatic dancing requires public Core Audio taps on
14.2+, guarded at runtime. AVFoundation/CoreAudio/SoundAnalysis are system frameworks, no external
dependency. The generated app Info.plist merges `NSAudioCaptureUsageDescription` from
`Config/PetScape-Info.plist`, selected by the app target in both configurations. Merely adding an
arbitrary `INFOPLIST_KEY_…` setting did not emit this key in the built bundle. `make build` now checks
the actual Debug bundle so this cannot silently regress. No microphone key, Screen Recording/Automation entitlement or private
permission API is needed. Run the bundled installed app with a stable development signature for
native consent tests; a changed ad-hoc signature can affect stored OS grants. Do not enable capture
inside unattended tests. Fakes exercise lifecycle; real audio/consent/route checks remain owner-run.
See [M16](../planning/m16-implementation.md) and [V9 art handoff](../specifications/animation-assets-v9.md).

## Installing a character pack (M19)

1. Use a local **folder** containing a schema-v1 `character.json` at its root and every referenced
   PNG at its manifest-relative path. ZIP files and remote packs are not supported.
2. Open PetScape Settings → Character → **Install Character Pack…** and choose that folder in the
   native folder picker. The app validates it and copies only the manifest and referenced PNGs to
   `~/Library/Application Support/PetScape/Characters/<id>`.
3. After the success message, choose the installed character from the same Character picker. Import
   does not switch the active pet automatically.
4. To remove a pack, quit PetScape and delete its `<id>` folder from the Characters directory in
   Finder. The app discovers external changes at the next launch; if the saved character is missing
   or invalid, it applies the M18 fallback after a successful swap.

PetScape does not update or overwrite an existing ID. Choose an ID that is unique among bundled and
installed packs. Invalid packs stay on disk and are omitted from the selector; use the localized
Settings message to correct the pack or quit and remove it. Unreferenced files are ignored and not
copied. The import flow does not keep a bookmark or require Full Disk Access, Accessibility, Screen
Recording, Input Monitoring, Automation, or network access.

## Localization (M17)

`PetScapeLanguage` resolves `Locale.preferredLanguages` in order: English variants map to `en`, all
Portuguese variants map to the Brazilian Portuguese resources, and unsupported lists fall back to
English. `SystemLanguageMonitor` observes `NSLocale.currentLocaleDidChangeNotification`; the app
applies its selected locale to the content inside MenuBarExtra and Settings. Status and error models
expose typed values so the view resolves their copy using that same SwiftUI locale. There is no app
language preference or selector.

When editing copy, update both the English source and `pt-BR` entry in `Localizable.xcstrings`.
`xcodebuild` compiles the catalog into the app resources; `xcrun xcstringstool sync` can compare the
catalog with build-emitted `.stringsdata`, and `xcrun xcstringstool compile` validates catalog
compilation. Verify the built Debug and Release bundles contain `pt-BR.lproj/Localizable.strings`
and both localized `InfoPlist.strings` resources.
