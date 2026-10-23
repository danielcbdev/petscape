# M14 implementation and verification record

Date started: 2026-10-23. Status: **Done by explicit owner acceptance (2026-10-23)**. Branch: `develop`, initially one local commit
ahead of `origin/develop`; no pre-existing working-tree changes. No commit, push, tag, release or
publication was performed.

## Owner exception

The owner explicitly waived the continuous 8-hour soak on 2026-10-23. AC-M14-01/T14.5 soak is
**dispensado pelo proprietário — não executado e não aprovado por medição**. No accelerated test is
used as a substitute. This does not establish NFR-03, continuous memory stability or an 8-hour
crash-free run. T14.5 still includes separate leak, footprint and overlay lifecycle checks.

## Owner closeout — 2026-10-23

The owner reviewed the implementation and verification record, approved the documented results,
and authorized M14 finalization. M14 is closed by explicit owner acceptance, including the
environment-dependent evidence gaps listed below. This acceptance does not change which checks
were run: the 8-hour soak was waived and not run; native two-display/mixed-DPI validation, the
macOS 14 VM matrix, and the full manual VoiceOver/keyboard audit were not run. Their outcomes are
not represented as passed measurements. No further M14 implementation remains pending owner
acceptance.

## Changes implemented

- T14.1: the overlay manager now maintains a panel for every connected screen. PetRuntime supplies
  all screen descriptors and screen-bottom/wall surfaces to the same PetWorld; one display link
  remains attached to the selected host overlay. Per-screen renderers share the same snapshot and
  hit tester. Each visible pet is assigned by its global contact point to one half-open screen frame,
  so adjacent screen boundaries cannot draw it in two overlays. Removed screens discard their
  renderer and layers. A synthetic mixed-scale/negative-origin runtime test checks overlay count,
  one rendered pet and continued operation of the single injected driver.
- T14.2: the existing texture policy remains a single cache decoded at the maximum supported scale;
  layer bounds remain manifest `displaySize` in points. DPI-specific visual sharpness has not been
  verified on physical mixed-DPI displays.
- T14.3: no interpolation was added. A 120 Hz judder measurement was unavailable in this
  environment; the conditional justification was not met, so the fixed-step renderer is unchanged.
- T14.4: bundle pruning copies only manifest-referenced files. Startup now checks image metadata
  without allocating pixel buffers, decodes the locomotion family before showing the pet, and lazily
  decodes other behavior families on first use. During that decode the default frame remains visible;
  a deferred decode error is logged, exposed as a degraded-character issue, and does not retry every
  frame. Cache counters report retained decoded bytes.
- Native-test environment: macOS 27.0.1 on Apple M4 with one built-in Liquid Retina display
  (system reports 2560 × 1664 Retina, internal connection). No external display or common VM app
  (Parallels, VMware, UTM, VirtualBox) was present in `/Applications`; physical multi-display,
  mixed-DPI and macOS 14 VM checks remain unavailable here.

## Verification and limits

| Item | Result |
|---|---|
| Initial repository state | `develop` at `7db992a`, one commit ahead of `origin/develop`; clean worktree |
| `make lint` | Passed after formatting the changed Swift files |
| `make test-core` | Passed after M14 changes: 309 Core tests, 80 Runtime tests, plus Rendering and Platform suites. XCTest `measure` ran in Debug (reported average 0.003 s per 600-step batch; high variance) and optimized package Release (reported average 0.001 s; samples 0.000501–0.001284 s per 600-step batch). No CI threshold or baseline comparison is claimed. |
| Debug/UI build and `make test` | Passed after lazy loading and accessibility-label changes; 309 package tests and 2 UI tests passed in Automation Mode |
| Release build | Passed on arm64 with warnings treated as errors |
| `make run` and clean quit | `make run` built and launched the latest Debug app; the UI launch/Quit test showed its status item, sent Command-Q, observed Not Running, and confirmed no PetScape process remained. |
| Lazy behavior family memory comparison (T14.4) | Current cat pack: 5,308,416 decoded cache bytes after startup (locomotion), 16,588,800 bytes after loading all authored families. Initial retained decoded-frame cache is 68.0% smaller (11,280,384 bytes avoided at startup). This compares cache bytes, not process footprint or peak startup memory. Automated tests verify metadata probes retain zero frames and that lazy family loading increases the cache only when requested. |
| Paired Release app CPU/footprint sample (T14.8) | Same Apple M4, macOS 27.0.1, default active/unhidden preferences and app launched outside Xcode. After 30 s settle, M14 process CPU rose 1.11 → 2.41 s over 69 s (≈1.9% of one core); the `7db992a` baseline rose 0.97 → 2.23 s over 74 s (≈1.7%). The M14 sample ended at 41 MB footprint; baseline ended at 48 MB. One window per build, activity phase not pinned, and app order not randomized; the observed CPU difference is below 20%, but this is exploratory only, not stable regression acceptance. |
| Release app `leaks` snapshot | 415 objects / 19,856 bytes, visible roots in Apple's `com.apple.linkd.autoShortcut` AppIntents XPC cycles; no PetScape-owned root appeared in the report. Single instrumented snapshot only; not leak-free or growth proof. |
| Build notices | Xcode reported multiple matching macOS destinations in `make` commands and selected arm64. AppIntents metadata extraction was skipped because the target does not link AppIntents. These are tool notices, not Swift compiler warnings. |
| 120 Hz judder | Not measured; no 120 Hz display/equivalent native setup recorded |
| 2-screen and mixed-DPI native checks | Not run; synthetic runtime coverage is not a manual approval |
| macOS 14 VM matrix | Not run; no common VM app was present |
| VoiceOver and keyboard audit of menu and Settings | UI tests verify the menu and Settings controls expose human-readable accessibility labels and exercise Command-comma / Command-Q. Full manual VoiceOver narration and keyboard-only navigation review remain not run. |
| Leaks/footprint short checks | One earlier Debug sample and one Release sample are recorded above. Both reports identify Apple AppIntents XPC roots and no visible PetScape-owned root. The samples are single startup snapshots, instrumentation affects footprint, and neither proves stable growth or absence of app leaks. The 8-hour soak remains waived. |
| Bundle pruning (T14.4) | Implemented schema-v1 manifest-driven resource copy. Existing full Debug resource folder: 21 MB by `du -sh`; final Debug and Release resource folders: 9.4 MB each, 51 files. Disk bundle size only; no decoded bytes or process footprint inferred. |
| Lazy clip loading / runtime memory comparison (T14.4) | Implemented and covered by tests. Decoded cache bytes: 5,308,416 initial vs 16,588,800 when all authored families are requested; this is not a process-footprint comparison. |
| XCTest `measure` / paired Release performance protocol (T14.8) | Measurement test added around 600 representative `PetWorld.step` calls, no time threshold. Debug/Release package runs passed. The short paired app CPU/footprint comparison is above. p95 callback/frame-pacing and idle-wakeup comparisons were not captured. Existing step/render/decode/pass-through signposts reviewed; no additional signpost justified. |

The Xcode app target's script-sandbox setting is disabled only for the resource-pruning phase,
because that phase replaces a previously built bundle directory. The phase input/output paths are
restricted in the project file; the UI-test target retains its script sandbox.

Manual VoiceOver and keyboard navigation, native two-display/mixed-DPI checks, and the macOS 14 VM
matrix were not run. The 8-hour soak was explicitly waived by the owner, not run, and not
measurement-approved. Single-session leak/footprint observations and synthetic overlay lifecycle
tests are recorded, but they do not establish long-term growth stability. This Mac has one built-in
display and no VM app; synthetic tests do not replace those manual results. The owner explicitly
accepted these evidence limits and closed M14 on 2026-10-23; this closeout does not claim that the
unrun checks passed.
