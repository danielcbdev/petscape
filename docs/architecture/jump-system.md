# Jump System

Status: **Implemented; M8/V4 Done by owner acceptance (2026-10-18).**
Owner-reported tests and numeric evidence limits: [owner closeout](../planning/m7-m8-technical-review.md#owner-m7m8-closeout-2026-10-18).
Prerequisite: accepted and verified [M7 physics](physics-engine.md), particularly contact, visible
flight, frame demand and recovery. Decision: [ADR-0017](../decisions/0017-simulation-driven-jumps.md).
M9 selects activities later; M8 uses explicit deterministic world commands/test or DEBUG triggers.
No autonomous selector, window jumps, climbing, cursor input or drag behavior is included.

## State and intent contracts

Extend the existing PetState hierarchy, not a second state machine:

- `grounded`: Walking, Turning (M7), Idle, PreparingJump, Landing.
- `airborne`: Rising, Falling. `spawning` and `recovering(reason)` remain lifecycle cases.
- Runtime operational states stay in existing RunStateController. Recovery is not a RunState.

The implemented `WorldInput.requestJump(PetID, JumpRequest)` accepts `.vertical` or a target
`SurfaceID` + targetX. `JumpRequest` includes `returnActivity: .walking | .idle` (`ResumeActivity`), rather than inferring intent from the current art. Idle may be selected through
`WorldInput.setActivity(PetID, ResumeActivity)` for M8 tests/DEBUG only; no production menu or new
preferences required. Unknown pet/invalid request returns a typed `JumpRejection` through a world
event, with no state/position change. World accepts requests only while runtime is running; runtime
must drop jump commands while paused/hidden/suspended. Core also checks grounded/contact/recovery.

Per-pet pending `JumpPlan` stores source/target IDs and geometry, initial velocity, predicted impact
time/position, return intent, and a monotonically increasing per-pet request ID. Position remains
Pet.position, velocity Pet.velocity; the plan is immutable launch data, not another body. A request
ID is consumed at most once; duplicates during preparation/flight/landing are rejected. Cooldown
starts at launch (including flights interrupted by geometry changes), uses simulation time, and does
not expire while paused. Newer pending requests never overwrite an active plan.

## Parameters and solver

All initial values are provisional until owner visual calibration, in injected `JumpTuning` (Core),
not frame-count constants or manifest physics fields.

| Parameter | Initial value | Rule |
|---|---|---|
| gravity / terminalFallSpeed | Reuse M7 2400 pt/s² / 1800 pt/s | Exactly the same integrator/collision path |
| preferredApexHeight | 80 pt above higher endpoint | Request preference, not an independent gravity or duration |
| maxApexRise | 120 pt above start | Hard ceiling; reject unreachable elevated targets |
| maxHorizontalDisplacement | 80 pt | Short jumps in either facing, vertical displacement 0 allowed |
| maxHorizontalSpeed | 160 pt/s | Bound all candidate plans |
| preparationDuration | 0.15 simulated s (9 steps) | Independent of sprite duration |
| landingDuration | 0.10 simulated s (6 steps) | Independent of `finished`; no missing-art deadlock |
| jumpCooldown | 2 simulated s | Reject earlier requests |
| maxFlightDuration | 2 simulated s (120 steps) | Solver bound; M7 3 s watchdog still applies to interrupted falls |
| targetTolerance | 1 pt | Actual swept contact position, not analytic prediction |
| clearance | 4 pt | Apex above elevated target; logical box must remain inside host |

Impulse is derived, not separately tuned: analytic `vy ≈ sqrt(2*g*h)` seeds candidate selection,
with `vx ≈ dx / flightTime`. With g=2400 and h=80, analytic vy≈619.68 pt/s; **this is not the
final discrete impulse**. An analytic-only solver at 60 Hz semi-implicit Euler can miss by several
points and does not meet AC-M8-01.

Proposed internal `JumpSolver.solve(from: CGPoint, target: CGPoint, targetSurfaceID: SurfaceID, surfaces: SurfaceMap,
geometry: ContactGeometry, screen: ScreenDescriptor, physics: PhysicsTuning,
tuning: JumpTuning) -> JumpPlan?` is pure and bounded. Enumerate N=2…120 steps, solving the exact
semi-implicit endpoint equation for initial vy (before terminal clamp):

```text
yN − y0 = N*h*vy0 − g*h²*N*(N+1)/2
vy0 = ((yTarget−y0) + g*h²*N*(N+1)/2) / (N*h)
vx0 = (xTarget−x0) / (N*h)
```

Reject nonfinite/nonascending launches, speed/displacement/height bounds or terminal-clamped
trajectories that differ from the candidate equation. Replay each candidate using **M7's real
PhysicsStepper**, including swept x at contact, first surface hit and impact-step remainder discard.
Accept only descending contact with the requested surface, x error ≤ 1 pt, within maxFlightDuration,
and all intermediate logical/visual bounds inside the hosted screen below its menu-bar exclusion.
Use `min(screen.frame.maxY, screen.visibleFrame.maxY)` as the logical ceiling; do not use the Dock
reservation as a lower flight boundary. Source surface is one-way: upward passage is allowed;
descending recrossing can land on it only when it is the first actual hit.

Apex height is sampled from replay, not guessed from sprite frame or interpolated continuous parabola.
Among accepted candidates minimize absolute difference from preferred apex (relative to higher
endpoint), then shorter flight time, then N. If none is safe, reject; no silent target clamp or
random teleport. The bounded search is done on jump request/retarget validation, never every frame.
Its worst-case ≤120×120 steps is measured separately from per-step budget (provisional request-time
p95 ≤4 ms, below a 16.7 ms frame interval); if main-thread request
cost causes a hitch, reduce candidates analytically before replay rather than moving simulation off-main.
No speculative interpolation or general trajectory planner is introduced.

Target selection T8.3 offers same-surface vertical/short horizontal targets and floor↔bottom Dock
within this envelope, on the current host only. Capture current geometry and validate again at
launch. No target selection from unknown real Dock shelf ends or other apps' windows. A short jump
returns to Walking/Idle after Landing; a floor pet may deliberately return to the Dock only via a
valid request, never by surface-add reprojection.

## Transition table

All rows run on simulation time. Safety/environment reconciliation runs before launch/landing timers.
`elapsed` is reset only when entering the destination state. A frame marker cannot cause a transition.

| From | Event / preconditions | Result / postconditions | Invalid / interruption behavior |
|---|---|---|---|
| Walking or Idle | Valid jump request, contact valid, cooldown expired, plan safe | PreparingJump; zero vx/vy, keep attachment/facing; save return intent | Reject unsupported target/cooldown, no state mutation |
| Turning | Jump request | Reject busy; finish existing turn first | No hidden facing flip mid-preparation |
| PreparingJump | elapsed ≥ 0.15 s, captured geometry still valid | Consume request ID once; clear attachment, apply planned velocity; Rising; emit tookOff | Source/target changed → cancel, restore valid grounded return intent or fall if support gone |
| Rising | vy changes from >0 to ≤0 in physics step | Falling; emit apex once, same body | Duplicate apex ignored; never reset airborne watchdog |
| Rising or Falling | Swept descending contact (may coincide with apex in low arc) | Landing, valid attachment, zero velocity, emit landed once | Collision dominates ordinary animation/activity events |
| Falling | No contact yet, within host/watchdog | Continue M7 fall | Above/underside surfaces do not capture |
| Landing | elapsed ≥ 0.10 s, attachment valid | Grounded Walking or Idle per saved return intent; clear active plan | Never depend on loop/finished/fallback duration |
| Any grounded phase | Actual support removed | Cancel preparation/landing; M7 Falling | Timer cannot launch after surfaceLost in same step |
| Airborne | Target removed/moved, source changed | Invalidate plan; continue physical fall/arc with existing velocity, then nearest valid swept contact | No in-air retarget impulse or teleport; mark cancellation once |
| Any | Invalid body/out of host/watchdog/host removed | M7 recovering pipeline, clear plan, safe placement | Return Walking after exceptional placement; no retry loop |
| Any | Pause/hide/system suspension | Freeze exact body/phase/timers; RunStatus controls visibility | Resume with new environment before any step, no catch-up |

At most one safety transition plus one physics phase transition per pet per step; queue remaining
ordinary activity requests to a later eligible step. If apex/contact coincide, emit ordered apex then
landed, finish in Landing. No `finished → idle → jump → ...` immediate recursion. Contradictory
combinations (grounded without valid support, airborne with attachment) go through M7 reconciliation.

## Animation causality and compatibility

Simulation issues animation requests on phase entry: Idle→`idle`, PreparingJump→`jump-start`,
Rising→`jump`, Falling→`fall`, Landing→`landing`, Walking→`walk`. `jump` can resolve to legacy
`jump-air`, and `landing` to legacy `land` when present; otherwise CharacterDefinition's normal
fallback/default path. Core chooses semantic requests; it never rewrites original assets.

- Apply impulse at the fixed preparation deadline, even if `jump-start` is missing, looping,
  longer/shorter or has no marker. V4 authoring aligns its visual extension to that deadline.
- Physics vy crossing emits world apex; choose fall presentation immediately. An asset `apex`
  marker may be inspected, never used to determine trajectory/phase.
- Physics contact starts Landing in the **same step**; authored `contact` is optional visual output.
- Each phase uses a critical-priority (90) request at entry only, so noninterruptible art cannot
  block safety. Restore normal priority for normal grounded states. Walking rate tracks speed;
  jump/idle/fall/landing playback rate uses 1 unless explicitly calibrated independently.
- Idle fallback to walk holds frame 0; airborne fallback holds the default frame rather than
  animating planted walking paws in flight. Preparation/landing may hold default pose while their
  simulation timer continues. A real idle/fall loop advances normally. No new engine frame counts.
- Do not set manifest `next` between these phase clips: AnimationController's automatic chaining
  could switch art before the physical phase changes. Existing unrelated `next` support remains.

The old T8.4/AC-M8-02 event-driven takeoff plan is explicitly superseded by this direction.
V4 timing is reviewed visually but must never change the physical arc in deterministic tests.

## Interruption matrix and no-stuck guarantees

Dock hide/side while preparing detaches and falls; during flight keep body and invalidate target;
Dock shown under an airborne cat is eligible only for a real descending crossing. Same-ID resizing
while attached follows M7 reprojection; during preparation cancels captured plan; during flight
never drags the cat with the surface. Resolution changes revalidate host/bounds and plan; if host
survives, flight continues safely or uses ordinary recovery, not a second placement algorithm.
Space/full-screen/lock/sleep/display sleep/session switching freeze timers/velocity, hide according
to existing RunStatus and refresh geometry on return. User pause/hide similarly freezes. Source or
target mutations during suspension are reconciled before resuming, so no launch uses stale geometry.

Finite flight bound + 3 s physical watchdog + bounded landing/preparation timers prevent hangs.
Once a candidate is rejected, no per-frame retry; wait for an explicit request (M9 may later retry
after cooldown/environment change). Deterministic tests cover duplicate commands, timer boundaries,
same-step surface loss, airborne pause at apex, pending recovery snapshots and both Dock sides.

## Verification

Use explicit dt/seeded inputs, including both facings/scales, target at bounds, stacked occluders,
raised targets and unreachable plans. Assert state sequence, actual swept endpoint error ≤1 pt,
one launch/apex/contact, velocity sign, default walking/idle return, invariant and frame-demand
behavior. Replay identical jumps with 1/8/12/24/32-frame art and no jump art; body trajectories and
state timings must be identical. Loader tests cover invalid/absent clips/frames; runtime tests use
fake screen reader + fake driver. Manual owner review covers V4 art/anchor, Dock/desktop
click-through (≥20 transparent points), focus/VoiceOver and Release measurements. Screen recording
is owner-supplied/opt-in outside the app; PetScape must never request Screen Recording permission.

## Implemented launch and command seams

`JumpRequest.Target` supports vertical, signed horizontal offset and explicit surface/x targets.
`PetRuntime.requestJump(_:)` gates commands on RunStatus; `requestJump(to:)` preserves the current
walk/idle return intent for DEBUG controls. No autonomous selection or preference key was added.
The immutable plan captures the original requested point; immediately before consuming its ID,
the solver replays against all current surfaces and the current visible-frame ceiling and requires
the same plan. A changed intervening support cancels safely. Unchanged support is not reprojected
for unrelated changes, preserving exact launch coordinates. In-flight target loss cancels intent
while keeping physical position/velocity and using current first-hit collision.
