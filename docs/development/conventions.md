# Code Conventions

Applies to all Swift code. Agents: this is the long form of [AGENTS.md §4–5](../../AGENTS.md).

## Formatting

- `swift format` with the repository `.swift-format`: 4-space indentation, 120
  columns, ordered imports, trailing commas in multi-line collections.
- `make lint` must be clean; formatting changes go in the same PR as the code, never mixed into
  unrelated files.

## Naming

| Element | Rule | Example |
|---|---|---|
| Types, protocols | UpperCamelCase nouns; protocols describe a role (noun) or capability (`…ing`) | `AnimationPlayer`, `FrameDriver`, `PetHitTesting` |
| Protocol + implementations | Protocol takes the role noun; implementations add a qualifying prefix | `PreferencesStore` / `UserDefaultsPreferencesStore`, `InMemoryPreferencesStore` |
| Functions | Verb phrases, Swift API Design Guidelines | `step(dt:)`, `resolveClip(named:)` |
| Booleans | `is…`, `has…`, `can…`, `should…` | `isPaused` |
| Test doubles | `Fake…` (working simplified impl), `Stub…` (canned answers), `Spy…` (records calls) | `FakeClock` |
| Coordinates | Canonical by default; other spaces in the name | `overlayPoint`, `quartzRect`, `localRect` |
| Units | In the name when not obvious | `durationSeconds`, `speedPointsPerSecond` |

## Files and organization

- One primary type per file, file named after it; small private helpers may share the file.
- Folder structure per module as in [modules.md](../architecture/modules.md); no `Utils`/`Helpers`
  dumping grounds — put helpers next to their single user or in a named folder.
- Extensions adding protocol conformance: `Type+Protocol.swift` when non-trivial.
- Order inside a type: properties, init, public/internal API, private helpers.

## Types and access control

- Value types (`struct`, `enum`) by default. Classes only for identity/lifecycle (windows, views, layers,
  controllers, observers); mark them `final`.
- Access: `internal` default; `public` only for API used by another module; `private` for helpers;
  avoid `open`.
- Prefer enums with associated values for states and events; exhaustive `switch` without `default`
  for domain enums (so new cases fail to compile where they must be handled).
- Avoid stringly-typed identifiers: `PetID`, `SurfaceID`, `CharacterID` are distinct types.

## Protocols and dependency injection

- Introduce a protocol only at a real seam: platform adapters, clock, randomness, preferences,
  hit testing, frame driver, renderer boundary. Not "one protocol per class".
- Dependencies are passed through initializers. `AppContainer` (app target) is the only composition
  root. No singletons, no service locators, no global mutable state, no `static var` caches.
- Apple singletons (`NSWorkspace.shared`, `NotificationCenter.default`, `UserDefaults.standard`) are
  touched only inside Platform adapters, injected where possible for tests.

## Error handling

- Each domain defines a typed error enum (`CharacterLoadError`, `ManifestValidationError`, …) with
  context (path, clip name) for logs. Typed throws (`throws(CharacterLoadError)`) where it clarifies
  an API.
- Never `try!`/`fatalError` for recoverable situations. `precondition` only for programmer errors,
  with a message.
- Force unwrap only for proven invariants, with a `// Invariant:` comment.
- Recoverable runtime problems degrade gracefully (fallback clip, placeholder, recovery state) and
  are logged at `.error`.

## Swift concurrency

Model: [ADR-0012](../decisions/0012-concurrency-model.md).

- Core: nonisolated; types `Sendable` (conformance explicit on public types).
- Platform/Rendering/Runtime/App: default `MainActor` isolation; mark the few background entry points
  `nonisolated`/`@concurrent`.
- Use structured concurrency (`async let`, task groups) for parallel decoding; cancel on teardown.
- No `Task.detached`, `@unchecked Sendable`, `nonisolated(unsafe)`, locks or new `DispatchQueue`
  without a `// Concurrency:` justification comment reviewed in the PR.
- AppKit notification observers: store tokens and remove them in `stop()`; closures use `[weak self]`.
- Never block the main actor (no synchronous file I/O after launch, no `sleep`, no semaphores).

## SwiftUI

- Views are thin: layout + bindings. No business logic, no direct calls into Core/Platform; they talk
  to an `@Observable` model (`AppModel`, `SettingsModel`) that forwards intents.
- Use native controls and `Settings`/`MenuBarExtra` patterns; follow macOS HIG; all strings
  localizable via the String Catalog.
- English is the String Catalog source language; `pt-BR` is the Brazilian Portuguese localization.
  Resolve the ordered macOS preferred-language list at the app boundary, pass the selected locale to
  SwiftUI, and keep model/service statuses semantic until the view renders localized text. Do not
  materialize view copy with the process-default locale in Runtime or Platform.

## Logging

- `Log.<category>` wrappers over `os.Logger` with subsystem = bundle ID. Categories: `app`, `overlay`,
  `rendering`, `animation`, `assets`, `simulation`, `behavior`, `physics`, `surfaces`, `dock`,
  `windowTracking`, `permissions`, `performance`.
- Levels: `.debug` (dev detail, not persisted), `.info` (state changes), `.notice` (important
  lifecycle), `.error` (recoverable failure), `.fault` (bug/invariant violation).
- Privacy: interpolate only non-sensitive values; mark anything else `.private` (we should not have
  sensitive data at all — no window titles, no paths outside the bundle in release logs).
- No logging with string interpolation in the per-frame path except `.debug` behind a flag; use
  signposts for timing.

## Documentation in code

- `///` doc comments on public API and on any non-obvious internal type (purpose, units, invariants).
- Comments explain *why*, not *what*. Link to specs/ADRs when a rule comes from them
  (`// See ADR-0008`).

## Avoid

Force unwraps without invariants · singletons · god objects (`Manager` doing everything) · circular
dependencies · logic in views · duplicated code (extract after the second real duplicate, not before)
· premature abstraction · unnecessary libraries · magic numbers (use tuning structs) · `default:` in
switches over domain enums.

## Tooling evaluation (summary)

| Tool | Decision |
|---|---|
| `swift format` (bundled) | Adopted for format + lint |
| SwiftFormat (nicklockwood) | Not adopted — external install, overlaps with swift-format |
| SwiftLint | Not adopted initially — external install; revisit if review finds recurring issues |
