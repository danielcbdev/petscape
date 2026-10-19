# M9 implementation plan

Status: **Done by explicit owner acceptance, 2026-10-18.**
Implementation, package/build gates, Settings UI automation and a two-hour real-time isolated Runtime
soak are complete. Real SMAppService registration/approval, native frame cadence and the ≥2-hour
installed-app playtest remain unverified; see the execution record.
After temporarily deferring M9, the owner explicitly instructed closing M2/M3/M5/M6 by acceptance
and implementing M9 continuously through completion without intermediate approval stops.
The owner delegates reversible implementation/tuning choices in this execution. Initial defaults
below are the concrete implementation baseline under accepted ADR-0018, to be checked by seeded
scenarios and playtest. No new architecture or dependency; no commit/push/tag/PR/release authorized.
The current checkout intentionally retains the accepted uncommitted M7/M8 implementation.

## Design and initial tuning

Keep PetWorld as sole body writer and the existing Grounded/Airborne hierarchy. Select at simulated
activity deadlines, completion or safety interruption; never draw random choices per frame.
Runtime alone gates time. Existing manifest personality DTO is unchanged; map its optional traits
to finite clamped [0,1] values with 0.5 defaults, retaining sociability.

Energy starts at 0.7, drains at 1/300 per awake simulated second, restores at 1/45 while asleep,
and stays in [0,1]. Sleeping requires rest enabled; energy≤0.08 forces Sleep at the next eligible
decision. Stable weighted candidates: Walk=4, Idle=2, Jump=0.7, Sit=1.5, Sleep=0 when energy>0.25
else 8+10*laziness, Stretch=0.5, Observe=1, Explore=0.8. Curiosity/playfulness/laziness adjust
corresponding base weights with a simple finite linear multiplier (0.5+trait); no utility/top-k.
Invalid weights are unavailable, zero total yields bounded Idle. Exclude an action after three
consecutive selections when an alternative exists. A forced safety/zero-total fallback is exempt.

Durations in simulated seconds: Walk 8–16, Idle 2–5, Sit 8–15, Sleep 30–60, Stretch 1.5,
Observe 3–5, Explore 6–10. Sit-down/stand-up/lie-down 0.3, wake-up 0.5. Jump uses M8 timing,
solver/cooldown and contact. Additional cooldowns: Jump 8 s, Sleep 20 s, Stretch 20 s. A rejected
jump yields Idle for ≥2 s, never recursive selection. Explore uses a short supported walk or a
validated M8 request, no new surface/window/cursor service. A sleeping pet accepts an explicit wake
intent; support loss interrupts every grounded state through the existing physical fall handler.
A walking activity with no progress for 2 s makes a bounded Idle decision, not a recovery loop.

New resting/expression clips are optional: existing idle fallback is safe until dedicated art is
produced. A sleeping fallback holds a pose and never claims new sleep art was delivered. Physical
phases stay simulation driven. Autonomous deadlines keep simulation demand active even with held
art; sleeping display demand is no higher than the selected clip's FPS (held fallback may use 4 Hz
for timed needs). Low-rate callbacks must retain 60 Hz simulated time, without catch-up after pause.
World defaults to autonomy disabled for explicit-command/legacy clients; production Runtime restores
preferences with autonomy enabled by default. Tests explicitly choose the policy being exercised.

Settings use native SwiftUI: scale 0.5–1.5 (default 1), speed 0.5–2 (default 1), autonomy/jumps/rest/
expressions toggles (default true), Advanced Dock offset (existing ±40 pt), Pause/Hide and Restore
defaults. Values apply live, including while paused; resizing updates both sprite/contact geometry,
preserves finite foot position/facing and revalidates planned jumps. Add version-2 namespaced
preferences, preserving v1 pause/hide/Dock values. Unknown future versions are not downgraded.
Restore only known PetScape keys; no domain-wide UserDefaults deletion.

Launch at login uses the public SMAppService.mainApp via an injected Platform seam. Show actual
system enabled/disabled/requires-approval/not-found status and errors, refresh on opening/activation,
no polling. Never register during launch or tests; only the explicit Settings toggle changes the OS
login item. Restore defaults also turns off an enabled login item as an explicit user action.

## Global constraints

Swift 6 strict concurrency, macOS 14+, no dependencies. Core imports Foundation/CoreGraphics/os only.
No network, cursor reaction before M10, window interaction, private API, original asset edit or new
animation schema field. Runtime/Platform/App stay MainActor. No new scheduler. No unasked commits.

## Task 1 — T9.1–T9.6 Core model, selection and execution

Create small Sendable values for Needs, runtime Personality, activity selection, settings and pet
activity bookkeeping under existing Core folders. Extend the one world/HSM; do not add an engine
class. Expose `PetSettings` (scale, speed, behavior), `AutonomySettings` (isEnabled, jumpsEnabled,
restEnabled, expressionsEnabled), `WorldInput.configureBehavior(AutonomySettings)`,
`WorldInput.setDisplayScale(Double)`, `WorldInput.setSpeedScale(Double)`, `WorldInput.wake(PetID)`.
PetSettings defaults use enabled behavior, while a default PetWorld remains explicit-command only.
Use these interfaces verbatim so Task 2 can integrate them.

Tests first: clamped/nonfinite energy/traits; deterministic weighted draws/invalid and zero weights;
three-repeat cap; seed 42 energy 0.05/laziness 1 sleeps within two decisions; explicit wake exits in
bounded time; unsupported sleeping/sitting falls; rejected jumps do not spin; no time advancement
without stepping; exact seeded replay with variable/missing art; no random decisions per frame;
resizing updates contact bounds without NaNs and invalidates a preparation safely. Existing tests
remain intact, updated only to explicitly opt out/in where the default policy is relevant.
Run the new tests RED before implementation; then all package tests GREEN and strict-format lint.
Report changed files, commands/results and limitations in `/tmp/petscape-m9-core-report.md`.

## Task 2 — T9.7–T9.9 Runtime, preferences, Settings and login

Consume Task 1 APIs. Add a small Settings observable model with injected Runtime/preferences/login
service; views only forward intents. Add native Settings access from the status menu. Restore/update
menu pause/hide state correctly. One composition root owns service/model lifetimes.

Tests first: v1→v2 preserves values; invalid preferences clamp; future versions remain intact;
restore known keys only; in-memory parity; live Runtime scale/speed/behavior, including paused/hidden
and midair; fallback sleep demand/time at low FPS with pause/resume; login state/error behavior via
fake service (never register a real login item in tests). UI test opens Settings, changes a value,
restores defaults, closes and quits. Preserve the existing launch/menu test.
Run focused RED/GREEN, `make lint`, `make test`, `make build`, Release with warnings as errors.
Report in `/tmp/petscape-m9-shell-report.md`. Do not enable login on the owner's Mac during development.

## Task 3 — T9.10 verification, review and documentation

Fresh read-only review of the M9 delta, fixing substantive findings with RED→GREEN regressions.
Run deterministic ≥2 simulated-hour behavior replay with seed/decisions/recoveries recorded;
label it simulated. The original plan left the actual ≥2-hour installed-app playtest open until executed; the owner later accepted milestone closure with that evidence gap documented below.
Record original-asset integrity and all automation results without inventing native/long-run proof.
Update architecture/state catalogue, task/status/evidence and usage in the same change.

## Review focus

Low-FPS time loss, held sleep waking demand, unsupported rest recovery, bounded selection after
rejection, repeat policy with one eligible action, settings mutations while airborne/paused,
persistence migration/future versions, login approval/errors and teardown/weak captures.

## Execution record (2026-10-18)

- **T9.1–T9.6 Core:** implemented under PetWorld's existing HSM and reviewed. Needs, finite
  personality defaults, stable weighted selection, repeat/cooldown rules, sleep/wake/rest,
  expression, automatic M8 jump requests, rejection/stuck bounds and live behavior/scale inputs
  have deterministic Swift Testing coverage. The first independent review caught loss of the
  automatic jump cooldown when autonomy was switched off during flight; the fix records it at
  cancellation and six rising/falling/landing re-enable cases passed RED→GREEN.
- **T9.7–T9.9 integration:** Runtime restores enabled autonomy/settings, v2 preferences migrate
  without overwriting future versions, and native SwiftUI Settings/menu/login-service wiring is
  implemented. Login behavior uses public `SMAppService.mainApp`; launch itself never registers.
  The Settings UI test uses an isolated UUID preference suite and fake login service.
- **Package/build gates:** `make test-core` passed 400 tests (Core 262, Runtime 66, Rendering 44,
  Platform 28); `make lint`, warnings-as-errors Debug and Release builds, and the final full `make test`
  passed after the scoped review fixes. Both UI tests passed (launch/menu/Quit and Settings changes,
  Restore Defaults, close and Quit). The pasted failure was a test-query defect: SwiftUI exposed two
  “Settings…” menu items, and macOS exposed `Toggle` controls as `Switch` values rather than checkboxes
  or String values. The test now selects the status-menu item and reads native switch values correctly.
  The UI test uses a fake login service; actual OS login registration/approval and `SMAppService`
  behavior remain **not verified**. No owner login-item state or privacy permission was changed.
- **T9.10 real-time integration soak:** an isolated Release-linked Runtime/Core/Platform/Rendering
  harness ran for 7,206.27 active wall seconds and accumulated 7,201.82 simulated seconds (seed 42,
  1,435 five-second samples, 689 decisions, no non-finite body/energy samples). It exercised all
  eight activities and walking, turning, rising, falling, landing, sitting, sleep transitions,
  waking, stretch and observe; preferred rates included 4, 30 and 60 Hz. The temporary offscreen
  screen and injected real-time frame driver kept overlays outside the visible desktop and avoided
  the current full-screen suspension; this is not a visual playtest, native `CADisplayLink` test,
  or installed SwiftUI app CPU result. Harness process CPU was 93.03 s (~1.29% of the 7,206 s run),
  with RSS 27.6–47.0 MiB. A restricted read-only `leaks` snapshot returned 417 allocations / 20,016 bytes with visible Apple AppIntents/XPC roots; it did not provide a complete final snapshot, so leak growth and PetScape-owned cycles remain unverified. Deterministic 7,200 simulated-second Core replay and this separate real-time Runtime
  integration soak are recorded independently.
- **Data integrity:** all 12 original art files matched their recorded hashes; all 41 V4 checksum
  entries validate. Manifest changes are additive semantic aliases to the existing idle clip. The
  actual six clip definitions, decoded frame count/byte budget and original walk sources are
  unchanged.

The implementation, package/lint/Debug/Release gates and both UI tests are complete. The first M9 UI run exposed selector/value assumptions, which were corrected; the final `make test` passed. A deterministic 7,200 simulated-second Core replay (seed 42, 432,000 fixed steps) made 689 decisions, exercised every activity, launched 35 automatic jumps, made 36 contacts, and had zero recoveries. The optimized Core-only run took 0.173 s; this is a simulated stress run, separate from the two-hour wall-clock Runtime harness. The successful Settings XCUITest validates UI controls and restore behavior with an isolated preference suite and fake login service.

## Owner M9 closeout (2026-10-18)

The owner explicitly approved and closed M9 after reviewing the implementation and test results. The accepted closeout does not assert that unperformed checks passed. Real `SMAppService.mainApp` registration/approval, native sleep frame-delivery cadence and the ≥2-hour installed-app visual playtest remain **unverified** evidence limits. The two-hour isolated Runtime harness and deterministic simulated replay are recorded separately above. No remote CI run, commit, release or tag is implied; CI is authored in `.github/workflows/ci.yml`.
