# Release & Distribution

PetScape distributes a ready-to-run universal macOS app through GitHub Releases. The primary
format is a **DMG with an Applications shortcut**, with a ZIP alternative. Users download the
binary package and follow [the README](../../README.md#download-and-install); no source checkout,
Xcode or compilation is required. macOS 14+ is required. Both arm64 and x86_64 slices are built
and verified; native Intel execution and clean older-OS testing remain unverified.

## Current installation release: v1.0.3/build 13

[v1.0.3](https://github.com/danielcbdev/petscape/releases/tag/v1.0.3) is published from
`a6deacf4a06e801101be2b242d57305ef50a79ba`. The README, release body and native-readable bilingual
guide lead with the same cURL download/checksum/open flow, without requiring a manual file
download or citing unrelated projects. [Strict validation](https://github.com/danielcbdev/petscape/actions/runs/40260320801)
passed every gate: both 574-test rounds (48 explicitly known artwork findings), 7 UI tests and
15 tooling tests, builds/archive and package round-trips. There were no failed/waived/blocking gates.
Actual DMG/ZIP and public README download/checksum/payload checks passed. See the
[publication evidence](../planning/m21-implementation.md#v103-curl-first-installation--2026-10-25).

## v1.0.2 V8 closeout publication — authorized 2026-10-25

After accepting the final V8 visual baseline, the owner explicitly requested committing the
closure, merging feature → develop → main, pushing and publishing another release.
**[v1.0.2/build 12](https://github.com/danielcbdev/petscape/releases/tag/v1.0.2) is published** from
`ce23370c260883d107a6dc2705be651f9eb95a53`, following
[strict validation](https://github.com/danielcbdev/petscape/actions/runs/40255266960) with every gate
exit 0 and no release failure waiver. Both 574-test rounds report the 48 hash-pinned,
owner-accepted known findings; all 7 UI and 15 tooling tests pass. This records
artwork acceptance; no original pixels are repaired or changed. Future packages include
`ARTWORK-ACCEPTANCE.json`. Existing tags/releases remain unchanged. The public DMG and README
download/checksum commands were verified independently, including mounted inventory and both
signatures. Exact results and remaining native-install evidence limits are recorded in the
[publication evidence](../planning/m21-implementation.md#v102-v8-closeout-publication--2026-10-25).

[v1.0.0 (build 10)](https://github.com/danielcbdev/petscape/releases/tag/v1.0.0) was published on
2026-10-25 from `c157cbf2dc31d69cc268b8de1b446a13d6211872`, following successful hosted validation
with the explicit V8 exception. Its anonymous public DMG download, checksum and mounted payload
were independently verified. See the [publication record](../planning/m21-implementation.md#public-release-and-download-verification--2026-10-25)
for exact hashes, gates and remaining native-install evidence limits.

## v1.0.1 installation follow-up — authorized 2026-10-25

[v1.0.1/build 11](https://github.com/danielcbdev/petscape/releases/tag/v1.0.1) was published from
`a9db12f5c0be3d49a3e1252d58301f6ccfdaf400`, after
[hosted validation](https://github.com/danielcbdev/petscape/actions/runs/40227041048). The actual
public DMG download/checksum/mounted payload, both signatures and plain-text offline guide passed
independent checks. Complete clean-machine approval/relaunch and native Intel remain unverified.

The owner reported the Apple verification warning after opening v1.0.0 and requested comparison
with [MacDevClean](https://github.com/danielcbdev/mac-dev-clean), a separate branch, integration into
`develop`, README corrections and an updated public release. The owner separately and explicitly
approved retaining the same 48-issue V8 exception for **v1.0.1 (build 11)**. This authorizes the
feature branch, commit, merge/push into develop/main, new tag and public release; v1.0.0 remains
immutable. No future version inherits this approval.

MacDevClean's published v1.0.1-unsigned DMG was inspected: its app is `adhoc, linker-signed`, with
no Authority and no TeamIdentifier. Its build/package scripts produce a universal unsigned app
inside a compressed DMG with an Applications shortcut; that is not an Apple-verified distribution.
Its README downloads via `curl`, verifies a checksum, opens the image and describes manual approval.
PetScape already had equivalent universal DMG/ZIP packaging plus ad-hoc integrity validation.
The different owner experience may involve download metadata, previous approval or OS behavior;
those circumstances were not recorded and are not asserted as a proven cause.

The follow-up adopts the reference's download/verify/open flow with HTTPS-only redirects and
dependent commands so download/checksum failure prevents opening. The first-open instructions
identify the actual alert and use Apple's current Privacy & Security → Open Anyway flow instead
of promising older Control-click behavior. The packages also contain `INSTALL-FIRST.txt`, copied
from the canonical bilingual installation document for native TextEdit access. It is part of the
checksummed inventory. The signing policy, app architecture, original art and privacy behavior do
not change; no global Gatekeeper/quarantine change or warning-free installation is promised.

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

## Current strict gates and the accepted V8 baseline

The owner gave final approval of the current V8 artwork on 2026-10-25. The
[acceptance record](../planning/v8-visual-acceptance.json) pins all 134 original image hashes and
exactly 48 findings (43 margin, three cross-clip duplicate poses, one ground and one seam finding).
Every original pixel assertion remains evaluated. Swift Testing reports only the exact approved
image/hash/criterion as a non-intermittent known issue; changed images, unapproved findings and
unexpectedly disappeared issues fail. This is visual acceptance, not repaired pixels. See the
[closeout](../planning/m15-implementation.md#final-v8-visual-acceptance--2026-10-25).

Current packaging requires a clean checkout and every canonical gate to exit successfully.
The historical [release-only waiver](release-exceptions.json) is **retired** (`approved=false`),
its workflow input is removed, and the legacy `--allow-known-v8-failure` CLI option is rejected.
The v1.0.0/v1.0.1 tags and published artifacts retain their original approval/failure records;
this closeout does not rewrite those results.

`logs/results.json` retains actual exit codes; `logs/gate-review.json` retains failed/blocking
checks (the legacy `ownerApprovedV8Gates` field is empty under current policy).
`ARTWORK-ACCEPTANCE.json` accompanies future packages and records the reviewed visual baseline.
A known-issue test outcome must not be presented as every original pixel threshold passing.
All other package/UI/build/signature/resource gates remain mandatory. Rehearsal accepts local
edits but still exits nonzero for failures and marks output **NOT FOR PUBLICATION**.

## Local commands

Requires macOS, selected Xcode 26+ / Swift 6.2+, `python3` standard library, and system tools
(`codesign`, `ditto`, `hdiutil`, `shasum`, `lipo`). No package-manager dependencies, certificates or
Apple credentials are needed. Development defaults in `Config/Base.xcconfig` stay unchanged;
release version/build are command-line overrides. Preserve bundle ID `io.github.danielcbdev.petscape`.

```bash
# Fast tooling checks:
python3 -B -m unittest discover -s scripts/tests -v
bash -n scripts/release.sh

# Future candidate: add nonempty changelog notes and choose a fresh version/build, no waiver:
scripts/release.sh 1.0.4 14

# Diagnostic local work; never distribute its output:
scripts/release.sh 1.0.4 14 --rehearsal
```

Stable versions use `MAJOR.MINOR.PATCH`, without v/leading zeroes; build is a positive integer
(up to nine digits), greater than `CURRENT_PROJECT_VERSION` and every previously distributed build.
The owner chooses monotonically increasing distributed builds; the local script makes no remote
version queries. `CHANGELOG.md` needs matching version notes or nonempty Unreleased notes. Release
notes should be reviewed and dated before distribution. Existing output directories never overwrite:
move them aside or choose a fresh build. `--architecture arm64` is available for diagnostic/specialized
builds; official packages use the default `universal`.

## Build, package and verification sequence

1. Run canonical lint, package tests, `make test`, Debug build, release-tool tests and Release build.
2. Review test results, including the exact owner-accepted known findings. Every gate must succeed;
   no historical V8 release waiver applies.
3. Run the manifest-driven asset-copy script into a temporary folder and compare every referenced
   file against the original source. Original art is never rewritten.
4. Archive Release with both architectures, explicit `CODE_SIGN_IDENTITY=-`, no team and
   `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`. Validate bundle/version/build/minimum OS, executable
   slices, localizations, resources, per-slice ad-hoc signatures and absence of entitlements.
5. Stage the complete app, notes, bilingual `INSTALL.md` and native-readable `INSTALL-FIRST.txt`, source/art license notices,
   `ARTWORK-ACCEPTANCE.json` and internal `CONTENTS.sha256` inventory.
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
The preflight also uses canonical `make build-release` for optimized universal compilation; the
release script delegates that build gate to the same target, including its Info.plist check.

## GitHub Actions and publication

[release.yml](../../.github/workflows/release.yml) uses manual `workflow_dispatch`. Default
`publish=false` performs strict validation and uploads artifacts without creating tags or releases.
There is no V8 failure-bypass input. The workflow calls the same local script; it has no second
packaging implementation.

The public repository `danielcbdev/petscape` and enabled Actions were verified read-only. Standard
`macos-26` is [generally available](https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/)
and the [official inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
includes `/Applications/Xcode_26.2.app`. Toolchain selection is explicit; the local Xcode 26+ script
is the fallback if a hosted image/toolchain becomes unavailable. No preview Xcode runner is required.

GitHub documents [standard hosted runners as free for public repositories](https://docs.github.com/en/actions/concepts/billing-and-usage).
Private repos have plan-specific minute/storage quotas and possible overages. An Ubuntu preflight
stops private visibility before scheduling macOS (that small preflight can consume private minutes).
Review billing before dispatching if visibility changes. Retention is seven days; quotas are not
assumed unlimited. Existing development CI keeps its original checks; the accepted V8 baseline is evaluated within the tests.

Actions remain pinned to reviewed official commits: checkout v5
`fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09`, upload-artifact v4.6.2
`ea165f8d65b6e75b540449e92b4886f43607fa02`, download-artifact v5.0.0
`634f93cb2916e3fdff6788551b99b062d0335ce0`. Checkout credentials do not persist. Build is read-only;
only the optional draft-publication job receives `contents: write` and this successful run's artifact.

Initial dispatch requires the workflow on default branch `main`, as
[GitHub documents](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch).
After an authorized push, a publication rehearsal is:

```bash
gh workflow run release.yml --ref main -f version=1.0.4 -f build=14 -f publish=false
```

For `publish=true`, select main and supply an **already existing** `vVERSION` tag at that exact
workflow commit. Tag identity is checked before building and again remotely before
`gh release create --verify-tag --draft`; the workflow never creates/pushes tags or overwrites an
existing release. Publish a reviewed draft only under owner authorization. The current owner's
v1.0.2 request supplies that authorization; future releases need their own instruction.

Actual Git/tag/run/release identities and validation results are recorded in the
[M21 publication evidence](../planning/m21-implementation.md). Local and original closeout results
remain historical evidence, rather than being rewritten as successful remote/clean-machine tests.

## References

- [Apple: installing downloaded apps](https://support.apple.com/guide/mac-help/install-and-uninstall-other-apps-mh35835/mac)
- [Apple: notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: universal macOS binaries](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)
- [Apple: Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
