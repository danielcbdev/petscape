# Requirements

Requirement IDs are stable and referenced from planning documents
([acceptance-criteria.md](../planning/acceptance-criteria.md),
[task-breakdown.md](../planning/task-breakdown.md)). Do not renumber; deprecate instead.

Priority: **MVP** (first release), **Next** (scheduled post-MVP milestone), **Future** (vision, unscheduled).

## Functional requirements

### MVP (milestones M2–M6)

| ID | Requirement |
|---|---|
| FR-01 | The app launches on macOS as a menu bar–only app (no Dock icon, no main window). |
| FR-02 | A menu bar icon exposes: Show/Hide pet, Pause/Resume, Quit. |
| FR-03 | The app creates a transparent, borderless overlay on the screen that hosts the pet. |
| FR-04 | One pet (the cat) is rendered in the overlay. |
| FR-05 | Animation frames are loaded from a character pack described by a declarative manifest. |
| FR-06 | The walk animation plays in a loop at the FPS declared by the manifest, independent of render rate. |
| FR-07 | The pet moves horizontally at a speed consistent with its walk animation. |
| FR-08 | The pet's horizontal movement is bounded by a computed walkable segment. |
| FR-09 | At a boundary the pet turns around automatically (mirrored sprite). |
| FR-10 | The pet is visually placed on top of the bottom Dock; falls back to the screen bottom when the Dock is hidden, absent, or not at the bottom. |
| FR-11 | Pause freezes animation and movement; Resume continues from the same state. |
| FR-12 | Hide removes the pet from the screen and stops rendering; Show restores it. |
| FR-13 | Quit terminates cleanly (windows closed, observers removed, no crash report). |
| FR-14 | Clicks on transparent regions of the overlay reach the apps and desktop underneath. |
| FR-15 | Missing or invalid assets never crash the app; the user sees a status message and a placeholder or fallback animation is used. |
| FR-16 | The MVP requires no special permissions (no Accessibility, Screen Recording or Input Monitoring). |
| FR-17 | The overlay follows screen configuration changes (resolution, scaling, display connect/disconnect, Dock size/position change). |
| FR-18 | Pause/hidden state is persisted across launches (UserDefaults). |

### Next (milestones M7–M20)

| ID | Requirement | Milestone |
|---|---|---|
| FR-20 | Gravity, falling and landing on surfaces. | M7 |
| FR-21 | Jumps between surfaces with takeoff/landing animations. | M8 |
| FR-22 | Autonomous behaviors: idle, sit, sleep/wake, stretch, observe, driven by internal needs and personality. | M9 |
| FR-23 | Settings window: size, speed, behavior toggles, launch at login, restore defaults. | M9 |
| FR-24 | Reaction to the cursor (look at, approach, startle). | M10 |
| FR-25 | Drag and drop of the pet with the mouse, including throwing and falling. | M10 |
| FR-26 | Climbing the left/right screen edges. | M11 |
| FR-27 | Detection of other apps' windows (opt-in, permission requested only when enabled). | M12 |
| FR-28 | Walking on window top edges, riding moving windows, reacting to closed/minimized windows. | M13 |
| FR-29 | Multiple displays: pets can live on and move between displays. | M14 |
| FR-30 | Signed, notarized DMG published on GitHub Releases. | M20 |

### Future (unscheduled)

| ID | Requirement |
|---|---|
| FR-40 | Multiple simultaneous pets. |
| FR-41 | Pet-to-pet interactions: meet, chase, play, sleep together, react to movements. |
| FR-42 | Additional characters selectable in Settings. |
| FR-43 | Dock on left/right edges used as a climbable vertical surface. |
| FR-44 | User-installed character packs from `~/Library/Application Support/PetScape/Characters`. |

## Non-functional requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-01 | Performance | Meet the targets in [performance.md](../specifications/performance.md) (CPU, memory, frame pacing, launch). Targets are validated by measurement, not assumed. |
| NFR-02 | Energy | No timers, polling or rendering while paused, hidden, display asleep, screen locked or overlay occluded. |
| NFR-03 | Stability | No crashes in an 8-hour soak test; recover from invalid states (lost surface, off-screen pet) automatically. |
| NFR-04 | Non-interference | Never steal focus or key status; never block clicks outside pet pixels; never move/resize/close other apps' windows. |
| NFR-05 | Privacy | No network access; no telemetry; no reading of window titles or screen contents. |
| NFR-06 | Security | Public APIs only; no code injection; Hardened Runtime; no private frameworks. |
| NFR-07 | Extensibility | New animations and characters are added via data (manifest + images) without changing engine code. |
| NFR-08 | Testability | Domain logic (animation timing, state machines, physics, behavior, geometry) is unit-testable without AppKit/Core Animation and with deterministic time and randomness. |
| NFR-09 | Compatibility | macOS 14 Sonoma or later; Apple silicon primary; Intel best-effort (see [ADR-0001](../decisions/0001-platform-baseline.md)). |
| NFR-10 | Accessibility | Menu and Settings fully usable with VoiceOver and keyboard; pets are decorative and hidden from the accessibility tree. |
| NFR-11 | Maintainability | Code follows [conventions.md](../development/conventions.md); no third-party runtime dependencies without an ADR. |
| NFR-12 | Observability | Structured OSLog categories and DEBUG-only visual diagnostics (see [debugging.md](../development/debugging.md)). |
| NFR-13 | Localization | UI strings are localizable from day one (String Catalog); English is the source language. |

## Constraints

- Distribution outside the Mac App Store (see [ADR-0010](../decisions/0010-distribution-no-sandbox.md)).
- No payments, subscriptions, authentication, backend, remote database, cloud sync, external telemetry.
- No LLMs controlling movement or behavior.
- Original files in `assets/` are never modified.

## M10 first-delivery scope proposal (2026-10-18)

The current owner brief narrows the first M10 implementation to bounded observation, primary
click, pickup and predictable zero-impulse drop. FR-24's approach/startle locomotion and FR-25's
throw impulse remain broader deferred requirements; their stable IDs and original text above
are preserved. Do not claim those original requirements fully satisfied by initial M10.
See [plan/approval decisions](../planning/m10-implementation.md#approval-decisions) and revised
[AC-M10](../planning/acceptance-criteria.md#m10--cursor--drag). Single-host clamping does not
satisfy FR-29 handoff. This is proposed scope documentation, not implementation acceptance.
