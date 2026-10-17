# Testing Strategy

Principle: test **behavior that can break**, with deterministic inputs. No tests written only for
coverage numbers; no deleting or weakening tests to get a green build.

## Layers

| Layer | Framework | Where | What | Runs |
|---|---|---|---|---|
| Unit | Swift Testing | `PetScapeCoreTests` (bulk), other package test targets for pure helpers | Geometry/conversions, manifest decoding/validation, animation timing, state machines, physics, Dock estimation, surface map, behavior scoring, run-state logic, pass-through state machine | `make test-core` (seconds) |
| Integration | Swift Testing | `PetScapeRenderingTests`, `PetScapeRuntimeTests`, `PetScapePlatformTests` | Image decoding with fixture PNGs, frame image store + hit masks, `PetLayer` configuration from snapshots without a window, character loader end-to-end with a fixture pack, preferences store with an isolated `UserDefaults(suiteName:)`, runtime with fake frame driver/screens | `make test` |
| UI | XCTest (XCUITest) | `PetScapeUITests` | Launch, menu items and state labels, Settings (M9) | `make test` |
| Performance | XCTest `measure` + signposts | Runtime tests / manual | Simulation step cost, decode time | on demand / M14 |
| Manual | Checklist | PR description | Overlay, click-through, Dock alignment, Spaces, multi-display, sleep/wake | per milestone |

## Determinism

- Time: tests drive `world.step(dt:)` explicitly or use `ManualClock`; never `Date()`/`sleep`.
- Randomness: `RandomSource` injected; tests use `SeededRandomSource(seed:)` or a scripted source.
- Environment: screens, Dock estimates and surfaces are values constructed in tests.
- Platform: protocol fakes (`FakeScreenProvider`, `FakeFrameDriver`, `FakeHitTester`,
  `InMemoryPreferencesStore`).

## What to test per area

| Area | Key tests |
|---|---|
| Coordinates | list in [coordinate-system.md](../specifications/coordinate-system.md#unit-tests-t31) |
| Manifest | one fixture per validation code; the real cat pack validates; unknown fields tolerated |
| Animation | parameterized frame counts (8/12/16/24/32) × stepping (60/120 Hz) × modes; per-frame durations; multi-frame steps emit ordered events; pause = no advance; `next` chaining; fallbacks |
| State machines | every transition row; priority thresholds; stuck detection; recovery |
| Physics | walking speed and edge events; landing without tunneling (property test); moving/removed surfaces; jump solver accuracy; determinism with seed |
| Surfaces / Dock | estimator table; re-projection; diffs |
| Behavior | seeded scenarios (tired → sleep, startled → wake, no 3× repetition) |
| Run state | all combinations user intent × system state; accumulator reset on resume |
| Pass-through | enter/leave/drag sequences; drag keeps interactivity until mouse-up |
| Preferences | defaults, persistence, version migration, restore defaults |

Fixtures: under each test target's `Fixtures/` folder (JSON manifests, tiny PNGs generated for the
purpose — never modified copies of original art beyond what the test needs).

## UI tests

`PetScapeLaunchTests` (T2.7) launches the app, waits for `app.statusItems.firstMatch`, checks that no
window is open, opens the menu, clicks "Quit PetScape" and expects the process to end. **Not yet
verified (2026-10-16):** every run so far stopped before the test body with "Timed out while
enabling automation mode", so it is still unknown whether XCUITest can reach the status item. See
[setup.md](setup.md#ui-tests-and-automation-mode). If status items turn out to be unreliable, UI tests
cover only launch and Settings; menu behavior is covered by `AppModel` unit tests plus manual checks.

## Manual test matrix (MVP)

Record environment (see [proof-of-concept.md](../planning/proof-of-concept.md#environment-to-record-for-every-result)) and pass/fail per row in the PR.

| # | Scenario | Expected |
|---|---|---|
| 1 | Dock bottom, default size | Cat on shelf (±3 pt after offset) |
| 2 | Dock small / large, magnification on | Same offset; walking unaffected |
| 3 | Dock autohide on | Cat on screen bottom; Dock reveal works normally |
| 4 | Dock left / right | Cat on screen bottom |
| 5 | Resize/move Dock while running | Cat re-settles within 1 s |
| 6 | Different scaling (More Space / Larger Text) | Correct size and placement |
| 7 | Retina + external non-Retina display; disconnect while running | Cat stays on Dock screen; no crash |
| 8 | Secondary display left/above (negative coordinates), Dock on secondary | Correct placement |
| 9 | Switch Spaces, Mission Control, App Exposé | Overlay stable; not listed as a window |
| 10 | Stage Manager on | Click-through intact |
| 11 | Fullscreen app | Cat not visible over it |
| 12 | Sleep/wake, lock/unlock, display sleep, fast user switching | No rendering while away; resumes without jumping |
| 13 | Click-through matrix (AC-14) | All events reach targets |
| 14 | Click cat; type in frontmost app | Focus unchanged (AC-21) |
| 15 | Missing/corrupt manifest (dev build) | Status message + placeholder; no crash |
| 16 | No permissions requested | Privacy panes have no PetScape entry |
| 17 | Quit from menu | Exits cleanly |

Post-MVP milestones extend this matrix (drag, climbing, windows, multi-display).
