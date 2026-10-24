# M16 — Music dancing and Dock cleanup

**Current status: Done by explicit owner acceptance, 2026-10-24.** See the
[owner closeout](#owner-m16-closeout--2026-10-24). Earlier pending/not-Done statements below record
historical checkpoints; owner acceptance supersedes their approval status, not their evidence limits.

Owner authorization: 2026-10-23, implement all work independent of new images. No image
creation/editing, commits, pushes, tags, releases, PRs or merges. M15 closeout and V8 QA exception
are unchanged. M17–M20 are excluded. On 2026-10-24 the owner additionally authorized milestone
closure, a feature branch, commit, merge into develop and push.

## Design and acceptance contract

Use the existing Platform → Runtime → Core value boundary and PetState hierarchy. No module,
physics model, scheduler, dependency or schema change. Platform uses public Core Audio process
taps (macOS 14.2+) and Apple's built-in SoundAnalysis classifier. Unlike ScreenCaptureKit this
requires only system audio recording consent, never Screen Recording. Microphone capture would
not detect headphone playback and is not selected. On macOS 14.0–14.1 automatic mode is unavailable;
manual dance remains available. No microphone access or process/window identification is used.

Evidence: [Apple tap sample](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps),
[stream classification](https://developer.apple.com/documentation/soundanalysis/classifying-sounds-in-an-audio-stream),
and installed SDK AudioHardwareTapping.h availability macOS 14.2. Native permission/route behavior
must still be verified; documentation and SDK inspection do not prove capture on this machine.

- Opt-in defaults off. Explain system output capture before starting; native OS consent follows.
  Manual controls never start capture. Samples exist only in bounded memory, no file/network/logs.
- Classification runs off the main actor, outside simulation frames, using 1 s windows with 50%
  overlap (the SDK may round the window to a supported duration; elapsed confirmation uses the
  actual result duration). Music confidence >=0.65 for 1 s confirms start; <=0.35 for 1 s confirms stop. Intermediate
  scores cancel a pending transition. A shorter dip retains the session. Stop interrupts automatic
  dance immediately after confirmation (classification latency is explicit, not instantaneous audio).
- A confirmed start consumes one opportunity even if the pet is busy; do not queue. Automatic dance
  requires enabled autonomy, active run state, supported walking/idle, no press/hold/excursion. Manual
  dance uses the same eligibility and may replace an automatic dance once; repeated manual requests
  while manual dancing are rejected. Automatic starts cannot replace manual dancing.
- Both dances draw 5–30 simulated seconds inclusive using existing injected RandomSource. Core
  owns the deadline. The M15 five-second ordinary rest budget excludes these explicit M16 actions.
  Completion returns to bounded idle/walking policy. Music stop ends automatic only.
- Pause/hide/suspension, autonomy off, capture failure/off cancel dances; stop capture whenever the
  app is not running, no visible pet exists, or autonomy is disabled. Physical phases/hold/support
  loss always win. Cancellation never resumes a partially completed dance. Capture restart requires
  observed non-music before rearming a previously confirmed session, avoiding repeated dance on
  continuous playback across pause. Startup suspension/failure before any confirmed music does not
  consume the first session.
- Cleanup: record descending swept contact on dockTop only after falling from strictly above its
  top, excluding any flight launched from that same Dock and upward jumps. The owner follow-up
  additionally enables cleanup after a held release descends onto Dock or screen ground; a held
  release onto a window or placement without a fall remains excluded.
  A downward jump from a strictly higher surface is eligible; its immutable launch height survives
  source movement/removal during flight. After the existing
  0.10 s stable Landing phase, consume the trigger once and hold cleanup for 3 simulated seconds.
  Walking, placement, upward flight, other surfaces, paused return and duplicate contacts do not trigger.
  Support loss/hold/suspension/autonomy off cancel it. Position, contact and geometry remain physics-owned.
- Semantic clips `dance` and `cleanup` request existing missing-clip held-frame fallback when a pack lacks
  them. No aliases or fake art are added; such packs show that the new artwork is pending. The cat pack
  ships both since T16.8 (V9 rig art). Valid manifests never reference
  nonexistent PNGs. Final visual acceptance remains blocked on owner-supplied art.

## Tasks and verification plan

- [x] T16.1: This contract, task register and AC-M16 criteria before implementation.
- [x] T16.2: Core session hysteresis and dancing HSM; failing deterministic tests, then implementation.
- [x] T16.3: Core typed cleanup provenance and stable landing; positive/negative deterministic tests.
- [x] T16.4: Injectable audio service, bounded off-main classification, lifecycle and unavailable tests.
- [x] T16.5: Persisted opt-in, explicit consent, normal menu/Settings manual control and status.
- [x] T16.6: Per-clip art briefs, precise integration handoff; no images produced.
- [x] T16.7: Lint, package/Core tests, app/UI tests, Debug/Release, manifest/asset checks; record actual
  results and pre-existing failures separately. Owner native audio/permission/VoiceOver/playback pending.
- [ ] T16.8: Owner supplies new art; integrate actual manifest clips, validate pixels/playback/memory,
  complete native acceptance, then obtain owner closure. Art delivered 2026-10-23 with the V8 rig by
  owner-approved method change ([V9 delivery](../specifications/animation-assets-v9.md#delivered-v9-art--2026-10-23));
  manifest integration and pack tests done 2026-10-23; native playback, memory and visual acceptance remain open.

Review focus: stale audio callbacks after stop; permission denied or silent stream; pause during a
session; manual takeover; same-Dock jump versus actual descent from above. Test these at their seams.

## Delivered implementation and file responsibilities

- Core `MusicSessionDetector`: acoustic session hysteresis, invalid-sample handling and silence
  rearming across capture restarts. `DanceSource` uses existing injected randomness with both
  inclusive endpoints. GroundedState/PetWorld own finite dances/cleanup; FlightOrigin stores source
  ID/height or release provenance, independent of mutable jump planning.
- Platform `Audio/MusicScoreSource` is the injected hardware/classifier seam;
  `MusicDetectionController` owns opt-in lifecycle, generation-fenced results, failure latch and
  session reduction. `SystemMusicScoreSource` owns tap/IOProc/private aggregate, bounded samples,
  output/format listeners and stalled-result watchdog. `MusicStreamAnalyzer` owns background
  SoundAnalysis and sends only confidence/time values outward. Public framework adapters retain
  the existing module boundaries; there is no new domain scheduler or physics change.
- Runtime connects run-state/autonomy/visible-pet gates and world inputs; SettingsModel forwards
  consent/manual intents and publishes status/eligibility. Normal menu and Settings contain Dance;
  no M16 preview/demo panel was added. The existing DEBUG preview remains an M15 facility.
- Preferences add `petscape.musicDancing`, absent = false, restore removes it. Existing keys/version
  meanings and schema-v1 manifests are unchanged. Config adds only NSAudioCaptureUsageDescription.
- Tests use fixed dt/injected RNG/fake scores and synthetic environment for new music integration;
  new tests read the existing cat pack and create no image fixture. The existing complete test suite
  retains its ordinary temporary fixtures; no artwork or versioned image is authored by M16.

## Verification record — 2026-10-23

Environment: Xcode 27.1 (27A9275), Swift 6.4, arm64 macOS SDK 27.0; deployment remains macOS 14.0.
Swift 6.2 / Xcode 26 compatibility was not executed on an alternate toolchain.

Final gate totals are recorded below. Initial red/green cycles verified missing
Core/service APIs, upward-jump cleanup rejection, failure callback reentry, failure-status retention,
and upper-window source removal. Independent review found the last two lifecycle/provenance cases;
both received failing regressions and fixes. A tuple-pattern compiler error during the provenance
edit was corrected; no compiler error is ignored in the final build.

An early expanded UI run failed because “Cancel” matched both the Touch Bar and confirmation sheet.
The query now scopes to the actual Settings sheet; both UI tests subsequently passed, including
music default-off, visible manual control, autonomy-disabled state, explanation and cancellation.
A package run concurrent with native UI automation produced 136 extra runtime assertions (11 in
new music integration and 125 in preexisting runtime tests); this run is not a passing gate or proof
of a preexisting product defect. New music integration now injects both screens and fullscreen
readings. A first sequential rerun still had 63 assertions in existing overlay tests, while the new music
suite passed. The new native fixture suite had its own serialized root, which did not serialize it
against the existing overlay tests. Nesting it inside the existing serialized PetRuntime suite
removed cross-fixture overlap without changing old assertions. The final sequential full rerun
passed all runtime tests except the unchanged V8 pixel-QA test (48 issues). No test was removed,
skipped or weakened.

### Final verification results

| Gate | Actual result |
|---|---|
| `make lint` and `git diff --check` | Pass, including module boundaries and strict formatting |
| `make test` → `make test-core` | **Fails only the existing V8 pixel-QA test**; Core 329, Platform 39, Rendering 50 pass; Runtime 90/91 tests pass, 48 issues in `newDrawingsAreDistinctOpaqueContainedAndRegistered` |
| Targeted M16/persistence tests | 22 tests pass (15 Core, 5 Platform/persistence, 2 Runtime); included again in the final full run |
| Native app/UI via direct `xcodebuild … -configuration Debug test` | 2/2 pass, including expanded music consent-cancel/manual-availability assertions; run separately because the package failure stops `make test` before app tests |
| `make build` Debug | Pass; zero Swift compiler warnings; existing AppIntents metadata-extraction warning retained |
| Release `xcodebuild … -configuration Release build` with warnings-as-errors | Pass; same existing AppIntents metadata warning |
| Manifest/path/decode/original-hash gates in existing package tests | Pass; schema 1, 10 clips, 134 references, 0 missing paths; no new clip falsely declared present |
| Independent Git blob hash comparison | All 307 tracked image files byte-identical; no new untracked image/asset files; runtime manifest unchanged |
| Real capture/consent/denial/revocation/routes/CPU/leaks/VoiceOver/new-art playback | **Not executed / not claimed**; owner matrix below |

The aggregate package total is 509 tests, with one failing test (48 assertions), not “48 failing
tests.” The known V8 test was not suppressed. Earlier transient native/test-query failures and the
corrected compiler failure above are retained separately from these final results. Final command
logs were inspected at `/tmp/petscape-m16-{tests,lint,debug,release,ui}-final.log` (temporary local
logs, not product telemetry). No hosted CI, release, new performance measurement or visual approval
is claimed.

## External art and native acceptance handoff

At the art-delivery checkpoint M16 was **not Done**. On 2026-10-23 the owner chose to have the V9 art built with the V8 cut-out rig
instead of hand-drawn frames; the source files were delivered and then integrated as recorded below:

- `assets/characters/cat/v9/dance/frames/dance_01.png` … `dance_30.png` (30 FPS loop).
- `assets/characters/cat/v9/cleanup/frames/cleanup_01.png` … `cleanup_36.png` (12 FPS, once).

Method, measured checks, deviations and limits are in the
[V9 delivery record](../specifications/animation-assets-v9.md#delivered-v9-art--2026-10-23). T16.8 integration
(2026-10-23): both clips are in the runtime `character.json` (`dance` loop 30 FPS, `cleanup` once 12 FPS;
bottom alignment, mirrorable, interruptible, no events/`next`/alias), so the Settings pending-art note
no longer shows for the cat. New `M16CharacterPackTests` check manifest timing, report paws, the V8
pixel contract on all 66 drawings and lazy family loading (66 × 288 × 288 × 4 = 21,897,216 decoded
bytes measured when both load; no budget approved). The M15 inventory assertion admits exactly these
two clips; V8 QA is unchanged. Remaining: native playback/registration/hit testing, CPU/memory
measurement and owner visual acceptance.

T16.8 gate results (2026-10-23, same toolchain): `make lint` and `git diff --check` pass; `make test-core`
fails only the unchanged V8 pixel-QA test (48 issues) — Core 329, Platform 39, Rendering 50 pass, Runtime
94/95 (4 new V9 tests pass); app/UI tests via direct `xcodebuild … -configuration Debug test` 2/2 pass;
Debug and Release builds pass with warnings as errors (existing AppIntents metadata warning only); the
Release app bundles all 66 V9 PNGs. Dance/cleanup playback in the running app was not observed.

Native music/speakers/headphones, true OS consent/denial/revocation, route changes, resource/leak
measurements and VoiceOver remain unverified. The exact owner steps are in the
[M16 manual matrix](../development/testing.md#m16-owner-native-matrix-not-executed).
The public tap path never requests a forbidden permission, but zero-filled output cannot establish
whether permission is denied/revoked; immediate revocation detection is **not claimed** and remains
an explicit acceptance limit. Review that native result before closure. No private API or misleading
microphone substitution is offered.

M15 owner acceptance and its V8 pixel-QA exception remain unchanged. No M17–M20 functionality,
commit, push, tag, release, PR, or merge was performed.

## Owner follow-up — music failure and cleanup after dragging

The owner reports that V9 playback looks good, but automatic dancing failed with Spotify and
YouTube, and requests the same cleanup after picking up, dragging upward and releasing the cat.
This explicitly supersedes the original held-release exclusion; M16 remains In progress.

Root causes and changes:

- Both existing built configurations lacked NSAudioCaptureUsageDescription despite the arbitrary
  generated-plist setting. A failing `make build` artifact check reproduced the absence. Add
  `Config/PetScape-Info.plist`, merge it via app-target INFOPLIST_FILE for Debug/Release, remove the
  ineffective custom build setting and keep the actual bundle-key gate in `make build`.
- A failed start or initial suspension latched “wait for silence” before any confirmed session.
  Two fake-source failing regressions reproduce lost first music detection; preserve the latch
  only for a confirmed/unresolved prior session. Continuous music after pause still cannot repeat.
- Released pets were deliberately excluded from cleanup. An actual press→hold→release→fall→stable
  landing regression failed at the missing cleanup. Allow a released pet's descending contact on
  Dock or screen bottom, retain the landing delay/three-second bound and all physical guards.
  Window landings and same-Dock/upward jumps remain excluded. Existing no-clean expectations were
  updated only where the owner changed behavior, with separate positive/negative replacements.

No images, rig scripts or character manifest were changed by this follow-up. Existing V9 art and
other pending changes are preserved; no commit/push/tag/release/merge is authorized.

Follow-up verification: 25 targeted tests pass (17 Core, 6 Platform, 2 Runtime). Full package
execution: Core 331, Platform 41, Rendering 50 pass; Runtime 94/95 pass, with only the retained V8
pixel-QA test failing (48 assertions). `make lint`, Debug/Release builds and actual bundled usage-
description checks pass in both configurations; LSUIElement remains true. The existing AppIntents
metadata warning remains. Native UI checks pass; the launch test now uses the same isolated
preferences mechanism as Settings so it cannot start capture from the owner's saved opt-in.
All 66 supplied V9 frame hashes still match their provenance. No art was altered.

Real audio consent, Spotify/YouTube playback, revocation and performance still require a native
retest; do not equate a repaired plist with a verified end-to-end audio result. Close any old
PetScape process, launch the new Debug build, enable the toggle/confirm the explanation and grant
only system audio recording when macOS asks. With an active walking/idle pet, test playback,
confirmed stop, restart, and nonrepeat after expiry. Retest held drops onto Dock/screen ground and
negative window landings. M16 is not closed by this follow-up.

## Owner follow-up — Stop Dance

T16.10 adds a normal menu/Settings “Stop Dance” button, enabled only while a supported active pet
is dancing. SettingsModel forwards an explicit WorldInput.stopDance through Runtime. Core exits
Manual or Automatic dance via existing bounded Idle, without changing attachment/position,
interrupting unrelated states, disabling music capture or clearing the consumed music session.
Continuous music therefore does not immediately restart automatic dancing after Stop; an observed
stop/start can trigger the next session. Availability is published independently of Dance start
availability, preserving the existing callback/API and preference keys. No new art is involved.

Deterministic regressions cover both origins, no automatic repeat, new session restart and ignored
Stop in Walking/Held/Falling/Cleaning. Runtime/model verifies live button eligibility and that manual
start/stop never starts audio capture. UI test checks presence and disabled state when unavailable.

Stop Dance verification: the missing-command/model tests first failed to compile, then 27 focused
music tests passed (19 Core, 6 Platform, 2 Runtime), followed by all 333 Core tests. Strict lint,
Debug build and 2 native UI tests pass; the UI checks Stop exists and is disabled when unavailable.
The existing V8 pixel-QA exception is unchanged; no images or persisted preferences were modified.
Release build also passes; Debug/Release retain only the existing AppIntents metadata-extraction
warning. No commit, push or milestone closure.

## Owner M16 closeout — 2026-10-24

The owner explicitly reported “funcionou tudo” after testing the final implementation and asked
to close M16, create the branch, commit, merge into develop and push. **M16 is Done by explicit
owner acceptance.** This records the owner's functional confirmation of the delivered behavior;
it does not invent individual permission-revocation runs, hardware details, timing tolerances,
CPU/memory measurements, VoiceOver observations or soak duration.

Delivered and accepted scope:

- Local, opt-in public system-audio music classification (macOS 14.2+, no microphone/screens),
  inclusive seeded 5–30 s automatic dance, confirmed-stop interruption and one dance per session.
- Normal app manual Dance and Stop Dance, no audio permission for manual controls, physical/run-
  state precedence and safe lifecycle/first-session recovery after initial failure/suspension.
- Three-second cleanup after stable eligible descent to Dock; owner-requested held drops also
  qualify on Dock or screen ground. Same-Dock/upward jumps, window landings and no-fall placement
  remain excluded; physical motion and contact are unchanged.
- Owner-approved V9 rig art: 30 dance loop frames and 36 once-only cleanup frames, real manifest
  entries, lazy loading, provenance/QA and unchanged original/V8 frames.
- Actual bundled audio usage-description in Debug/Release; deterministic regression tests, native
  menu/Settings assertions, docs and explicit accepted evidence limits.

Retained exceptions and evidence limits:

- M15's unchanged `newDrawingsAreDistinctOpaqueContainedAndRegistered` V8 pixel-QA test remains
  failing with 48 assertions; it is neither fixed nor counted as passed by closing M16.
- AppIntents metadata extraction emits the existing warning because no AppIntents dependency
  exists. No new Swift compiler warning is accepted or ignored.
- Zero-filled output cannot publicly distinguish silence from a denied/revoked audio grant.
  Immediate native revocation detection, detailed permission/route matrix, CPU/energy/leaks,
  VoiceOver, alternate Xcode 26/Swift 6.2/macOS 14 hardware and full memory budget validation were
  not independently established. The owner accepts these recorded evidence limits for closure;
  functional acceptance does not supply missing measurements or private-API permission checks.
- No M17–M20 work, release, tag, hosted CI result or publication is implied.

Integration authorized by this closeout: `feature/M16-music-dance-and-cleanup` → `develop`,
Conventional Commit(s), regular remote push; no force push or PR is required. The fresh pre-merge
verification record below distinguishes the known inherited failure from any new regression.

### Closeout verification — 2026-10-24

Fresh checks on the integration tree:

| Check | Result |
|---|---|
| Strict `make lint`, `git diff --check` and staged diff check | Pass |
| `make test` → full package suite | 519 tests: 518 pass; only the unchanged V8 pixel-QA test fails (48 assertions). Core 333, Platform 41, Rendering 50 pass; Runtime 94/95 pass |
| Native app/UI tests, run separately after the package suite | 2/2 pass; separate run is needed because the inherited package failure stops make before app tests |
| Debug `make build` and Release build | Pass with compiler warnings treated as errors; inherited AppIntents metadata warning remains |
| Actual built consent description | Present in both Debug and Release app bundles |
| Manifest and delivered V9 files | Schema 1, 12 clips, 200 image references, zero missing paths; all 66 V9 provenance hashes match |
| Independent read-only review | No new critical/important correctness or privacy finding |

The inherited failing test was executed and retained, not skipped or weakened. These results do
not create a measured native-performance, permission-revocation or VoiceOver pass. Owner acceptance
and its explicit Git authorization govern closure with the documented exceptions.
