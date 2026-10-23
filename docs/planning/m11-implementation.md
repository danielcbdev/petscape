# M11 implementation record

**Date:** 2026-10-22
**Status:** Done by owner acceptance (2026-10-22).

## Implemented

- Added canonical left/right vertical screen surfaces to `Surface` and `SurfaceMap`; wall IDs are
  stable per screen and vertical segments use bottom-to-top attachment parameters.
- Reused `GroundedState.climbing`, `PetState`, the existing `SurfaceAttachment`, and the current
  fixed-step physics. Walking clamps at the edge and attaches on that step. Climbing advances at
  120 pt/s, clamps the full display bounds to the hosted screen, and exits into the existing
  inward-directed fall at the top. Removed or too-short walls trigger the same safe fall.
- Added anchor-preserving pose transitions. The right wall uses the authored pose; the left wall
  mirrors it around the contact anchor. The contact is at the screen edge and the asset check
  measures the rightmost solid paw pixels within 3 pt at the 96 pt display size.
- Integrated the V6 `climb` loop and schema-v1 `idle` fallback. The two-frame loop keeps total
  decoded pack memory within the existing 16 MiB budget. Source prompts, export measurements and
  hashes are in [`assets/characters/cat/v6/README.md`](../../assets/characters/cat/v6/README.md).
  The first runtime export clipped the top of the ear; the deterministic exporter now offsets the
  art within its canvas, and the pack test requires at least 8 px of transparent margin on every
  side. The updated runtime frames retain full silhouettes with 11 px or more margin.
- No M10 scope or original V3/V4/V5 images were changed.

## Automated verification

| Command | Result |
|---|---|
| `make lint` | Passed after `make format`; no Swift format findings. |
| `make test-core` | Passed: runtime 77, rendering 48, platform 32, Core 291 tests. |
| `make test` | On the final run, all package tests passed (77 runtime, 48 rendering, 32 platform, 291 Core); UI-test runner failed to initialize because macOS timed out enabling Automation Mode. |
| `make build` | Final Debug build passed with Swift and C warnings treated as errors. Xcode emitted its existing App Intents metadata notice because the app does not link AppIntents. |
| `make run` | Built and launched PetScape before the final anchor-continuity refinement. Logs show runtime started, Cat loaded (16,588,800 decoded bytes), and spawned on Dock. The locked session then reported a full-screen Space and hid the overlay. The final build passed separately, but the latest code has not been launched because the existing app could not be quit through its menu while locked. |

## Verification refresh — 2026-10-22 (unlocked session)

| Gate | Result |
|---|---|
| `make lint` | PASS |
| `make test-core` | PASS: Core 291, Platform 32, Rendering 48, Runtime 77 (**448 total**), including V6 all-edge alpha-margin assertions |
| `make test` package stage | PASS: same 448 package tests |
| `make test` UI stage | PARTIAL: launch/status-item/Quit passed; Settings test failed after 53 s waiting for the menu-open notification (`PetScapeSettingsTests.swift:30`) |
| Debug build | PASS with Swift/GCC warnings as errors after the V6 canvas-margin correction |
| Release build | PASS with Swift/GCC warnings as errors after the V6 canvas-margin correction |
| `make run` launch | PASS after the V6 canvas-margin correction; app loaded 10 clips at 16,588,800 decoded bytes and logged cat spawn on Dock |
| Focused UI launch/Quit test | PASS after the correction; the current Debug app was then relaunched from the updated build |
| Native owner review | PASS by owner report (2026-10-22): “subiu sim, ficou ótimo.” This confirms the climb was visible and the result looked good to the owner; no quantitative native paw-offset measurement was reported. |

The UI suite initialized in the unlocked session, so the earlier Automation Mode startup timeout is
no longer the current result. The Settings failure is a menu notification/automation failure; it
does not verify or falsify the edge-climbing behavior. The first visual inspection of the exported
V6 frames found a clipped ear; the export was corrected, and automated margin assertions and both
build configurations pass on the correction. A focused UI launch/Quit test also passed, allowing a
clean relaunch of the updated Debug build. Startup logs again confirm loading and Dock spawn only,
not climbing. The full `make test` was repeated after the correction: all 448 package tests passed;
the Launch/Quit UI test passed; the Settings UI test again failed at its menu-open notification
after 53 seconds. The latest Debug app was relaunched after that run.

## Owner closeout — 2026-10-22

The owner reported that the cat climbed and that the result looked great, accepting the native
visual result and V6 art. M11 is closed by owner acceptance. Deterministic tests cover both wall
directions, mirrored alignment, top exit and continuous falling back to a supported surface; the
asset test checks paw alignment at the bundled 96 pt size and transparent margins. The owner did
not provide a measured native paw offset, so no such measurement is claimed.

The Settings UI automation failure recorded above is a menu notification issue and does not test
M11. All package tests and both build configurations passed after the final art correction.
