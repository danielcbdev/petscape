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
doing anything. As of 2026-10-18, **M7 (basic physics) and M8 (jumps/landings, including V4 art)
are Done by explicit owner acceptance** after the owner confirmed all remaining tests. Automated
package tests, UI runs and Debug/Release builds are recorded; instrumented evidence limits and
the historical Automation Mode timeout remain explicit in the
[owner closeout](docs/planning/m7-m8-technical-review.md#owner-m7m8-closeout-2026-10-18).

M1–M8 are Done by owner acceptance. On 2026-10-18 the owner explicitly closed M2/M3/M5/M6,
reporting that everything works perfectly; historical missing logs/hardware/quantitative evidence
remain identified in the closeout record, without inventing measurements. CI is authored locally;
no hosted run, push, release or tag is claimed. M6 is merged, v0.1.0 remains untagged.
**M9 was explicitly reauthorized and then closed by owner acceptance on 2026-10-18** after the
implementation, 400 package tests, 2 UI tests, lint and Debug/Release gates passed. Real login-item,
native cadence and installed-app playtest evidence limits remain in the [closeout](docs/planning/m9-implementation.md#owner-m9-closeout-2026-10-18); they are accepted gaps, not claimed test results.
M10–M14 have subsequent owner closeouts in the milestone register. **M15 was closed by explicit
owner acceptance on 2026-10-23**, after the owner tested the revised animations and pacing and
authorized integration into `develop`. The existing V8 pixel-QA failure remains a documented
exception, not a passed check; see the [M15 closeout](docs/planning/m15-implementation.md#owner-m15-closeout--2026-10-23).
**M16 was closed by explicit owner acceptance on 2026-10-24**, after the owner confirmed all
behavior works, including automatic/manual dancing, Stop Dance and cleanup after held drops, and
authorized creating a branch, committing, merging into `develop` and pushing. V9 art is integrated.
The existing V8 pixel-QA failure and measurement/permission-evidence limits are retained in the
[M16 closeout](docs/planning/m16-implementation.md#owner-m16-closeout--2026-10-24).
M17–M20 were planning only at M16 closeout; M16 closure did not authorize their implementation.
The owner separately authorized **M18** and then explicitly accepted its closure on 2026-10-24,
including branch creation, commit and local merge into `develop`. **M18 is Done by owner acceptance**
with only `cat` bundled: real two-character selection remains deferred (AC-M18-08 unmet), and native
Automation Mode/V8/performance evidence limits remain recorded in the
[M18 closeout](docs/planning/milestones.md#owner-m18-closeout--2026-10-24). No push, release or tag is
implied. The owner separately authorized and accepted **M17 localization** on 2026-10-24, with
native visual, VoiceOver and live system-language-change checks explicitly unverified and accepted
as evidence limits in the [M17 closeout](docs/planning/milestones.md#owner-m17-closeout--2026-10-24).
M19 was explicitly authorized and later closed by owner acceptance on 2026-10-24, with real
external-pack import/manual visual review, VoiceOver review and imported-art performance still
unverified. These are accepted evidence limits in the [M19 closeout](docs/planning/milestones.md#owner-m19-closeout--2026-10-24),
not passed criteria. The owner authorized the feature branch, commit and local merge into `develop`;
no push, tag, release or PR is implied. At that closeout, M20 remained not started and unauthorized.
**Planning revision (2026-10-24):** M20 now covers a full Settings layout redesign that preserves
existing functionality and a persisted active roster supporting one independently simulated pet
per unique bundled or installed character pack. M21 is the previously planned release pipeline.
The owner explicitly authorized end-to-end M20 on 2026-10-25 and accepted its closure on 2026-10-25
after testing the final autonomous animation-variation refinement. M20 is Done with retained evidence
limits: VoiceOver/keyboard, minimum supported window size, and matched Release resource evidence
remain unverified, and the package gate retains the known M15 V8 pixel-QA exception. The owner also
authorized branch commit, local merge into `develop`, and push; no tag, release or PR was implied
by that closeout. The owner subsequently authorized end-to-end M21 local implementation on
2026-10-25 and specified that no paid Apple Developer Program account will be used. M21 follows
the ad-hoc, non-notarized release policy in [release.md](docs/development/release.md), with
implementation/evidence in [m21-implementation.md](docs/planning/m21-implementation.md).
The M21 instruction authorizes its feature branch but no commit, push, tag, PR or release. See
[milestones](docs/planning/milestones.md),
[tasks](docs/planning/task-breakdown.md) and [acceptance criteria](docs/planning/acceptance-criteria.md).
Do not create a tag or publish a release without an explicit instruction to do so.

M21 is **Done by owner-directed local closeout** (2026-10-25): after receiving the implementation
and its evidence limits, the owner requested finalization and a complete README update. The
script/workflow/ZIP/checksum/tests/docs are delivered, with repeated validated diagnostic packaging.
At that local closeout, the existing V8 gate still blocked strict release; hosted dry-run and
clean-machine Gatekeeper behavior were unverified. Closure did not turn those criteria into passes, waive any release
gate, or authorize commit, merge, push, tag, PR or publication. See the
[M21 closeout](docs/planning/m21-implementation.md#owner-directed-local-closeout--2026-10-25).

**v1.0.0 publication follow-up (2026-10-25):** the owner subsequently explicitly authorized the
full Git integration/update, tag and public release process, with a ready-to-install download
linked from the README. This later instruction supersedes the original local-only Git/publication
boundary for this release. The owner separately authorized publishing v1.0.0 with the exact known
48-issue V8 pixel-QA exception disclosed (test and original assets unchanged), and confirmed art
redistribution in the app with art rights reserved and source MIT. See
[release policy](docs/development/release.md) and [ARTWORK-LICENSE.md](ARTWORK-LICENSE.md).
Official packages now use a universal arm64/x86_64 DMG plus ZIP alternative for macOS 14+.
The exception is opt-in, version-scoped and fails closed on any other failure; native Intel and
clean-machine Gatekeeper evidence are still not claimed. Never infer approval for future releases.

**Published:** [v1.0.0](https://github.com/danielcbdev/petscape/releases/tag/v1.0.0), build 10,
on 2026-10-25. [Hosted release validation](https://github.com/danielcbdev/petscape/actions/runs/40222864448)
passed all other gates from `c157cbf2dc31d69cc268b8de1b446a13d6211872`: 7 UI tests, 14 release-tool
tests, Debug/universal Release/archive and DMG/ZIP validation. Both full 573-test rounds retain
only the approved 48-issue V8 failure. The public README DMG download and checksum were tested
without authentication, with mounted inventory and both signatures verified. Native Intel and
clean-machine first-launch/Gatekeeper remain unverified. See the
[publication record](docs/planning/m21-implementation.md#public-release-and-download-verification--2026-10-25).

**v1.0.1 installation follow-up (2026-10-25):** the owner reported the Apple
verification warning, requested comparison/adaptation of MacDevClean distribution on a separate
branch, merge into develop, README correction and another public release. The owner separately
approved retaining the exact 48-issue V8 exception for v1.0.1/build 11. This authorizes branch,
commit, merge/push, tag and publication after all other gates pass; v1.0.0 remains immutable.
`feature/T21-installation-followup` adds verified Terminal download/DMG opening and native-readable
offline instructions, retaining ad-hoc signing and app-specific manual approval. No quarantine or
global security setting is changed. **v1.0.1/build 11 is published**, following
[run 40227041048](https://github.com/danielcbdev/petscape/actions/runs/40227041048) from
`a9db12f5c0be3d49a3e1252d58301f6ccfdaf400`; all other gates passed (7 UI/14 tooling tests).
The public DMG download, checksum, 216-file inventory, both signatures and native-readable guide
were verified. The owner's v1.0.0 warning is recorded; full clean-machine approval/relaunch and
native Intel remain unverified. See the [follow-up](docs/planning/m21-implementation.md#v101-installation-follow-up--2026-10-25).

**Final V8 visual approval (2026-10-25):** the owner subsequently closed and approved the existing
artwork after the 48 findings were explained. The remaining visual follow-up is closed by acceptance,
not pixel repair. [The exact baseline](docs/planning/v8-visual-acceptance.json) pins all 134 image
hashes and 48 findings. Every original pixel assertion still runs; only a matching approved
image/hash/criterion reports a strict, non-intermittent Swift Testing known issue. Changed assets,
new findings and disappeared expected issues fail. The historical release-only waiver is retired;
current packaging requires all gates to succeed. Existing release tags/artifacts remain historical.
See the [final closeout](docs/planning/m15-implementation.md#final-v8-visual-acceptance--2026-10-25).

**v1.0.2 publication authorization (2026-10-25):** after local V8 closeout, the owner explicitly
requested committing, merging into develop, then main, and the complete release process.
Target v1.0.2/build 12 includes the accepted visual baseline and retires the release-only waiver.
All canonical gates must succeed; original art and the v1.0.0/v1.0.1 tags/artifacts remain preserved.
See the [publication follow-up](docs/planning/m21-implementation.md#v102-v8-closeout-publication--2026-10-25).

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

- `PetScapeCore` imports only Foundation, CoreGraphics (geometry value types only) and `os`. Never AppKit, SwiftUI, QuartzCore, SpriteKit, ApplicationServices.
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
