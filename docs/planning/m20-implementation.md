# M20 implementation record

Status: **Done by explicit owner acceptance, 2026-10-25**, with retained evidence limits. The owner
authorized end-to-end M20 on 2026-10-25, then confirmed the final autonomous animation-variation
refinement worked after testing and authorized branch commit, local merge into `develop`, and push.
Branch: `feature/T20-settings-multi-pet`. M21, tag, release and PR remain out of scope.

This record preserves the pre-M20 behavior audit, implementation decisions, test/build evidence,
manual verification and any remaining limits. The historical M18/M19 acceptance records are not
rewritten; M20 expands their one-active-character model.

## T20.1 — Pre-change behavior inventory

Inventory sources: `SettingsView`, `SettingsModel`, `CharacterSelectionModel`, `PetRuntime`,
`PetWorld`, `PreferencesStore`, `MenuBarContent`, the catalog/installer and the existing runtime,
platform and UI tests. This is a source/test audit; it does not claim a new native playtest.

| Area | Existing behavior and contract to preserve | Existing state, error, permission and persistence behavior |
|---|---|---|
| Character catalog/selection | Bundled and immediate installed folders are discovered by manifest ID, sorted stably, and selected through the M18 loader. First launch prefers `cat`; a saved valid ID is preferred after relaunch. Selection transactionally replaces only a settled pet. | Loading, unavailable-pack count, no-catalog placeholder, invalid/degraded load and unsafe-boundary feedback are modeled. `petscape.selectedCharacterID` stores the selected manifest ID. |
| Pack import | A native folder picker imports a local folder containing `character.json` and referenced PNGs. Import does not activate a pack. | Cancel is quiet; active selection is unchanged on failure. Progress, success and localized invalid/unsafe/size/duplicate/storage/copy errors are exposed. No network or extra permission is used. |
| Size and speed | Global sliders update `PetSettings`; scale is 0.5–1.5 and speed uses the shared 0.5–4 range. Runtime applies changes between fixed steps. | Stored in namespaced preferences; missing values use current defaults. |
| Pause, Hide, Wake | Pause and Hide are global menu/Settings actions. Wake applies to every pet currently in the world. | Pause/Hide persist and seed run state on launch; Restore Defaults clears these two keys. |
| Autonomous behavior | Global autonomy, jumping, resting and expressions toggles update Core settings. The state machine owns per-pet needs, choices, activity deadlines, cooldowns and transitions. | Missing autonomy toggles default enabled. Disabling an activity safely exits eligible states while preserving physical flight guards. |
| Manual Dance / Stop Dance | Manual dance requires autonomy, a visible running pet, a supported settled state, and the existing 5–30 second bound. Stop Dance performs bounded cleanup. Before M20, menu and Settings target the only/first pet. | Availability is dynamic; pending dance/cleanup art uses the manifest fallback and shows explanatory copy. M16 cleanup after a held drop is covered by existing tests. |
| Dance to music | Explicit consent precedes opt-in system-output audio access. Confirm enables the preference and detector; cancel leaves it off. Manual dance needs no audio permission. | Off/suspended/monitoring/unavailable states explain local-only analysis, supported OS, System Audio Recording and retry. Capture is retried only by explicit retry or the existing app-activation recovery path. |
| Launch at login | Toggle reads actual `LaunchAtLoginService` state and performs registration only after user action. | Enabled/disabled/approval-required/unavailable statuses and registration/unregistration errors are surfaced. Restore Defaults explicitly disables the login item. |
| Window interaction | Optional global opt-in reads window positions only; it does not move, click, close, resize, activate windows, or read titles/content. | Accessibility is checked only after opt-in. Missing access presents an explanation and confirmation; cancel disables the preference. Revocation is reflected in status. |
| Cursor and click/drag | Global preferences control cursor reactions and direct click/drag. Reduce Motion gates optional reactions; pause cancels interaction. | Defaults remain enabled for both preferences; changes are applied at runtime. A native pointer session owns one active gesture and is routed by `PetID`. |
| Dock offset | Global −40…+40 pt slider updates the Dock surface and attached pet placement. | Preference is clamped on read/write; Restore Defaults returns it to zero. |
| Language guidance | SwiftUI follows ordered macOS preferred languages: English or `pt-BR`; unsupported languages fall back to English. Settings advises restarting if a live change is not reflected. | No app-specific language selector or permission. All product copy belongs in the English/pt-BR String Catalog. |
| Restore Defaults | Resets pause, hide, Dock offset, scale, speed, autonomy, cursor/direct interaction, window interaction and music detection; applies them to runtime and unregisters launch-at-login. | It does not remove or reset the selected character, preference schema version, or unrelated/unknown keys. M20 keeps the roster as the corresponding content choice. |
| Empty/loading/import outcomes | Empty catalog shows an accessible message and placeholder pet; a populated catalog loads on launch. Import success does not select the newly installed pack. | Loading, quiet picker cancel, explicit success, validation failures and unavailable-pack count are already represented in the model/view and existing tests. |

Architecture audit: `PetWorld` already stores an array and `Pet` already owns physical, behavior,
interaction and animation state. The M20 gaps are single-character replacement, one world-wide RNG,
runtime-wide loaded-character ownership, family-load tasks keyed only by family, and unscoped manual
dance/menu availability. The fix keeps all logic inside the documented Core/Runtime/Platform/
Rendering/App boundaries; no new module, permission, dependency, or ADR-level boundary change is
needed.

## Implementation decisions

- Replaced the one-selection model with `CharacterRosterModel`; catalogs still keep validated metadata
  and pack URLs, and load decoded frames only for active characters. Import remains inactive until an
  explicit Add action.
- `petscape.activeCharacterIDs` is an ordered stable-ID list under preference version 4. Migration
  copies the old singular key once and removes it. `nil` means first launch, `[]` means an intentionally
  empty roster, invalid stored values fall through the documented default/lexical recovery, and
  Restore Defaults retains active characters.
- Core prevents duplicate active manifest IDs and each pet receives a separate seeded random stream.
  Add leaves existing simulation values untouched; remove filters only target-owned events. Runtime
  owns loaded characters, family tasks, dance availability and render lookup by PetID. Late work checks
  the exact PetID/LoadedCharacter identity before publishing.
- Manual Dance/Stop Dance is addressed by PetID in Settings and menu actions. Legacy no-argument
  Runtime calls act only when one pet exists. Shared music-start and global settings remain shared,
  while each active pet advances its own state and deadline.
- Settings uses a native sidebar with Pets, Behavior, Appearance, Interaction and General sections.
  Existing controls, consent and error/status copy remain available; roster rows add individual
  Dance/Stop Dance and Remove actions. No new permission, module, dependency, asset, schema or cap.
- During the two-display Core test, a newly added pet on a secondary window surface exposed that the
  simulation's visual range always used the first screen. The range now resolves against the pet's
  attached/target surface host, preserving per-display placement while keeping the same global points.
- The existing per-pack 16 MiB policy remains. The real Cat+Dimas integration reports combined
  initial decoded frame residency; this is not aggregate app memory. A two-pet XCTest measures Core
  fixed-step cost without setting a machine-sensitive threshold. Native Release CPU and process
  footprint still require their own matched comparison.

## T20.10 — User-requested autonomy variety refinement (2026-10-25)

The owner asked for less repetitive autonomous motion, more occasional jumps, and more visible
window climbs. Existing weighted selection now raises the average Jump weight from 0.7 to 1.2,
Explore from 0.8 to 1.0, and WindowExcursion from 0.6 to 1.5 (each retains its personality factor).
The window cooldown is 20 seconds, the top walk is 7–19 seconds, and the initial side contact is
targeted at 30% of the available span above its lower bound, with a 48 pt minimum ascent when
feasible. The pet still climbs and returns to the Dock through the existing M11/M13 states.
No new animation state, clip, asset, preference, or permission was added. Cat rest/expression states
continue to follow the pack's declared idle fallbacks.

Focused `WindowClimbTests` pass 4/4, including a seeded 256-world distribution check, lower side
contact, top-walk bounds, multi-window selection, and a complete Dock-return excursion. The updated
default cadence and climb height were not manually reviewed in the native app during this change.

## Verification and closeout

### Acceptance review

| Criterion | Result | Evidence and limit |
|---|---|---|
| AC-M20-01 | Partially verified | Native Settings hierarchy was reviewed at the observed default window size in English and `pt-BR`; all five sections and long copy were visible. Supported minimum-size resizing was not verified. |
| AC-M20-02 | Implementation reviewed; not a complete manual re-test | Existing control flows and persistence were audited against Settings/runtime/models/tests and the controls remain present. Restore Defaults was exercised in an isolated suite. The full list of permission, audio-consent, login-item, interaction and error flows was not re-run natively. |
| AC-M20-03 | Automated and partial native verification | Empty/one/many, real Cat+Dimas pack install, source labels and roster operations are covered by tests; native import/add, both Dance actions, targeted Stop Dance and removing Cat while Dimas remained active were observed. Manual restart with multiple pets was not done. |
| AC-M20-04 | Automated pass | Stable-ID uniqueness, duplicate add rejection and roster persistence/fallback paths passed the M20 preference/runtime tests in the package run. |
| AC-M20-05 | Automated pass; manual partial | Singular preference migration, explicit empty roster, invalid/duplicate recovery and round-trip are tested. Restore Defaults was manually confirmed to retain Cat while resetting global controls in an isolated preferences domain. |
| AC-M20-06 | Automated pass | Core/runtime tests cover add/remove without replacing the kept pet, scoped events/cancellation, stale loading results and removal in held, falling, preparing-jump, climbing, dancing and cleanup phases. No claim is made for an unlisted native phase. |
| AC-M20-07 | Automated pass | Deterministic tests exercise independent random choices/durations, movement/state/frame/dance timers and per-pet commands. |
| AC-M20-08 | Automated pass; partial native review | Shared music input fan-out and per-pet eligibility/timing are tested. Native manual Dance/Stop Dance targeting was observed. Audio consent/detection and global control semantics were not all re-tested in the native app. |
| AC-M20-09 | Automated pass | Runtime/render and real-pack integration coverage exercises distinct definitions/resources, per-PetID ownership, stale-load rejection and interaction/event routing. Native visual confirmation covered Cat and Dimas in the roster; it did not instrument hit masks or every display/surface. |
| AC-M20-10 | Partially verified | Existing 16 MiB per-pack limit is retained. The real Cat+Dimas integration reported 32,514,048 initial decoded-frame bytes; isolated Core fixed-step measurements are in [performance.md](../specifications/performance.md#m20-package-measurements-2026-10-25). A matched native Release CPU/process-footprint comparison was not run, so no aggregate app target is claimed and no arbitrary cap was added. |
| AC-M20-11 | Partially verified | String Catalog compilation/synchronization and English/`pt-BR` native review of all five sections, source labels and roster actions completed. VoiceOver and end-to-end keyboard traversal/focus order were not verified. |
| AC-M20-12 | Gates reported below | Formatting, lint, Debug/Release builds and focused M20 tests passed. `make test-core`/`make test` remain nonzero for the pre-existing M15 V8 pixel-QA exception; a separate final XCUITest run passed all 7 tests. Real Dimas installation and validation passed in a focused package test and native flow. |
| AC-M20-13 | Automated pass; owner manual pass | Seeded 256-world default-choice comparison increases both Jump and WindowExcursion selections over the previous weights. Side-contact height, 7–19 s top walk, 20 s cooldown and complete return are covered. The owner manually tested the revised autonomous variation and reported it worked perfectly on 2026-10-25. |

### Commands and automated results

| Command | Result |
|---|---|
| `make format` | Passed. |
| `make lint` | Passed after the final Swift changes. |
| `make test-core` | Failed only at the existing M15 `M15CharacterPackTests.newDrawingsAreDistinctOpaqueContainedAndRegistered` V8 pixel-QA test (48 recorded issues); no test or asset was skipped or changed to hide it. All M20 roster, preference, runtime, real-pack, platform, rendering, and new autonomy tests passed. Core reported 344 tests/33 suites, Rendering 50/10 suites and Platform 51/9 suites passed; Runtime reported 127 passing tests plus that one M15 test failure in a 128-test/13-suite run. The real Dimas + Cat integration passed and reported 32,514,048 initial decoded-frame bytes. |
| `make test` | Failed at its package-test prerequisite for the same 48-issue M15 V8 exception, so the Make target did not reach its UI-test phase. A separate UI command below was run after this prerequisite failed. |
| `xcodebuild -project PetScape.xcodeproj -scheme PetScape -destination 'platform=macOS' -derivedDataPath build/DerivedData SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES -configuration Debug build` (`make build`) | Passed. |
| `xcodebuild -project PetScape.xcodeproj -scheme PetScape -destination 'platform=macOS' -derivedDataPath build/DerivedData SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES -configuration Release build` | Passed. Xcode emitted its existing AppIntents metadata warning because the app has no `AppIntents.framework` dependency; there were no Swift compiler warnings. |
| `xcodebuild -project PetScape.xcodeproj -scheme PetScape -destination 'platform=macOS' -derivedDataPath build/DerivedData SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES -only-testing:PetScapeUITests test` | Passed on the closeout run: 7 UI tests across `PetScapeLaunchTests` and `PetScapeSettingsTests`, 0 failures. The suite covers launch/menu, import cancellation, installed/bundled roster, empty state, pt-BR, relaunch persistence, control changes and Restore Defaults. |
| String Catalog compile/sync | Passed; catalog has 148 entries and the English/`pt-BR` strings are present. |
| `swift test --package-path Packages/PetScapeKit -Xswiftc -warnings-as-errors --filter realDimasPackInstallsAndRunsBesideTheBundledCat` | Passed: 1 test/1 suite. The production installer/catalog flow loaded real `packs/human-programmer` Dimas alongside bundled Cat and reported 32,514,048 combined initial decoded-frame bytes. |
| `git diff --check` | Passed. `git status --short assets packs` is empty; original assets and pack files are unchanged. |

Closeout rerun (2026-10-25): `make build` and the Release `xcodebuild` command both passed;
`make lint` passed; `make test-core` and `make test` stopped on the same known M15 V8 pixel-QA
exception; the separate XCUITest command passed 7/7. `WindowClimbTests` passed 4/4 and
`AutonomyTests` passed 21/21. No asset or installed-pack source was changed.

The package measurement environment was an Apple-silicon M4 Mac, macOS 27.0.1 and Xcode 27.1.
Debug XCTest measured 600 Core fixed steps: one pet averaged 0.004 s (RSD 27.475%); two pets
averaged 0.007 s (RSD 35.075%). These coarse, high-variation test timings exclude AppKit, rendering
and whole-process memory, and are not a release CPU target comparison. The decoded-frame byte count
is likewise not physical process footprint. No concurrency cap was introduced.

### Native review and remaining owner checks

The detailed observed scenarios and environment are in the [manual matrix](../development/testing.md#m20-active-roster-and-settings-redesign).
English and Brazilian Portuguese Settings sections, isolated Dimas import/add, Cat+Dimas concurrent
roster controls, Dance/Stop Dance targeting, removal isolation, and isolated Restore Defaults were
reviewed. The fake login-item service was used for Restore Defaults, so the actual system login item
was not changed. The owner's normal preference domain and installed-pack directory were not used.

The owner accepted M20 closure with these retained evidence limits: supported-minimum window sizing,
keyboard/VoiceOver navigation, multi-pet native relaunch, full native consent/error scenarios, and
matched one-pet versus Cat+Dimas native Release CPU/physical-footprint comparison were not all
verified. These are accepted evidence limits, not passed criteria or remaining implementation tasks.
The initial XCUITest attempt
timed out enabling Automation Mode; a retry ran and passed all 7 UI tests without changing a privacy
permission. The known M15 V8 pixel-QA failure remains a package-gate exception, not an M20 product
failure.

## Owner closeout — 2026-10-25

The owner reported testing the revised autonomous activity mix and window climb and confirmed it
worked perfectly, then explicitly requested closure with a feature branch, commit, local merge into
`develop`, and push. M20 is accepted with the evidence limits above. No M21, tag, release, or PR was
authorized.
