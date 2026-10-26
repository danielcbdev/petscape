# M21 — Ad-hoc release pipeline

Authorized on 2026-10-25 for local implementation only. No commit, push, tag, PR or release is
authorized. Pre-existing planning/policy changes in the working tree are preserved.

## Design and execution plan

Use `scripts/release.sh VERSION BUILD [--rehearsal]` as the single local/CI entry point. Keep
`Config/Base.xcconfig` development defaults; pass release versions as build settings. Stable
three-component versions and positive increasing integer build numbers are validated before work.
Versioned changelog sections or the explicitly unreleased changelog supply the notes.

Choose ZIP over DMG: system `ditto` preserves the signed app hierarchy without mounting a disk
image or introducing layout tooling. Include notes, installation guidance and an internal SHA-256
inventory of bundle files; publish an external ZIP checksum alongside it. Extract with `ditto`,
verify both inventories, metadata, original referenced resources and ad-hoc signature again.
Repeatable means the same process and verified contents, not byte-identical Xcode archives.

Default release mode requires a clean checkout and every gate to pass. Rehearsal accepts local
edits, runs every gate, and may create an explicitly diagnostic package after quality-gate failures;
it still exits nonzero and can never be used by the publishing job. Structural, signing, version,
archive and checksum failures always abort packaging. No asset or test exception is waived.

1. T21.1–2: inspect identity/toolchain/visibility, validate inputs and changelog; add failure tests.
2. T21.3–4: canonical gates, Release archive, strict bundle checks, ZIP/checksums and extraction.
3. T21.5: manual dry-run workflow, immutable actions and separate opt-in draft publication job
   for an already existing `vVERSION` tag at the selected `main` commit; never create tags.
4. T21.6: English repository documentation and bilingual packaged installation instructions.
5. T21.7: run local gates, controlled failures, archive/package rehearsals and record exact evidence.

Review focus: unsafe version/path input; missing or altered assets; metadata/signature mismatch;
checksum corruption; gate failure reaching publication; tag/source mismatch; stale output reuse.
Tests exercise these boundaries without changing original assets. Remote Actions and clean-machine
Gatekeeper testing require external evidence and must stay unverified until actually run.

## Evidence

Local implementation and verification complete, with the failed/external gates below retained.
Environment: macOS 27.0.1, Xcode 27.1 (27A9275),
Apple silicon. Repository `danielcbdev/petscape` is PUBLIC (GitHub CLI read-only query).
The official macOS 26 runner inventory includes Xcode 26.2; the workflow uses that stable
Swift 6.2 toolchain, with a local Xcode 26+ fallback. No remote workflow was dispatched.

## Delivered scope

| Task | Local implementation |
|---|---|
| T21.1 | Existing bundle ID retained/validated; public repository/Actions visibility and official runner/toolchain inventory checked; no-cost Apple signing policy retained |
| T21.2 | Deterministic version/build/changelog checks; version/build passed only as build settings; current unreleased notes and history separated |
| T21.3 | Single shell/Python entry point, canonical gates, Release archive, explicit ad-hoc signing without injected debug entitlements, signature/bundle validation |
| T21.4 | arm64 ZIP using system `ditto`, complete signed app, notes/install/source-license text, internal inventory, external checksum and fresh extraction round-trip |
| T21.5 | Manual workflow; same strict script; seven-day artifacts/logs, public-repo preflight, immutable actions, read-only build token and isolated opt-in draft job for an existing main tag |
| T21.6 | English process docs and English/pt-BR install/upgrade/troubleshooting/security copy, with real OS-evidence limits and no security-policy bypass |
| T21.7 | Local gates, controlled integrity failures, code review and rehearsal evidence below; hosted dry-run and clean-machine observations remain external verification |

No app, package code/tests, character originals, Xcode configuration or development CI was changed.
The initial pre-existing policy edits remain present. Development version defaults stay `0.1.0`/`1`;
candidate values are command-line overrides, not a claim that v1.0.0 was released.

## Controlled failures and review

- Nine release boundary tests pass (exit 0). They cover unsafe/noncanonical versions and builds,
  missing/empty changelog, bounded note extraction, changed/missing/extra inventory files, missing or
  changed character resources, traversal, CLI early failure, wrong bundle version/signature and
  strict failure before archive. New implementation and note-extraction/English-fallback corrections
  were exercised through failing then passing tests.
- Real `codesign --verify --deep --strict` on a temporary copy returned 0 before tampering and 1
  after changing its Info.plist. No original app/source asset was modified.
- Real `shasum -a 256 -c` returned 0 for matching bytes and 1 after corruption. Test harness exit 0:
  `build/m21-controlled-checks.log`.
- Invalid version/build, strict dirty checkout and an existing rehearsal output directory each
  returned 1 before packaging. Output is never overwritten. Positive candidate inputs proceed to
  actual Xcode archive and resource/signature checks.
- `bash -n scripts/release.sh`: exit 0. Local actionlint 1.7.12 on the workflow: exit 0; ShellCheck
  was unavailable and disabled explicitly. Its binary was downloaded into ignored `build/m21-tools`
  from the official release and matched that release's SHA-256 list; no project dependency added.
- Independent read-only review found no actionable code defects and confirmed artifact path,
  failed-gate isolation, tag checks and token-permission boundaries. It did not treat local review
  as hosted or Gatekeeper evidence.
- `git diff --check` and the scoped check of 33 new/changed Markdown targets returned 0. An
  exploratory scan including all historical milestone links returned 1 for two pre-existing M18
  filenames (`BundledCharacterCatalog.swift`, `CharacterSelectionModel.swift`) superseded by M20;
  those historical references were left unchanged during implementation. The owner's subsequent
  documentation-finalization request corrected them to explicitly labeled current successors.

## Local gate and artifact results (2026-10-25)

The first full rehearsal (`1.0.0`, build 2) ran lint/Debug/Release/archive/asset-copy successfully,
then correctly stopped at an overstrict new validator assumption: Xcode emits English source-key
fallbacks without `en.lproj/Localizable.strings`. The validator now requires the real bundle contract:
both localized InfoPlist files and the translated pt-BR Localizable strings. A regression test
demonstrated the former rejection and passes with that correction. No product translation/resource
was removed. Build 2 did not produce a ZIP; its script exit was 1.

| Gate | Build 2 exit/result | Build 3 exit/result |
|---|---|---|
| `make lint` | 0 | 0 |
| `make test-core` | 2; V8 48 issues plus three unchanged runtime tests with six assertions | 2; V8 48 issues only |
| `make test` | 2; V8 48 issues, stops before UI | 2; V8 48 issues, stops before UI |
| `make build` | 0 | 0 |
| Release `xcodebuild … build` | 0 | 0 |
| Release-script tests | 0; 8 tests then present | 0; 9 tests |
| Separate unchanged `xcodebuild … Debug test` | 65; 6/7 UI pass, navigation hit-point failure | 0; 7/7 pass |
| Manifest asset-copy/parity | 0 | 0; complete referenced bundle inventory |
| Release archive | 0 | 0 |
| Complete release script | 1; validator stopped before ZIP | 1; diagnostic ZIP validated, failed gates still block publication |

Each package invocation ran 573 tests: Core 344, Platform 51, Rendering 50 and Runtime 128.
The build 3 package runs fail only `newDrawingsAreDistinctOpaqueContainedAndRegistered` with the
existing 48 V8 issues. No test or original art was changed, skipped or weakened. In the first
`make test-core`, `heldIdleStopsFramesAndJumpWakesTheSameDriver`,
`debugTargetCommandPreservesIdleIntent` and `realIdleLoopAtLowerCallbackRatesKeepsSimulationTime`
also failed (six assertions). They passed in the following full runs; no root cause is claimed.
Build 2 UI failed `testSettingsNavigationControlsAndRestoreDefaultsKeepTheRoster` at line 92:
“Unable to find hit point for ScrollView”. Build 3's full UI retry passed; the earlier failure is
retained, not recast as a pass. These product tests predate M21 and have no diff.

Debug/Release/archive emit no Swift compiler warnings. Xcode's existing AppIntents metadata warning
(`Metadata extraction skipped, no AppIntents.framework dependency found`) remains when extraction
runs. Xcode also reports `Using the first of multiple matching destinations` for the canonical
`platform=macOS` destination (arm64/x86_64 candidates on this Mac); the actual packaged executable's
architecture is explicitly checked as arm64. These tooling diagnostics are retained, not counted as
a zero-tool-warning result.
Logs are under ignored `dist/rehearsal/PetScape-1.0.0-{2,3}-arm64/logs/`; every phase's exact exit
code is in its `results.json`. Top-level transcripts: `build/m21-rehearsal.log` and
`build/m21-rehearsal-3.log`.

Build 3 produced `dist/rehearsal/PetScape-1.0.0-3-arm64/PetScape-1.0.0-3-arm64.zip` (about 44 MiB),
with SHA-256:

```text
f75b32396b7ca20035841e2393200913254b16b502e01de1a6dd8b71368840b9
```

`shasum -a 256 -c SHA256SUMS`: exit 0 (`OK`). Internal inventory contains 213 files, and its
verification after fresh `ditto` extraction returns 0, including `shasum -a 256 -c CONTENTS.sha256`.
Both archived and extracted `PetScape.app` pass `codesign --verify --deep --strict` (exit 0), version
1.0.0/build 3, bundle ID `io.github.danielcbdev.petscape`, macOS 14.0 minimum and arm64 executable.
Signature output records `Signature=adhoc`, `TeamIdentifier=not set`, no Authority and no
entitlements; flags are `0x10002(adhoc,runtime)`. This is integrity evidence only, not Apple trust.

### Repeated final rehearsal — build 4

`scripts/release.sh 1.0.0 4 --rehearsal` repeated the entire process into a new output directory.
Lint, Debug, Release build, nine script tests, all 7 UI tests, character validation and Release
archive each returned 0. `make test-core` and `make test` each returned 2 for only the unchanged
48-issue V8 test. Signature/bundle validation, external checksum and extracted 213-file inventory
all passed again. The script returned **1**, preserving the publication block.

The second independently built/packaged ZIP is
`dist/rehearsal/PetScape-1.0.0-4-arm64/PetScape-1.0.0-4-arm64.zip`:

```text
8bdc8c1bce716098a564c3fed803e0a6e84dc8af7a1155ebb9cbef77f9d80099
```

Transcript: `build/m21-rehearsal-4.log`; phase logs and `results.json` are in the matching `logs/`.
Its archived and extracted app again report ad-hoc signing, no developer team, no entitlements,
version 1.0.0/build 4, the existing bundle ID and arm64. Builds 3 and 4 demonstrate repeated local
archive/package/round-trip execution without a source/config/asset/app-test diff. Their hashes
differ because the build metadata and archive outputs differ; bit-identical artifacts are not promised.
Build 4 is the final diagnostic artifact, **not for publication**.

## Acceptance evidence

| Criterion | Recorded scope |
|---|---|
| AC-M21-01 | Local Release archive/diagnostic ZIP pass; hosted run unverified, strict package blocked by the existing test gate |
| AC-M21-02 | Archived and extracted ad-hoc signatures validated; no developer/Apple identity claim |
| AC-M21-03 | ZIP, notes/install copy, internal inventory, external checksum and local extraction validated; actual downloaded clean-Mac copy is not claimed |
| AC-M21-04 | Input rejection, no source-config mutation, same local/CI script and two successful local archive/package round-trips recorded above |
| AC-M21-05 | Workflow/actionlint/permissions/runner/action references reviewed locally; hosted dry-run not executed |
| AC-M21-06 | Default-off manual publication, existing tag at main commit checked twice, no remote publication/tag/push performed |
| AC-M21-07 | Bilingual installation/security guidance reviewed against Apple documentation; actual warning path remains unverified |
| AC-M21-08 | Clean supported macOS download/install/first-launch unavailable and unverified; failed V8 gate remains explicit and blocking |

Only macOS 27.0.1/Xcode 27.1 was exercised locally. No clean macOS VM, macOS 14–26 machine,
managed-device policy, native downloaded-app upgrade or Intel runtime test was available. No
Gatekeeper alert/override was observed or tested: the artifact was built/extracted, not downloaded
and opened on a clean system. No `spctl` success is claimed. No M21 hosted CI was run.

## Owner-directed local closeout — 2026-10-25

After receiving the implementation report and the explicit V8/hosted/clean-machine limitations,
the owner directed: “pois finaliza tudo, deixa no jeito e atualiza o readme com tudo que precisa
estar lá”. This closes **the local M21 delivery** by owner direction, with those limitations
retained. It does not assert that the owner ran a new test or that unverified criteria passed.

The README now covers current product features, requirements, source quick start, all five Settings
sections, independent active pets, local pack installation/removal, privacy and optional consent,
ad-hoc ZIP installation/checksums, development commands, strict/diagnostic release modes, manual
workflow boundaries, architecture, troubleshooting, contribution guidance and the unresolved art
license. Obsolete single-pet and Settings/Advanced instructions were replaced with current behavior.
The setup guide's character-pack instructions were synchronized with the active-roster UI.
Broken historical source-file links in the milestone register now identify their current
successors without rewriting the M18 implementation history; stale M10/M15/M20 anchors in
the touched documentation were corrected.

M21 is **Done by owner-directed local closeout** with no remaining local implementation or
documentation task. The failed V8 gate, prior transient failures, hosted dry-run and clean-machine
evidence gaps remain recorded. Strict CI/publication gates are unchanged and continue to block a
release. No commit, merge, push, tag, PR, workflow dispatch or release is authorized by this
finalization instruction; none was performed. External verification/publication actions below stay
separate from local milestone completion.

Fresh finalization checks (documentation-only follow-up): `make lint`, all 9 release-tool tests,
`bash -n`, local actionlint, `git diff --check`, and the 197-link/path/anchor/README-image check
returned 0. Fresh extraction of build 4 again passed the ZIP checksum, complete file inventory,
metadata/resource checks and ad-hoc signature verification. App/package tests and native builds
were not repeated for this documentation-only edit; their recorded failed/passed results above
remain unchanged. The app, its tests, original assets, Xcode config and development CI still have
no diff. No fresh clean-machine or hosted success is claimed.

## Remaining owner/external verification

Historical checklist from the local-only closeout. The owner subsequently authorized Git/tag/release
actions, explicitly approved the v1.0.0 V8 exception and resolved D-08; the publication follow-up
below supersedes those authorization prerequisites. Native/clean-machine evidence remains unverified.

These are verification/publication actions, not missing M21 implementation:

1. Resolve the existing package-gate failure under a separately scoped product/art task; do not
   waive it in the release script. Re-run `make lint`, `make test-core`, `make test` and `make build`
   and expect exit 0. Intermittent unchanged runtime/UI failures below also require a green actual
   run; a retry does not erase an earlier failure.
2. After separately authorizing integration/push of this work, from a clean checkout run
   `scripts/release.sh 1.0.0 5` (or a fresh version/build greater than every distributed build).
   Expect all gates and archive/round-trip checks to return 0 and output under `dist/release/`.
   No automatic publication follows this command.
3. After separately authorized integration/push makes the workflow available on the default branch
   (`main`), dispatch a hosted **dry run**, for example
   `gh workflow run release.yml --ref main -f version=1.0.0 -f build=5 -f publish=false`.
   Expect a successful strict package job and a downloadable `petscape-release` artifact, with no
   new tag/release. Inspect `gh run list --workflow release.yml` and `gh run view RUN_ID --log-failed`.
   If a gate fails, expect logs only. No such dispatch occurred in this implementation.
4. On a clean Apple-silicon Mac with supported macOS, obtain the ZIP and checksum through the intended
   download channel. Run `shasum -a 256 -c SHA256SUMS`, extract, then run
   `shasum -a 256 -c CONTENTS.sha256` inside the extracted folder: expect `OK` for every entry.
   Follow [installation instructions](../development/install.md), record exact OS/security policy,
   actual warning and whether the OS offers manual approval, then menu-bar launch and quit.
   Record absence of an override/block honestly; do not change global policy or strip quarantine.
   Repeat upgrade/preferences/optional-consent checks on an installed copy.
5. Before any public art distribution, resolve D-08 provenance/license and review dated release notes.
   Tag creation and publication require a new explicit owner instruction. This implementation
   creates neither; the opt-in job only creates a draft for an already existing matching main tag.

## v1.0.0 publication follow-up — 2026-10-25

After local closeout, the owner explicitly requested the full Git process, branch updates and a
public release containing a downloaded installer, with a complete installation path in the README.
This authorizes commit/integration/push, an existing-main-commit v1.0.0 tag and public release.
It supersedes the original local-only publication boundary for this release.

The owner separately answered: **“Publicar com exceção V8 documentada”** and confirmed redistribution
of all included art in the app, **with art rights reserved and source MIT**. Decision D-08 is now
recorded in `ARTWORK-LICENSE.md`; original provenance and artwork remain unchanged. This is owner
authorization, not an independent legal/provenance audit. The exact release exception is versioned
in `docs/development/release-exceptions.json` and is default off in CLI/workflow operation.

Publication changes:

- Universal arm64/x86_64 build/archive and per-slice signature checks, macOS 14.0 minimum.
- Primary compressed read-only DMG with fixed Applications shortcut; optional ZIP and complete
  internal inventory. Mounts are validated read-only and automatically ejected in `finally`.
- Per-format `.sha256` files avoid requiring both downloads to check only one format; combined
  `SHA256SUMS` still checks both.
- README now leads with the direct DMG download and ordinary Finder install steps, no developer
  checkout or Xcode. Source instructions remain in their development section.
- Full canonical test runs remain red for V8. Opt-in release validation requires the complete
  573-test report with only the known named failure and exactly 48 issues; unrelated failures,
  missing/changed summaries or compiler/signal errors block. UI runs separately and must pass.
  Raw exit codes and applied exceptions are separately recorded and disclosed in release notes.
- Both source and art notices, and an applied-exception record, accompany the actual release.

Fresh local checks before Git integration: the universal Release build succeeds with both lipo
slices, a real DMG creation/mount/inventory/per-slice signature/eject probe passes, all 13 release
boundary tests pass and actionlint/shell syntax pass. The full package run still fails only V8.
The universal diagnostic build 6 produced valid DMG/ZIP files but correctly exited 1: its UI phase
timed out while enabling Automation Mode. `DevToolsSecurity -status` reported developer mode
disabled. This is not a passed UI run and is not covered by the V8 exception. The separately run
native and hosted results must be recorded honestly before publication. Native Intel and clean
download/Gatekeeper testing remain unavailable; cross-compilation/mounting do not imply those pass.

A separate local UI attempt also stopped during Automation Mode initialization; no test bodies ran.
`sudo -n DevToolsSecurity -enable` could not run without an administrator password; no development
security setting was changed. Authorized Git integration will make the manual workflow available
on main so the public hosted runner can supply actual UI/build/package evidence before publication.
No additional UI failure or missing native test is waived by the V8 policy.

Initial remote compatibility check: development CI run `40218587264` failed to compile the existing
M16 decoded-memory assertion with Swift 6.2 (`#expect` type-check timeout at M16CharacterPackTests.swift).
The same arithmetic and exact equality are preserved, but expected and actual byte counts are
now separately typed before the macro. No threshold/test count was changed; the V8 test and art
remain untouched. Release dry run `40218628452` was cancelled after this concrete blocking defect
was diagnosed, so its cancellation is not a successful package/UI result. A fresh committed run
must validate the compatibility repair before any tag or public release.

The repaired Swift 6.2 run (`40218879405`) compiled, then exposed main-actor starvation in two
FullScreenSpaceDetector notification tests (three assertions). Swift 6.2 runs all 573 tests in one
process; synchronous image QA delayed notification task scheduling beyond the helper's two-second
wall deadline. The existing condition wait now bounds 400 polling opportunities instead of wall
time spent blocked by other tests. Every callback/state assertion remains unchanged; this is not a
latency test or a waiver. Release run `40218905502` was cancelled while this blocking race was
addressed. The report validator now supports both exact complete layouts: Swift 6.2's 573 tests/65
suites aggregate, and Swift 6.4's four-module summaries. Both still require only V8 with 48 issues.

Run `40219644927` confirmed both complete package runs now fail **only** V8 (48 issues); the exact
exception matcher accepted both. It then blocked normal packaging because Xcode 26's implicit
`-suppress-warnings` for local SwiftPM packages conflicted with explicit `-warnings-as-errors` in
Debug, Release and UI builds. All three raw failures are retained in its uploaded logs. Canonical
Makefile and release Xcode commands now explicitly set `SWIFT_SUPPRESS_WARNINGS=NO`; warning
enforcement stays enabled. A canonical `make build` preflight was added before the long hosted
test sequence so further toolchain incompatibilities fail early. No additional gate was waived.

The fail-fast run `40220682699` resolved that flag conflict and then exposed a Swift 6.2.3 compiler
IRGen crash in SettingsView: the demangled thunk converts an actor-isolated Sendable Bool setter
into a generic indirect Bool setter. The direct Bool method/function references passed to Binding
now use forwarding closures; the existing MainActor/Sendable annotations, model intents, labels,
IDs and assertions remain unchanged. This is a compiler-compatibility repair, not a release-gate
exception. Local and fresh hosted builds must validate it before publication.

Run `40221129574` confirmed the Bool thunk was eliminated, then exposed the identical compiler
defect for a Double setter (`$sSdScA_pSgIeAghyg_SdIeAghn_TR`). The same forwarding pattern is now
applied to Size, Speed and Dock offset bindings, preserving their values/ranges and model actions.

Run `40221461065` passed the Debug build and all 7 hosted UI tests, and both 573-test package rounds
again failed only the approved V8 test. Optimized universal Release compilation exposed Swift 6.2
losing the implicit default-isolation metadata for MusicDetectionController's isolated deinitializer
when imported into Runtime. Its class now explicitly declares the same existing MainActor isolation;
cleanup and callback behavior are unchanged. `make build-release` centralizes the strict universal
Release gate and runs alongside Debug in the hosted preflight, before the longer test rounds.

### Successful hosted release validation — 2026-10-25

[Release run 40222864448](https://github.com/danielcbdev/petscape/actions/runs/40222864448)
completed successfully from clean source commit `c157cbf2dc31d69cc268b8de1b446a13d6211872`.
The runner reported macOS 26.6.2 (25G83), Xcode 26.2 (17C52) and Swift 6.2.3, arm64 host.
The optimized isolation repair passed both the early Debug/universal Release preflight and the
later canonical Release build/archive. A separate read-only code review found no release blockers.

| Gate | Actual result |
|---|---|
| Lint/module boundaries | Exit 0 |
| `make test-core` | Exit 2; complete 573 tests / 65 suites, only named V8 failure, exactly 48 issues |
| `make test` | Exit 2 at the same complete package report; UI therefore runs separately |
| Debug build | Exit 0 |
| Universal Release build | Exit 0 |
| Release tooling unit tests | Exit 0; 14/14 pass |
| Separate native app/UI suite | Exit 0; 7/7 pass |
| Character copy/resource parity | Exit 0 |
| Universal ad-hoc archive | Exit 0 |
| DMG/ZIP integrity and round-trips | Pass; both native slices, signatures, metadata, resources and checksums |
| Exception review | Only `test-core` and `test` approved for the exact V8 failure; `blockingGates: []` |

This is successful release validation under the explicit v1.0.0 exception, **not** an all-green
package/development CI result. The original V8 test/art remain unchanged. Xcode emits its
AppIntents metadata-extraction and signed-XCTest-library stripping notices; those tooling notices
are retained rather than described as zero-warning logs. Compiler warnings remain errors.
The hosted UI result does not erase the earlier local Automation Mode timeouts.

The actual downloaded CI artifacts were independently checked on the owner's Mac: both external
SHA-256 sums passed; DMG verification/read-only mount/eject and ZIP extraction passed; each payload's
215-file inventory, original character resource hashes, version 1.0.0/build 10, arm64/x86_64 slices,
per-slice ad-hoc signatures, source/art licenses and recorded V8 exception matched. The application
was not launched by this integrity check, and no OS security setting was changed.

| Artifact | SHA-256 |
|---|---|
| `PetScape-1.0.0-10-universal.dmg` | `04c79840756d2dd6db6abd002814e592b5564d142fb144d32e70dcff554362f5` |
| `PetScape-1.0.0-10-universal.zip` | `ff5f474ed51a2deded2e658ee909f8ec68d310483bc4488604c4dd5b794bc0c0` |

Hosted logs/artifacts are retained for seven days by the workflow; this record preserves their
identities/results beyond that retention period. Native Intel execution, a clean installation on
macOS 14–26, actual downloaded-app Gatekeeper approval, upgrade/login/permission playtests remain
**unverified**. No cross-compilation or integrity result is presented as those manual tests passing.

### Public release and download verification — 2026-10-25

- **Release:** [PetScape v1.0.0](https://github.com/danielcbdev/petscape/releases/tag/v1.0.0),
  published at `2026-10-25T19:04:20Z`, latest stable release (`draft=false`, `prerelease=false`).
- **Tag:** annotated `v1.0.0`, tag object `380adf93a038b22a2d2f7d06c15f2befe5eb2806`, pointing to
  the exact tested source commit `c157cbf2dc31d69cc268b8de1b446a13d6211872`. It was created and
  pushed only after the authorized hosted validation passed. It is not moved for documentation.
- **Publication:** the dry-run workflow created no release. Its six verified artifacts were
  downloaded, independently validated locally, uploaded to a draft via `gh release create
  --verify-tag --draft`, inspected for expected names/sizes/server hashes, then explicitly published
  via `gh release edit --draft=false --latest` under the owner's instruction. No rebuild substituted
  untested bytes. The optional workflow publication job was skipped in this run.
- **Assets:** universal DMG (48,492,493 bytes), ZIP (46,586,022 bytes), each format's `.sha256`,
  combined `SHA256SUMS` and `RELEASE-NOTES.md`. GitHub's reported binary SHA-256 values match the
  downloaded CI files and the table above. Both license notices and the V8 exception are inside
  each package. Original `assets/` have no diff from the pre-M21 baseline `09751a7`.
- **Public installation entry point:** the README's exact
  [DMG URL](https://github.com/danielcbdev/petscape/releases/download/v1.0.0/PetScape-1.0.0-10-universal.dmg)
  and matching `.dmg.sha256` were downloaded with ordinary unauthenticated `curl`, without `gh`,
  a token, a source checkout or the ZIP. `shasum -a 256 -c` returned `OK`; the mounted DMG inventory,
  version/build, resources and both ad-hoc signatures passed again, and the volume was ejected.
  This verifies public delivery/integrity, not clean-machine launch or Gatekeeper acceptance.
- **Git integration:** the M21 feature branch was committed and fast-forwarded into `develop`
  and `main`; all three branches are synchronized with their remote counterparts. The final
  documentation-only commit records the actual release evidence after the immutable tagged build.
  Historical branches, unrelated worktrees and existing source/art were not force-updated/deleted.
  No pull request was needed for this authorized direct integration.
- **Remaining limits:** native Intel execution, clean supported-macOS installation/first launch,
  downloaded-app Gatekeeper approval and installed upgrade/login/permission playtests remain
  unverified. The exact V8 test remains failed and disclosed; normal strict/development CI still
  reports that failure. Publication does not approve future version exceptions.

## v1.0.1 installation follow-up — 2026-10-25

The owner reported: “A Apple não pôde verificar se o item PetScape.app está livre de algum malware
capaz de danificar o Mac ou comprometer sua privacidade.” They requested comparison with
[MacDevClean](https://github.com/danielcbdev/mac-dev-clean), changes on a separate branch, merge
into develop, a corrected README and the full release process again. The owner separately answered
**“Sim, manter a mesma exceção na v1.0.1”** for the unchanged 48-issue V8 test. Target v1.0.1,
build 11; no future version is authorized by this exception.

### Investigation and chosen change

- Read the reference README, `build-local.sh`, `package-dmg.sh`, `verify-artifact.sh` and manual
  installation document in full. Downloaded the actual v1.0.1-unsigned DMG and inspected its app
  without running it: `Signature=adhoc`, `flags=adhoc,linker-signed`, `TeamIdentifier=not set`,
  no Developer ID authority. The temporary volume was ejected after inspection.
- Both projects ship universal compressed DMGs with an Applications shortcut and no Apple
  notarization. PetScape's prior checks validated integrity, not Gatekeeper acceptance. The
  reference cannot supply a missing Apple identity or notarization ticket.
- MacDevClean leads with Terminal `curl` download/checksum/open commands and manual approval.
  Its older Control-click guidance is not a dependable path on every current macOS release;
  [Apple's current article](https://support.apple.com/en-us/102445) uses Privacy & Security →
  Open Anyway after an attempted launch. The owner did not record OS/download metadata/prior
  approval, so the exact difference in their two experiences remains an inference, not a result.
- Adopt the reference download flow using HTTPS-only redirects and dependent commands, preventing
  image opening after a failed download or checksum. Place the exact Apple warning and the
  bilingual app-specific approval steps before first use in README/install instructions.
- Include `INSTALL-FIRST.txt` in DMG/ZIP, byte-for-byte from canonical bilingual `install.md`, so
  Finder/TextEdit users can read the instructions offline without a Markdown viewer. The existing
  full inventory covers it. No app code, signature trust policy, assets, preferences or permissions
  change. No global security/quarantine operation is introduced.
- Implementation branch: `feature/T21-installation-followup`, based on synchronized develop.
  T21.4/6/7 follow-up only; authorized Git/publication continues after validation.

### Verification in progress

The updated exception-boundary test was first observed failing against the old 1.0.0-only validator,
then passed after the explicit 1.0.1-only change. All 14 release tooling tests pass locally,
including rejection of missing/revoked approval, 1.0.0, 1.0.2 (even with a changed policy version),
and changed issue count. The original V8 test/art are untouched. Hosted gates, artifact/download
verification and publication identities will be recorded below when actually completed.

The owner's v1.0.0 warning is recorded as observed owner feedback, not a successful clean-machine
approval/relaunch. Native Intel, old supported OS, managed-device policy and full clean-machine
first-launch remain unverified. No unnotarized package promises a universally available override.

### v1.0.1 hosted and installer verification — 2026-10-25

[Run 40227041048](https://github.com/danielcbdev/petscape/actions/runs/40227041048) completed
successfully on the feature branch from clean commit
`a9db12f5c0be3d49a3e1252d58301f6ccfdaf400`, with macOS 26.6.2 (25G83), Xcode 26.2 (17C52),
Swift 6.2.3 on arm64. The optional publish job was skipped: validation created no release/tag.

| Gate | Actual result |
|---|---|
| Lint/module boundaries | Exit 0 |
| `make test-core`, `make test` | Each exit 2; complete 573 tests/65 suites, only the named V8 failure with exactly 48 issues |
| Debug and universal Release builds | Exit 0, including early toolchain preflight |
| Release tooling tests | Exit 0; 14/14 pass |
| Separate app/UI suite | Exit 0; 7/7 pass |
| Character resource/copy validation | Exit 0 |
| Universal ad-hoc archive | Exit 0 |
| DMG/ZIP round-trip/inventory/signatures | Pass |
| Policy review | Only `test-core` and `test` match the owner's exact V8 exception; `blockingGates: []` |

The full failed test still runs and its logs retain the actual failure. No other failure is waived.
This is successful release validation under the explicit exception, not a green development
package gate. Existing Xcode metadata-extraction/XCTest stripping notices remain in the logs.

The actual CI artifacts were downloaded and independently verified on the owner's Mac: external
checksums, DMG verification/read-only mount/eject, ZIP extraction, each 216-file inventory, original
resources, bundle ID/version 1.0.1/build 11, arm64/x86_64 slices, per-slice ad-hoc signatures and
source/art/V8 notices passed. In both formats, `INSTALL-FIRST.txt` exactly matches canonical
`install.md`, and system `textutil -info` identifies it as **plain text** (11,938 bytes). The app
was not launched and no global security/quarantine attribute was changed during these checks.
A separate read-only reviewer found no actionable correctness or release blocker.

| Artifact | SHA-256 |
|---|---|
| `PetScape-1.0.1-11-universal.dmg` | `1f402b9af3c2c3765bcdd247609eea275121dea9601deb922832ce3e9c801ccd` |
| `PetScape-1.0.1-11-universal.zip` | `f3c65606e8e24ed8f832cc64f0f99b452eeeca808674355ffbed00b81da83954` |

The reviewed feature commit was fast-forward merged into develop, then main, and both were pushed
before tag/release creation. All app/package Swift sources, Config and original assets have no diff
from v1.0.0; installation packaging/docs and version-specific release policy are the change.

### v1.0.1 public release and README flow — 2026-10-25

- **Release:** [PetScape v1.0.1](https://github.com/danielcbdev/petscape/releases/tag/v1.0.1),
  published at `2026-10-25T22:51:52Z`, latest stable (`draft=false`, `prerelease=false`). The six
  verified CI assets were uploaded to a draft, inspected for names/sizes/server SHA-256, then
  explicitly published under owner authorization. No untested rebuild replaced them.
- **Tag:** annotated `v1.0.1`, object `6ff4ec982c5a527962c1061b9b1e72b1a58e118b`, points to the
  exact tested/integrated source `a9db12f5c0be3d49a3e1252d58301f6ccfdaf400`. v1.0.0's tag and
  published artifacts remain unchanged. The final evidence commit is documentation-only and
  does not move either release tag.
- **Public delivery:** the exact README DMG URL and matching `.dmg.sha256` were downloaded using
  unauthenticated `curl` with no `gh`/token. The 48,493,391-byte DMG checksum passed. Its mounted
  216-file inventory, version/build, resources, both ad-hoc signatures and identical plain-text
  offline guide passed, and the image was ejected. ZIP size is 46,592,096 bytes; both hashes are
  recorded above and match GitHub's server digests.
- **README commands:** the actual documented Terminal block was also executed against the public
  v1.0.1 URLs, using an owned temporary download location. Its real HTTPS-only `curl` downloads
  and `shasum -a 256 -c` passed. The final Finder `open` was replaced by a completion marker to
  avoid changing the owner's UI or running the app; opening/approving/relaunching is not claimed
  as tested by this command check.
- **Integration:** feature → develop → main fast-forward merges and pushes were completed before
  tagging/publication. The final documentation-only evidence commit is synchronized to main,
  develop and `feature/T21-installation-followup`; historical branches/worktrees are preserved.
  README points to v1.0.1/build 11 and the new successful hosted run.
- **Limits:** this update reproduces the reference download/verify/open method and improves the
  manual approval instructions. It does not add Apple identity/notarization or promise that the
  alert disappears. Complete clean-machine approval/relaunch, native Intel, older supported OS
  and managed-device policies remain unverified. The only waived failure is the separately
  approved exact V8 test; development/default strict package validation remains red for it.

## v1.0.2 V8 closeout publication — 2026-10-25

After the local [V8 visual closeout](m15-implementation.md#final-v8-visual-acceptance--2026-10-25),
the owner explicitly requested: **“Commita, mergea para a develop, depois manda pra main e gera
a release. Faz todo o processo”**. This authorizes feature commit/push, integration into develop
then main, a new v1.0.2 tag and public release (build 12), superseding the prior local-only boundary
for this closure. Existing release tags/artifacts remain immutable; no historical branch cleanup
or forced remote updates are authorized.

The approved artwork remains unchanged. All 134 original hashes and 48 precise accepted findings
are recorded in `v8-visual-acceptance.json`; every pixel assertion runs and uses a strict known-issue
scope per approved image/hash/criterion. The release-only exception is retired (`approved=false`),
the workflow's bypass input is removed, and canonical commands must exit successfully.
`ARTWORK-ACCEPTANCE.json` accompanies future DMG/ZIP payloads. This is acceptance, not pixel repair.

The README/direct download, checksum commands and bundled bilingual installation guide target
v1.0.2/build 12. Signing remains ad-hoc, without notarization or developer identity. Native Intel,
clean-machine approval/relaunch and managed/older supported OS evidence remain unverified.
Fresh integration/hosted/artifact/public-download results are recorded below as they complete.

### v1.0.2 strict hosted validation and artifact checks

[Run 40255266960](https://github.com/danielcbdev/petscape/actions/runs/40255266960) completed
successfully from clean feature commit `ce23370c260883d107a6dc2705be651f9eb95a53`, on macOS 26.6.2
(25G83), Xcode 26.2 (17C52), Swift 6.2.3, arm64 host. Validation used no V8 bypass input/CLI option,
and the optional publication job was skipped. The full source tree was checked before integration.

| Gate | Actual result |
|---|---|
| Lint/module boundaries | Exit 0 |
| `make test-core` | Exit 0; 574 Swift Testing tests/65 suites pass with 48 known visual issues, plus 2 XCTest cases |
| `make test` | Exit 0; same full package round, then all 7 UI tests pass (`TEST SUCCEEDED`) |
| Debug/universal Release build | Exit 0, including early toolchain preflight |
| Release tooling | Exit 0; 15/15 tests pass, including retired-waiver rejection |
| Character copy/resource parity | Exit 0 |
| Universal ad-hoc archive | Exit 0 |
| Gate review | `failedGates: []`, `ownerApprovedV8Gates: []`, `blockingGates: []` |
| DMG/ZIP round-trips and external checksums | Pass |

This is a successful strict gate result with transparent owner-accepted **known** visual findings;
no failed gate is waived. The 48 original pixel thresholds are not claimed to have been repaired.
Xcode's existing metadata-extraction/signed-XCTest stripping notices remain in logs; compiler
warnings stay errors. The raw results/environment are retained in the workflow logs artifact.

The actual CI artifacts were downloaded and independently checked on the owner's Mac: both external
SHA-256 sums, DMG verification/read-only mount/eject, ZIP extraction, complete 216-file inventories,
version 1.0.2/build 12, both executable slices and ad-hoc signatures, original resource parity,
source/art licenses and canonical bilingual instructions passed. `INSTALL-FIRST.txt` is native
plain text (12,330 bytes). `ARTWORK-ACCEPTANCE.json` exactly matches the approved source record;
each of its 134 hashes also matches the PNG inside the actual app, and its finding counts are
43 margin, three duplicate, one ground and one seam. Neither package contains `RELEASE-EXCEPTION.json`.
The app was not launched and no global security/quarantine setting was changed during these checks.

| Artifact | SHA-256 |
|---|---|
| `PetScape-1.0.2-12-universal.dmg` | `86d8844f7124e84cfdc2c00d3157de50c583fbec94de080edd84283558e98e0a` |
| `PetScape-1.0.2-12-universal.zip` | `63a0e358c5df7c2341723f0d63f441d2c87d0323e8eecf44d41f81e14b45ce33` |

Fresh local precommit verification also passed: 574 package tests with 48 known findings, 15 tooling
tests, lint, actionlint, shell syntax, documentation paths/anchors and whitespace. A read-only final
review found no release blocker. The tested feature commit was fast-forward merged into develop,
then main, and both were pushed before tag/release creation. Runtime/app sources, configuration and
all original assets have no diff from v1.0.1. Existing release tags/artifacts are preserved.

### v1.0.2 publication and anonymous installation entry point

- **Release:** [PetScape v1.0.2](https://github.com/danielcbdev/petscape/releases/tag/v1.0.2),
  latest stable (`draft=false`, `prerelease=false`), published at `2026-10-26T01:59:56Z`
  (2026-10-25 in the owner's America/Fortaleza timezone).
- **Tag:** annotated `v1.0.2`, object `c40a5bbd364201ce90afd1dd70f2bf2ad657962a`, points to exact
  validated/integrated source `ce23370c260883d107a6dc2705be651f9eb95a53`. It was pushed after all
  strict gates and local checks passed. No tag was moved for final documentation.
- **Publication:** the six verified CI files were downloaded and independently checked, uploaded
  to a draft using `gh release create --verify-tag --draft`, inspected for expected names/sizes
  and server SHA-256, then explicitly published with `gh release edit --draft=false --latest`.
  The manual validation workflow itself published nothing. No new rebuild substituted bytes.
- **Assets:** universal DMG (48,415,793 bytes), ZIP (46,598,275 bytes), each format's `.sha256`,
  combined `SHA256SUMS` and `RELEASE-NOTES.md`. Server digests match the table above. Both binary
  formats contain the full artwork acceptance record and no retired release-waiver file.
- **Anonymous download:** ordinary HTTPS-only `curl` fetched the exact README DMG URL and matching
  checksum without `gh`/tokens or the ZIP. `shasum -a 256 -c` returned `OK`. Mounted inventory,
  bundle/version/build, both architectures/signatures, canonical instructions, acceptance metadata
  and all 134 actual bundled image hashes passed; the volume was ejected afterwards.
- **README commands:** the actual documented Terminal block was independently executed against
  the public v1.0.2 URLs, using an owned download directory. Real HTTPS downloads/checksum passed;
  the final Finder `open` was replaced by a completion marker, so app opening/approval is not
  claimed as tested. Source checkout/Xcode/Python are not needed by users following the README.
- **Git:** the implementation was committed on `feature/T15-v8-owner-closeout`, merged into
  develop and then main with fast-forwards, and pushed before release creation. A documentation-only
  follow-up records actual results after publication and is synchronized across those three
  branches. Prior tags/artifacts and unrelated branches/worktrees remain preserved.
- **Limits:** full clean-machine first-open/approval/relaunch, native Intel execution, older
  supported OS and managed-device policy behavior remain unverified. Ad-hoc signing provides no
  Apple developer identity/notarization; this release does not promise disappearance of Apple's
  verification warning. The visual follow-up is closed by acceptance, with original pixel
  criteria still evaluated and known findings transparently retained.
