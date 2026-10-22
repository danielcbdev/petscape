# M10 cursor, click and drag contracts

Status: **Engineering implementation in progress under owner authorization (2026-10-18).** Cursor
sample/button contracts, native event-time coordinates, 10 Hz cursor awareness, interaction settings
and preference migration, press reservation, thresholded held motion, zero-impulse drop, bounded click
reaction, lifecycle cancellation and Reduce Motion input are implemented with automated coverage.
Native event delivery/click-through/focus and V5 art remain unverified; the implementation does not
claim native routing or visual acceptance.
[Architecture and API evidence](../architecture/interaction-system.md),
[tasks](../planning/m10-implementation.md), [native gate](../planning/m10-native-poc.md).
Values below are the authorized implementation contract. They are tuning inputs, not measured
latency or new character-manifest fields.

## Scope and settings

First version: bounded cursor observation, hover feedback, primary click reaction, thresholded
pickup, held pose, predictable drop through M7 gravity/contact/M8 landing and autonomous return.
No chase/approach/startle locomotion, double-click command, throwing impulse, scroll gesture,
keyboard interception, window surfaces, climbing or cross-display pet migration.

Two Settings toggles under Interaction:

- **React to cursor**, default true: permits awareness only; independent of autonomy toggle.
- **Allow click and drag**, default true after the native gate passes: permits direct gestures;
  disabling it keeps every overlay/input panel click-through. Explain: “Click to get your pet's
  attention. Drag to pick it up. Pause stops interactions.”

Propose `InteractionSettings: Equatable, Sendable` with `cursorReactionsEnabled` and
`directInteractionEnabled`; add `PetSettings.interaction` with defaulted initializer argument.
Persist version **3** using `petscape.cursorReactions` and `petscape.directInteraction`; absent
keys mean true, legacy v1/v2 values unchanged, unknown future version/keys retained. Restore
Defaults clears only known keys and cancels interaction first. Do not serialize cursor, grab
coordinates, session IDs or intermediate state. No login service behavior changes.

RunState must be running to begin a command. Pause leaves a visible frozen cat but accepts no
click/pickup commands, does not unpause or secretly step a pet. Existing event-driven paused
pass-through housekeeping may remain; it cannot modify simulation. Hidden, full-screen suspended,
occluded, asleep, locked or session-inactive cancels capture and removes input work. Sleep of the
**pet** differs from sleep of macOS: pointer proximity cannot wake the pet, explicit click can,
and direct pickup can interrupt valid sleep.

VoiceOver: keep decorative panels/layers excluded, never make a keyboard focus target. Native
Settings toggles and existing Wake Pet/Pause/Hide supply accessible controls; free-form pointer
placement has no keyboard equivalent in this scope and must be disclosed, not claimed accessible.
For Reduce Motion, read the public NSWorkspace accessibility display setting and its change
notification through Platform; suppress optional cursor/click expression motion (held fallback),
keep intentional drag and required gravity/contact functional. No extra permission. Focus/typing
and VoiceOver menu/Settings navigation are manual gates.

## Units and observation

Canonical cursor, target and foot coordinates are **AppKit global points, y-up**. `mouseLocation`
already has that meaning. World logical coordinates are the same space. Non-flipped render
coordinates subtract the host screen origin through CoordinateConverter; input-panel-local
coordinates instead use the actual input panel origin. Native queued events must convert their
`locationInWindow` using their receiving window's origin; do not stamp an old event with a newer
mouseLocation. CoordinateConverter owns pure conversion math; adapter supplies native geometry.
Quartz/CGEvent coordinates would need the existing primary-height y flip, but no CGEvent source
is required here. SpriteKit has no live space in this architecture.

Retina scale is for decoding/mask pixel lookup, never cursor/offset/threshold multiplication.
Test host origins (0,0), (−1920,0), (0,−1080), different heights, 1×/2× backing and scale 0.5/1/1.5.
Screen/Dock changes invalidate cached converter/target data before next input. Ordinary Space
switch cancels active gestures conservatively; confirmed full screen follows existing hide gate.
No promise to eliminate the detector's historical confirmation delay is made by M10.

| Parameter | Initial contract |
|---|---|
| Behavioral sample interval | Active 0.1 s; pet sleeping 0.5 s; inactive runtime 0 |
| Route sample interval | Immediate movement events + each existing render frame, no new timer |
| Perception distance | Shortest distance from cursor to current spriteRect; enter ≤120×scale pt, exit ≥160×scale pt |
| Interaction radius | Current coarse alpha mask only; no extra circular capture radius |
| Dwell | 0.35 simulated seconds continuously in enter zone; in band retain current interest, do not accumulate new entry dwell |
| Lost interest | Outside exit radius for 0.75 simulated seconds; reset dwell |
| Observation duration | 1 + 2×curiosity seconds, at most 3 s; no RNG per sample |
| Reaction cooldown | 8 simulated seconds after cursor reaction/click/drag finishes; proximity while cooling never queues a reaction |
| Eligibility | Valid grounded Walk/Idle/Observe, stateElapsed≥0.5 s, energy>0.25, expressions enabled, no reservation/capture/flight/transition; autonomy disabled still allows enabled explicit cursor reaction |
| Primary drag threshold | Euclidean distance ≥4 pt from down point (squared distance≥16), independent of DPI and pet scale |
| Click reaction | On valid primary up within threshold and over same current pet mask; 0.6 s bounded expression, 0.5 s repeat cooldown; no effect for release off-pet |
| Direct sample freshness | Reject down if latest target snapshot is unavailable; always re-hit-test down against latest rendered mask; stale timestamp older than last accepted event is ignored |

Curiosity comes from existing `Personality` [0,1], energy from `Needs`. Default cat manifest has
no personality field, so current Core defaults 0.5 apply. Observe changes facing at most once
on entry toward the pointer (deadband ±8 pt around foot), no repeated turn flipping and no eye-bone
tracking system. Cursor movement refreshes interest only, not duration: max 3 s prevents permanent
hover captivity. Pointer beyond the host screen loses interest; the cat never pursues it.
Hysteresis/dwell/cooldown use fixed simulation dt, not event count or wall-clock jumps.

## Proposed typed boundary (names fixed for task handoff)

These declarations are documentation of future APIs, not existing symbols.

- Core `InteractionID`: Sendable/Equatable wrapper around UInt64, Runtime monotonic counter for
  the controller's lifetime, never reset by stop/start; zero reserved. Invalidate callbacks with a
  separate Runtime lifecycle generation before teardown; old-controller weak callbacks cannot
  address a new controller. Reject acquisition on counter exhaustion rather than reuse an ID.
  Pair it with existing `PetID`, never character ID or array index.
- Core `InteractionCommand: Equatable, Sendable` cases:
  `press(InteractionID)`, `beginHold(InteractionID, target: CGPoint)`,
  `moveHold(InteractionID, target: CGPoint)`, `release(InteractionID, target: CGPoint)`,
  `cancel(InteractionID, reason: InteractionCancellation)`, `click`,
  `observeCursor(location: CGPoint)`.
- Core `InteractionCancellation`: `paused`, `hidden`, `suspended`, `spaceChanged`,
  `geometryChanged`, `settingsChanged`, `petUnavailable`, `captureLost`, `stopped`.
- Add `WorldInput.interaction(PetID, InteractionCommand)`. Existing `apply(_:)` remains void;
  add `WorldEvent.interactionAccepted(PetID, InteractionID)` for accepted press,
  `interactionEnded(PetID, InteractionID)` for release/cancel, and
  `interactionRejected(PetID, InteractionID)` for invalid session-bearing commands.
  Runtime drains acknowledgement events synchronously before enabling capture; all log switches
  must handle these without cursor coordinates. Click/observe commands require no capture ack.
  `beginHold`/`moveHold`/`release` acceptance is checked against the world-owned current session
  and resulting held/released state in the submit adapter; do not emit/log one accepted event per
  move. The submit Bool is acknowledgement only, never a second authority or body mutation.
- Core `InteractionSession`: Sendable value reducer used by Runtime, with phase available,
  hovered(PetID), pressed(PetID, InteractionID), dragging(PetID, InteractionID); down location,
  foot offset and latest target. It produces commands, never changes Pet. Unknown/up duplicate
  inputs return no command. It has one active primary owner for now; target IDs permit future pets.
- Core `InteractionTuning`: Sendable/Equatable injectable values from the parameter table.
- Runtime `InteractionController`: MainActor final class; initializer injects hit-testing,
  `submit: (PetID, InteractionCommand) -> Bool` (Runtime applies/drains accepted facts),
  `setCapture: (InteractionID?) -> Void` and tuning. Methods
  `handle(_ event: OverlayMouseEvent)`, `update(with sample: CursorSample)`,
  `cancel(reason: InteractionCancellation)`. It reads a snapshot/context supplied by Runtime;
  no direct Pet mutations, native monitor installation, or independent scheduler inside it.
  Add `OverlayCoordinator.onWillInvalidateInteraction: ((InteractionCancellation) -> Void)?`,
  invoked before visibility/host/panel mutation and before stop removes callbacks. Runtime wires
  it to controller.cancel. Add an ordinary-Space-change callback to existing SystemEventsMonitor
  rather than implementing a second workspace observer service.
- Extend `CursorSample` with primary-button-down (defaulted initializer compatibility); keep
  `isButtonDown` for rejecting external gestures. Extend `OverlayMouseEvent` with button identity,
  primary default on existing constructors. No double-click metadata needed in first version.

Public API additions are restricted to cross-module command/value seams. World session fields,
press reservation, held target and resume bookkeeping remain internal. Tests pin these contracts
before client integration; deprecated old pass-through APIs may remain convenience wrappers
until all current callers/fakes have migrated in the same task.

## One authority and event lifecycle

On down: require running, direct enabled, primary button, latest valid visible pet hit and no
other capture. Re-hit-test current mask, allocate session, compute **offset = cursor − Pet.position**,
submit press; latch capture only after acceptance. A down missed by WindowServer cannot be
recovered/reposted. Right/other buttons and drags started elsewhere never create sessions.
A sequence accepted by the OS for our input panel may still consume secondary/scroll events
while enabled; this must pass the native non-interference matrix or the strategy fails.

A press reservation freezes that pet's underlying HSM, body, needs and activity timers immediately
at its current foot while waiting for the 4 pt threshold, so switching authority does not cause a
walking/jumping pet to snap to an old offset. This is deliberate touch-down feedback, not a new
behavior engine. Store remaining activity duration at press and restore relative to current world
time on non-drag release, because world time still advances. Do not restore stale absolute
activity deadlines or add elapsed wall time. Other pets would keep running in a future version.
Held-button press may last arbitrarily long; cancel on availability/lifecycle loss, not an
arbitrary timeout while the user still holds the button. A lost up is handled below.

At threshold: cancel pending jump/preparation once, finish autonomous activity through existing
cooldown bookkeeping, clear attachment and residual velocity; enter `PetState.held`, reset
stateElapsed and airborneElapsed once. `beginHold` supplies target `cursor − offset`. World
alone clamps and commits it; it is not stepped by PhysicsStepper. Hold does not deplete energy
or select activities. Presentation runs fixed dt, even for held fallback. No long animation may
block authority transfer. Press reservation is replaced by held session, not stacked.

Each frame: (1) apply latest environment/cancel first; (2) sample primary button and cancel/release
if needed; (3) coalesce latest pointer move; (4) submit command before ordinary fixed steps;
(5) PetWorld validates ID/body and commits held target at most once per step; (6) animate; (7)
snapshot → layers → masks → input-panel placement/gating. Existing per-frame cursor pass-through
check also uses the just-rendered snapshot. Event callbacks may synchronously apply begin/end
between steps, but do not advance simulation time or run extra physics steps.

Mouse-up applies its **final target atomically with release** before clearing session, so a queued
move cannot be applied after up, and the last movement is not dropped if no display frame occurred.
Set velocity exactly zero, clear attachment/jump plan, enter existing airborne.falling, reset
watchdog once and release capture immediately (no need to wait for landing). Next fixed step uses
ordinary gravity/swept contact. Do not apply gravity and drag movement in the same step. Repeated
up/cancel or stale generation/session IDs are idempotent, cannot release a newer capture.

For primary up without drag: clear reservation; if up still hits same pet emit click, otherwise
resume saved HSM/timers without reaction. Sleeping click uses existing wake input/0.5 s waking
phase rather than forcibly entering observe. Awake valid grounded click uses bounded
`GroundedState.reactingToClick`; airborne click just resumes prior flight (no midair rest pose).
Double click is two normal click attempts subject to the 0.5 s reaction cooldown; no delayed
single-click timer and no second special action. Hover/exit are reducer facts, not new locomotion.

## State, priorities and resumption

Safety and runtime permission checks precede input even though historical presentation priorities
list grab=100 and safety=90. Do not sort all events by these integers. Proposed ADR-0021 narrows
that interpretation: invalid body/host wins, stopped run state cancels, valid held ownership wins
over ordinary behavior, then explicit click, eligible cursor reaction, autonomous choice. Surface
loss while pressed cancels reservation first then uses existing falling; a held pet has no surface
to lose. World recovery must clear every input reservation/session.

| Layer / state | Entry/exit and motion | Clip, threshold, min/max |
|---|---|---|
| Runtime hovered | Current mask hit, no button; exit mask/availability | No phase/clip, zero world authority |
| Runtime pressed + world reservation | Accepted down; release→resume/click, ≥4 pt→held; safety cancels | Existing frame frozen; direct command guard, 0/unbounded while primary held |
| Core grounded.reactingToCursor | Eligible dwell command; exit far grace or duration | `curious` → held idle fallback, grounded hold; presentation priority 50, threshold 80; 0 / 1–3 s |
| Core grounded.reactingToClick | Valid awake grounded click; exit timer | `curious` → held idle fallback, grounded hold; presentation priority 80, threshold 90; 0.6 / 0.6 s |
| Core held | Accepted beginHold; finite host-clamped pointer target; release/cancel | `picked-up` for 0.2 s then `held`; held fallback if absent; direct/critical entry 100; 0/unbounded with valid button/session |
| Existing airborne.falling | Release atomically, current target and zero velocity | Existing fall/fallback, gravity; existing 3 s safety watchdog |
| Existing grounded.landing | Existing swept contact, same settle behavior | Existing landing, 0.1 s; then return policy |
| Existing recovering | Invalid coordinates/removed host/impossible geometry | Invisible bounded existing placement; clear reservation/capture before placement |

Each reaction saves only eligible activity kind, remaining duration, facing and return intent.
At end restore Walk/Idle/Observe if support/state/settings/energy still eligible; otherwise one
existing bounded Idle then selector at a decision boundary. No RNG per pointer sample. Do not
resume a captured jump plan or exact sleep timeline after a pickup. Pickup cancels activity once;
after landing use 2 s existing bounded Idle, then normal M9 selection (or saved explicit Walk/Idle
when autonomy disabled). Forced low-energy rest wins at the next ordinary decision; no negative
energy bonus/penalty from petting. Reaction/drag cooldown starts at completion/cancellation,
all simulated and frozen by Pause. No nested reaction stack or queued reaction burst.

## Drag geometry and release matrix

Use down-time global foot offset unchanged while pressed/dragging; freeze facing until release.
Keep canonical foot anchor stable across optional clips (V5 contract). For current effective
anchor `a` and sprite size `(w,h)`, constrain desired foot to
`[host.minX+a.x*w, host.maxX−(1−a.x)*w]` and
`[host.minY+a.y*h, host.maxY−(1−a.y)*h]`, using effective mirrored anchor for asymmetric packs.
The clamp keeps the entire canvas visible, so bottom release may fall a few points onto the floor.
If a future huge canvas has no legal interval, cancel and use existing bounded recovery rather
than construct a reversed range. Resizing settings cancels before geometry changes; do not rebase
an in-progress grab silently. Empty screen sets suspend/wait, never poll-retry.

M10 is confined to the current hosted screen. Cursor crossing to another display clamps at the
host edge; release falls there. This deliberately leaves FR-29 to M14. Host removal/change ends
the sequence and uses existing exceptional recovery, never a partially implemented handoff.

| Scenario | Required outcome |
|---|---|
| Above valid Dock/floor | First descending swept foot contact using current SurfaceMap; zero release impulse |
| Exactly on valid support | Existing contact epsilon/sweep should give a single landing; test exact y; if needed reuse contact primitive, no nearest-surface snap |
| Near Dock edge / visible icon | Dock stays above input; release collides with existing full-width estimated top, not icon geometry |
| No support immediately below | Fall to hosted floor; ordinary missing support is not a respawn |
| Outside host safe rectangle / display gap | Clamp target before release; impossible/nonfinite target→existing recovery |
| Dock moved/resized/auto-hide notification during sequence | Cancel capture before applying geometry; pressed resumes then support reconciliation, held→zero-velocity fall using new surfaces on next eligible step |
| Monitor removed / host changes | Cancel then existing host-loss recovery; if no screen, wait without frames |
| Pause/hide/suspend/lock during held | Clear capture immediately; record falling at last valid target without stepping; hidden follows RunState; resume reconciles surfaces, seeds clock then falls |
| Pet replaced / panel destroyed / stop | Invalidate session and callbacks before removal; no stale up may mutate new pet; stop does not require a visible landing |
| Lost native up | Sample primary bit each 60 Hz pressed/held frame; primary false→release at latest valid target exactly once, no click reaction inferred |
| Primary still down, secondary released | Stay held; any-button Bool alone is insufficient |

Lifecycle notifications cancel even when frames stop, so the recovery path never depends on a
watchdog timer running during suspension. A retained primary-down without motion remains held;
we do not invent a release. If native input becomes unavailable (monitor/view loss), cancel at
last known finite target rather than waiting forever. No fling estimator, mouse history, synthesized
input, global key monitor or Escape interception. An explicit Pause/Hide/disable is sufficient
accessible cancellation.
