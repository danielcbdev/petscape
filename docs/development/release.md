# Release & Distribution

PetScape distributes a ready-to-run universal macOS app through GitHub Releases. The primary
format is a **DMG with an Applications shortcut**, with a ZIP alternative. Users download the
binary package and follow [the README](../../README.md#download-and-install); no source checkout,
Xcode or compilation is required. macOS 14+ is required. Both arm64 and x86_64 slices are built
and verified; native Intel execution and clean older-OS testing remain unverified.

## Trust and signing policy

The owner does not use paid Apple Developer Program membership. Distribution is **ad-hoc signed**,
with no Developer ID identity or Apple notarization. `codesign --verify --all-architectures --deep
--strict` verifies bundle integrity, not developer identity or Apple trust. The app remains
unsandboxed under [ADR-0010](../decisions/0010-distribution-no-sandbox.md).

Downloaded apps may produce Gatekeeper warnings or be blocked by macOS/device policy. Installation
instructions describe Apple's user-approved Open Anyway path only for users who independently
trust the origin and accept the risk. Never disable Gatekeeper, strip quarantine metadata or claim
warning-free installation, Apple verification or a successful `spctl --assess`.
See [English/pt-BR installation](install.md) and [Apple's guidance](https://support.apple.com/en-us/102445).

SHA-256 detects accidental corruption, but a package and checksum replaced on the same channel
are not independent authentication. The DMG/ZIP each have a `.sha256` sidecar for single-format
downloads; `SHA256SUMS` covers both and requires both files when checked as a whole.

## Owner publication authorization — 2026-10-25

After the local M21 closeout, the owner explicitly requested the full Git process, branch updates,
a public release and an installation path requiring only a downloaded installer. This authorizes
committing the M21 work, integrating `feature/T21-adhoc-release` into `develop` and `main`, pushing
those branches, creating the v1.0.0 tag and publishing the release. It does not authorize changing
historical feature branches, deleting worktrees or force-pushing.

The owner separately confirmed:

- Publish this first version with the existing **V8 pixel-QA exception documented**, retaining
  the failed test and original art unchanged.
- All included art is authorized for redistribution in the app, with **art rights reserved and
  source code MIT**. [ARTWORK-LICENSE.md](../../ARTWORK-LICENSE.md) records D-08's decision; original
  provenance files remain read-only. Imported packs retain their authors' terms.

The earlier no-publication/no-Git instructions describe the original local implementation scope;
this later explicit instruction supersedes them for the v1.0.0 publication only.

## Gates and the bounded v1.0.0 exception

Default packaging still requires a clean checkout and all gates green. The explicit
`--allow-known-v8-failure` option is default off and requires the owner-approved
[versioned policy](release-exceptions.json) for **1.0.0 only**. It does not skip or weaken a test.

The full `make test-core` and `make test` commands run unchanged, retaining exit 2 and their raw
logs when V8 fails. Before allowing that exact exception, the script requires complete Swift Testing
summaries for all **573 tests** (Core 344, Platform 51, Rendering 50, Runtime 128), either the
Swift 6.2 aggregate (65 suites) or four-module Swift 6.4 report, exactly one failed
named test `newDrawingsAreDistinctOpaqueContainedAndRegistered`, exactly 48 recorded issues, and
only the known failed M15 suite. Missing/truncated/changed output, another failure or a compiler/
signal error blocks release. A changed test inventory requires a fresh policy/code review, not a
wider match. The unchanged UI suite runs separately and must pass, as must every other gate.

`logs/results.json` retains every actual exit code. `logs/gate-review.json` distinguishes failed,
owner-approved and blocking gates. Notes and `RELEASE-EXCEPTION.json` disclose any applied exception.
The script may exit 0 for this explicitly approved release while the canonical V8 gate remains
recorded as failed. No future version inherits the exception automatically.

Rehearsal accepts local edits and may produce **NOT FOR PUBLICATION** packages, but still exits
nonzero for a failed gate. Rehearsal is never used by the publication workflow.

## Local commands

Requires macOS, selected Xcode 26+ / Swift 6.2+, `python3` standard library, and system tools
(`codesign`, `ditto`, `hdiutil`, `shasum`, `lipo`). No package-manager dependencies, certificates or
Apple credentials are needed. Development defaults in `Config/Base.xcconfig` stay unchanged;
release version/build are command-line overrides. Preserve bundle ID `io.github.danielcbdev.petscape`.

```bash
# Fast tooling checks:
python3 -B -m unittest discover -s scripts/tests -v
bash -n scripts/release.sh

# Default strict candidate (blocked by the existing V8 failure):
scripts/release.sh 1.0.0 10

# Explicitly approved first release, from a clean checkout:
scripts/release.sh 1.0.0 10 --allow-known-v8-failure

# Diagnostic local work; never distribute its output:
scripts/release.sh 1.0.0 11 --rehearsal
```

Stable versions use `MAJOR.MINOR.PATCH`, without v/leading zeroes; build is a positive integer
(up to nine digits), greater than `CURRENT_PROJECT_VERSION` and every previously distributed build.
The owner chooses monotonically increasing distributed builds; the local script makes no remote
version queries. `CHANGELOG.md` needs matching version notes or nonempty Unreleased notes. Release
notes should be reviewed and dated before distribution. Existing output directories never overwrite:
move them aside or choose a fresh build. `--architecture arm64` is available for diagnostic/specialized
builds; official v1.0.0 packages use the default `universal`.

## Build, package and verification sequence

1. Run canonical lint, package tests, `make test`, Debug build, release-tool tests and Release build.
2. If the approved V8 option applies, run the unchanged UI suite separately; validate exact failure
   evidence. All other failures block normal packaging.
3. Run the manifest-driven asset-copy script into a temporary folder and compare every referenced
   file against the original source. Original art is never rewritten.
4. Archive Release with both architectures, explicit `CODE_SIGN_IDENTITY=-`, no team and
   `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`. Validate bundle/version/build/minimum OS, executable
   slices, localizations, resources, per-slice ad-hoc signatures and absence of entitlements.
5. Stage the complete app, notes, bilingual installation instructions, source/art license notices,
   optional release-exception record and internal `CONTENTS.sha256` inventory.
6. Create the ZIP with system `ditto`; create a read-only compressed DMG with system `hdiutil`,
   adding only the fixed `/Applications` shortcut. Verify image integrity, mount read-only without
   opening Finder, verify inventory and app signatures/resources again, then detach in `finally`.
7. Write combined and per-format SHA-256 files. Freshly extract the ZIP, revalidate complete contents,
   app and signature, and run `shasum` against the inventory. Verify external digests too.

Output is ignored `dist/release/PetScape-VERSION-BUILD-universal/`, or `dist/rehearsal/…`:

| Output | Purpose |
|---|---|
| `PetScape-VERSION-BUILD-universal.dmg` | Primary user download; app, Applications shortcut, notes, install/license files and internal inventory |
| `PetScape-VERSION-BUILD-universal.zip` | Alternative user download; same payload without a disk image |
| `.dmg.sha256`, `.zip.sha256` | Verify one downloaded format independently |
| `SHA256SUMS`, `RELEASE-NOTES.md` | Combined digests and matching release-page notes |
| `logs/` | Exact commands/results, failure/exception review, environment and signature evidence |
| `PetScape.xcarchive`, `DerivedData/`, staged payload | Local build evidence; not release uploads |

Repeatable means the same verified process/content contract, not bit-identical Xcode artifacts.
Timestamps, version/build and debug paths can change hashes. Existing AppIntents metadata and
ambiguous-local-destination diagnostics are reported; no Swift warning is ignored.
Both canonical and release Xcode commands explicitly use `SWIFT_SUPPRESS_WARNINGS=NO` alongside
warnings-as-errors: Xcode 26 otherwise adds warning suppression to local SwiftPM packages, which
conflicts with strict warning enforcement. The hosted workflow runs `make build` first to expose
app/toolchain incompatibilities before the longer package-test rounds.

## GitHub Actions and publication

[release.yml](../../.github/workflows/release.yml) uses manual `workflow_dispatch`. Default
`publish=false` and `allow_known_v8_failure=false` perform strict validation and upload artifacts
without creating tags or releases. For the approved first release, explicitly set the exception
input true. The workflow calls the same local script; it has no second packaging implementation.

The public repository `danielcbdev/petscape` and enabled Actions were verified read-only. Standard
`macos-26` is [generally available](https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/)
and the [official inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
includes `/Applications/Xcode_26.2.app`. Toolchain selection is explicit; the local Xcode 26+ script
is the fallback if a hosted image/toolchain becomes unavailable. No preview Xcode runner is required.

GitHub documents [standard hosted runners as free for public repositories](https://docs.github.com/en/actions/concepts/billing-and-usage).
Private repos have plan-specific minute/storage quotas and possible overages. An Ubuntu preflight
stops private visibility before scheduling macOS (that small preflight can consume private minutes).
Review billing before dispatching if visibility changes. Retention is seven days; quotas are not
assumed unlimited. Existing development CI keeps its original checks and can still report V8 red.

Actions remain pinned to reviewed official commits: checkout v5
`fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09`, upload-artifact v4.6.2
`ea165f8d65b6e75b540449e92b4886f43607fa02`, download-artifact v5.0.0
`634f93cb2916e3fdff6788551b99b062d0335ce0`. Checkout credentials do not persist. Build is read-only;
only the optional draft-publication job receives `contents: write` and this successful run's artifact.

Initial dispatch requires the workflow on default branch `main`, as
[GitHub documents](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch).
After an authorized push, a publication rehearsal is:

```bash
gh workflow run release.yml --ref main -f version=1.0.0 -f build=10 -f publish=false -f allow_known_v8_failure=true
```

For `publish=true`, select main and supply an **already existing** `vVERSION` tag at that exact
workflow commit. Tag identity is checked before building and again remotely before
`gh release create --verify-tag --draft`; the workflow never creates/pushes tags or overwrites an
existing release. Publish a reviewed draft only under owner authorization. The current owner's
v1.0.0 request supplies that authorization; future releases need their own instruction.

Actual Git/tag/run/release identities and validation results are recorded in the
[M21 publication evidence](../planning/m21-implementation.md). Local and original closeout results
remain historical evidence, rather than being rewritten as successful remote/clean-machine tests.

## References

- [Apple: installing downloaded apps](https://support.apple.com/guide/mac-help/install-and-uninstall-other-apps-mh35835/mac)
- [Apple: notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: universal macOS binaries](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)
- [Apple: Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
