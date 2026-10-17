# AGENTS.md — PetScape

Canonical instructions for **all** AI coding agents (Codex, Claude Code, Cursor, others) and a
quick map for humans. Tool-specific files (`CLAUDE.md`, `CODEX.md`, `.cursor/rules/`) only add
delivery details; if anything conflicts, **this file wins**, then `docs/`.

Documentation and code are written in **English**. The project owner may talk to you in Portuguese;
answer in the language you are addressed in.

## 1. Project

PetScape is a native macOS menu bar app in which small autonomous, animated pets (first: a
blue-grey cartoon 2.5D cat) live on the desktop — walking on the Dock, later jumping, climbing
screen edges and walking on window tops — without ever getting in the way of normal use.
Open-source portfolio project: local only, no backend, accounts, payments, telemetry or network.

- Vision: [docs/product/vision.md](docs/product/vision.md)
- Requirements (stable IDs FR-xx / NFR-xx): [docs/product/requirements.md](docs/product/requirements.md)
- MVP scope and non-goals: [docs/product/scope.md](docs/product/scope.md)

### Current phase

Check the **Status** column in [docs/planning/milestones.md](docs/planning/milestones.md) before
doing anything. As of 2026-10-16: planning is approved and the proof of concept (M1) is **done**
(results: [proof-of-concept.md](docs/planning/proof-of-concept.md#conclusion-t19); throwaway code on
branch `spike/overlay-poc`, never merged). **M2 (app skeleton)** is in review: the Xcode project,
`PetScapeKit` package, Makefile and swift-format config exist; the UI launch test still has to run once
with Automation Mode enabled ([setup.md](docs/development/setup.md#ui-tests-and-automation-mode)).
**M4 (animation system)** is in review: manifest/validator/definition/player/controller in Core, decoder,
frame store and hit masks in Rendering, `CharacterLoader` and the DEBUG Animation Preview in Runtime,
cat `character.json` bundled. Do not start implementation without an explicit instruction naming the
milestone/task.

## 2. Stack

Swift 6 (language mode 6, strict concurrency), SwiftUI (menu + settings), AppKit (windows, events,
screens), Core Animation (rendering only, [ADR-0015](docs/decisions/0015-core-animation-renderer.md)), Core Graphics (geometry), ImageIO (decoding), Accessibility
API (post-MVP, opt-in), OSLog, UserDefaults, Swift Testing + XCTest (UI tests).
macOS 14+ deployment target; developed with Xcode 27.1 / Swift 6.4, code must stay compatible with
Swift 6.2 / Xcode 26. **No third-party dependencies** ([ADR-0011](docs/decisions/0011-tooling-and-dependencies.md)).

## 3. Architecture (must-know)

Read [docs/architecture/overview.md](docs/architecture/overview.md) before changing code.

```
App target (SwiftUI shell, composition root — no domain logic)
  └─ PetScapeRuntime   (@MainActor orchestration: PetRuntime, FrameDriver, pass-through)
       ├─ PetScapePlatform  (AppKit/CG/AX adapters: screens, Dock, cursor, system events, prefs)
       ├─ PetScapeRendering (Core Animation layers, overlay panels, frame images, hit masks)
       └─ PetScapeCore      (pure Swift: world, pets, behavior, physics, animation, surfaces, geometry)
```

Hard rules:

- `PetScapeCore` imports only Foundation and `os`. Never AppKit, SwiftUI, QuartzCore, SpriteKit, ApplicationServices.
- `Platform` and `Rendering` never import each other; they meet in `Runtime`.
- Data crosses module boundaries as `Sendable` values (`ScreenDescriptor`, `Surface`, `RenderSnapshot`).
- Simulation: fixed 60 Hz step, driven by the display frame; stopped entirely when paused, hidden or
  suspended ([ADR-0013](docs/decisions/0013-simulation-loop.md)).
- Core Animation is a renderer only: layers display snapshots; implicit layer animations are disabled;
  no `CAAnimation` for domain timing; no SpriteKit
  ([ADR-0015](docs/decisions/0015-core-animation-renderer.md), [ADR-0005](docs/decisions/0005-kinematic-physics.md)).
- One canonical coordinate space: AppKit global points, y-up; all conversions go through
  `CoordinateConverter` ([coordinate-system.md](docs/specifications/coordinate-system.md)).
- All decisions: [docs/decisions/](docs/decisions/README.md). Do not change architecture without
  proposing an ADR (or ADR update) and getting approval.

## 4. Swift conventions (summary)

Full guide: [docs/development/conventions.md](docs/development/conventions.md).

- Formatting: `swift format` with the repo `.swift-format` (after M2). Do not hand-format against it.
- Types `UpperCamelCase`, members `lowerCamelCase`, one primary type per file named after it.
- `internal` by default; `public` only for cross-module API; `private` for helpers; `final` classes.
- Value types first; classes only for identity/lifecycle (windows, views, layers, controllers).
- Protocols only at real seams (platform adapters, clocks, randomness, renderers) — no speculative abstractions.
- Dependency injection via initializers; composition in `AppContainer`. **No singletons**, no global mutable state.
- Errors: typed `enum …Error: Error` per domain; never `try!`; no force unwrap except proven invariants with a comment.
- No business logic in SwiftUI views; views talk to `@Observable` models that forward intents.

## 5. Swift Concurrency

See [ADR-0012](docs/decisions/0012-concurrency-model.md).

- Core: nonisolated, `Sendable` value types. Platform/Rendering/Runtime/App: default `MainActor` isolation.
- Background work only for I/O and image decoding (`@concurrent`/nonisolated async). Never block the main actor.
- Forbidden without a justification comment approved in review: `@unchecked Sendable`,
  `nonisolated(unsafe)`, `Task.detached`, new `DispatchQueue`/locks.
- Long-lived closures capture `[weak self]`; observers and monitors are removed in `stop()`/`deinit`.

## 6. Testing

Strategy: [docs/development/testing.md](docs/development/testing.md).

- Domain logic (animation timing, state machines, physics, geometry, Dock heuristics, manifest
  validation, behavior) gets unit tests with Swift Testing, deterministic time (`ManualClock` /
  explicit `dt`) and randomness (`SeededRandomSource`).
- Every bug fix starts with a failing test when the logic is testable.
- Do not write tests that only raise coverage; do not delete or weaken tests to make a build pass.
- UI/platform behavior that cannot be automated goes into the manual test matrix in testing.md.

## 7. Feature rules

- Implement only what the current task in [task-breakdown.md](docs/planning/task-breakdown.md) asks.
  Out-of-scope ideas go to the "Follow-ups" section of your report, not into code.
- Check acceptance criteria in [acceptance-criteria.md](docs/planning/acceptance-criteria.md) before calling a task done.
- MVP must not require any permission (FR-16). Anything needing Accessibility is opt-in and post-MVP.

## 8. Pet rules

- Pets are data + systems: a new character is a character pack, not a subclass
  ([pet-engine.md](docs/architecture/pet-engine.md)).
- Pets never reference each other directly; interactions go through perception values and typed events.
- Every pet state declares clip, motion mode, interrupt threshold and duration bounds
  ([state-machines.md](docs/specifications/state-machines.md)); invalid states recover, never crash.

## 9. Animation & asset rules

- Frame counts, FPS, anchors, events and fallbacks live in `character.json`
  ([animation-schema.md](docs/specifications/animation-schema.md)) — never hard-coded.
- Animation timing is computed in Core (`AnimationPlayer`) from simulation `dt`.
- **Original files under `assets/` are read-only** (frames, atlases, GIFs, their README/manifest).
  You may add `character.json` files and new clips; never edit, rename, re-export or delete originals.
- Pet layer bounds always come from the manifest `displaySize`, never from image pixel size.

## 10. Permissions

- Matrix and flows: [permissions.md](docs/specifications/permissions.md).
- Never request Screen Recording, Input Monitoring, Automation or Full Disk Access.
- Accessibility is requested only when the user enables window interaction (M12+), with clear copy.

## 11. Security & privacy

- Public APIs only. **No private APIs/SPI**, no code injection, no scripting additions, no dlopen tricks.
- Never move, resize, close, focus or click other apps' windows. Interaction is purely visual.
- Never read window titles or screen contents. No network code. No telemetry.
- Never commit secrets, certificates, provisioning profiles or notarization credentials.
- Overlay windows never become key/main, never exceed the levels defined in
  [macos-integration.md](docs/architecture/macos-integration.md), never cover fullscreen apps (MVP).

## 12. Performance

Targets: [performance.md](docs/specifications/performance.md) (e.g. ≤ 5% CPU walking, ~0% paused).
No polling where a notification exists; no work while paused/hidden/suspended; no allocations or
string formatting in the per-frame path; downsample textures at load. Report measurements, don't
assume them.

## 13. Documentation

- Read the relevant docs before modifying code (start from the links in this file).
- Update docs in the same change when behavior, contracts or decisions change; add/supersede ADRs
  for decisions that are expensive to reverse.
- Use relative links; do not create empty or duplicate documents.
- Update the milestone **Status** column when a milestone changes state.

## 14. Implementation process

1. Identify the task ID (e.g. `T3.4`) and read its row, its milestone and the linked specs.
2. If the task is ambiguous or conflicts with the docs, stop and ask; do not guess silently.
3. Plan the smallest change that satisfies the acceptance criteria; state assumptions.
4. Implement with tests (tests first for pure logic).
5. Build and run the relevant tests (`make test-core`, `make test`, `make build` — available after M2);
   never ignore compiler errors or warnings.
6. Verify manually when the behavior is visual/platform-dependent and say exactly what was verified.
7. Update docs/status. Report: what changed, how it was verified, limitations, follow-ups.
8. **Do not commit, push, tag or open PRs unless explicitly asked.** Branch naming when asked:
   `feature/T3.4-overlay-panel`, `fix/…`, `spike/…`; Conventional Commits messages.

## 15. Quality bar (Definition of Done for any task)

- Builds with zero warnings in Swift 6 mode; `swift format lint` clean.
- Relevant tests pass; new logic has tests; no tests removed or skipped to pass.
- No new dependency, private API, singleton, force-unwrap or unjustified `@unchecked Sendable`.
- Module boundaries respected; no unrelated refactors or new files beyond what the task needs.
- Docs updated; limitations and unverified aspects stated explicitly.
- Never claim something works without having validated it; say "not verified" when you could not.

## Mandatory rules (checklist)

- Read relevant documentation before modifying code.
- Do not change the architecture without justification (ADR).
- Do not add dependencies without the owner's approval.
- Do not change contracts (public APIs, manifest schema, preferences keys) without assessing impact.
- Do not ignore compilation errors. Do not remove tests just to make builds pass.
- Do not use private APIs. Do not implement outside the task's scope.
- Do not create unnecessary files. Do not refactor unrelated code.
- Update documentation when needed. Run the relevant tests.
- Report limitations. Do not claim something works without validating it.
- Do not commit without being asked.

## Commands

Available since M2 (details and verified status: [setup.md](docs/development/setup.md#canonical-commands)):

| Command | Purpose |
|---|---|
| `make test-core` | `swift test` for the package (fast; pure logic) |
| `make test` | package tests + app/UI tests via `xcodebuild` |
| `make build` | Debug build of the app |
| `make lint` / `make format` | `swift format lint` / in-place format |
| `make run` | Build and launch the Debug app |

Environment facts and setup: [docs/development/setup.md](docs/development/setup.md).
Debugging and logs: [docs/development/debugging.md](docs/development/debugging.md).

## Where things are

| Need | Go to |
|---|---|
| Plan, milestones, tasks, criteria | [docs/planning/](docs/planning/implementation-plan.md) |
| Proof of concept | [docs/planning/proof-of-concept.md](docs/planning/proof-of-concept.md) |
| Risks and open decisions | [docs/planning/risks.md](docs/planning/risks.md) |
| Architecture per subsystem | [docs/architecture/](docs/architecture/overview.md) |
| Formats and contracts | [docs/specifications/](docs/specifications/animation-schema.md) |
| Decisions | [docs/decisions/](docs/decisions/README.md) |
| Release/distribution | [docs/development/release.md](docs/development/release.md) |
