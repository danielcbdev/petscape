# Physics Engine

Status: **Implemented; M7 Done by owner acceptance (2026-10-18).** Pure helpers and live world/runtime adoption are tested.
Visual/platform/performance acceptance remains open; see execution evidence in task-breakdown.md.
Decisions: [ADR-0005](../decisions/0005-kinematic-physics.md),
[ADR-0016](../decisions/0016-physics-state-and-recovery.md). Existing loop:
[ADR-0013](../decisions/0013-simulation-loop.md), amended by
[ADR-0015](../decisions/0015-core-animation-renderer.md).
Baseline/code inventory: [technical review](../planning/m7-m8-technical-review.md).

## Baseline and adopted implementation

At HEAD `2f7f33f`, PetWorld directly advances Pet.position along one selected surface; there is no
velocity or airborne integration. Surface loss uses recovering → spawning → same-x resettle or
random placement. The adopted implementation below replaces ordinary support loss with physics.
PetWorld commits Pet.position/velocity and owns physical phases. Internal PhysicsTuning,
ContactGeometry, MovementIntent, PhysicsStepResult and PhysicsStepper validate finite values,
positive geometry/scale, bounded dt and overflow before terminal clamping. Runtime consumes the
world's explicit demand and composes a persistent hosted floor with the optional Dock.

Use small custom kinematics in Core. No rigid bodies, materials, polygon solver, SKPhysicsWorld,
SKAction, CAAnimation trajectories or extra module. Core Animation only draws snapshots. Preserve
world ownership, existing callbacks and the single CADisplayLink. M8 reuses this stepper via
[Jump System](jump-system.md); windows/climbing remain M11–M13.

## Data and ownership

| Concept | M7 representation and invariant |
|---|---|
| Position | Existing `Pet.position: CGPoint`, global foot contact. Only PetWorld commits it, including spawn/reproject/recovery; stepper returns a candidate, never a stored second position |
| Velocity | Add `Pet.velocity: CGVector`, pt/s, finite; attached dy = 0; reset on safe placement. Do not introduce a KinematicBody that duplicates position |
| Acceleration | `CGVector`, pt/s², ephemeral input; airborne `(ax, ay − gravity)`, grounded desired horizontal speed, no integrated gravity |
| Gravity | Positive magnitude in PhysicsTuning; world y-up means acceleration.dy = −gravity |
| MotionState | Existing PetState refined to spawning / grounded(GroundedState) / airborne(AirborneState) / recovering(reason); no stored independent motion enum |
| ContactState / SurfaceReference | Existing optional SurfaceAttachment(surfaceID, parameter) is the sole contact representation; grounded requires non-nil valid attachment, airborne requires nil. No separate mutable ContactState |
| SimulationStep | Existing `Double dt` in seconds + FixedStepAccumulator.step; no new clock/time wrapper |
| Result | Proposed internal `PhysicsStepResult`: position, velocity, attachment, edgeReached, landedSurfaceID; computed, consumed once by PetWorld |
| Motion input | Proposed internal `MovementIntent`: `.hold`, `.walk(speed: Double, facing: Facing)`, `.airborne(acceleration: CGVector)`; never writes position |

PhysicsTuning is an injected Sendable value (not global mutable state); reuse BehaviorTuning for
speed/turn policy. PhysicsStepper and result remain Core internal. No new preferences keys or
manifest fields in M7/M8. Public impact: Pet gains readable velocity and stable visual-margin storage; PetState cases/WorldEvent
cases expand; PetWorld's timestep validation and frame-demand query change. All exhaustive switches,
tests and runtime logging must migrate together in T7.4–T7.6.

## Units, tuning and logical volume

All defaults below are provisional for visual calibration, except the existing loop limits.

| Name | Value / units | Purpose |
|---|---|---|
| gravity | 2400 pt/s² | Existing planned gravity; downward |
| terminalFallSpeed | 1800 pt/s | Clamp dy ≥ −1800; no clamp on jump ascent to a fall limit |
| fixed step | 1/60 s | Existing accumulator reference |
| maxStepsPerFrame / maxFrameDelta | 5 / 0.25 s | Existing stall cap |
| contactTolerance / timeTolerance | 1e-6 pt / 1e-9 s | Contact comparisons / step comparison; never expand a collision by visible pixels |
| maxAirborneDuration | 3 simulated seconds | Stuck watchdog; reset only on takeoff/detach, not at apex |
| outOfBoundsMargin | Existing BehaviorTuning 8 pt | Foot outside host frame plus margin triggers recovery |
| logicalWidth / logicalHeight | 0.5 × displaySize.width / 0.625 × displaySize.height | 48 × 60 pt for 96 pt cat; scale with pet.scale; stable across clips |

Proposed `ContactGeometry` holds halfWidth and height computed once per pet from validated
`displaySize × scale`. Logical box is `(x − halfWidth, y, width, height)`, independent of tail,
image alpha, pose and animation anchor. Foot contact remains `(x,y)`, including in flight (virtual
foot reference). Collision support requires the whole logical width on a surface. For a narrow
surface (< logical width), reject landing; do not use Surface.walkableRange's midpoint fallback
as proof of support. Initial floors/Dock are full width.

Keep a separate **stable visual screen margin**: existing max(anchor.x,1−anchor.x) × width from
resolved `walk` (or default) clip at spawn, not current clip. Ground walking range is intersected
with that margin, preserving AC-08. Landing range uses logical width plus host-screen visual bounds;
no tail-driven platform collisions. V4 must fit the same visual envelope. Geometry stays points;
backing scale affects decoded image size only. Global → overlay conversion remains exclusively
CoordinateConverter; normalized anchors remain a Rendering concern.

## Time integration

Continue using CADisplayLink.timestamp (monotonic uptime seconds), FixedStepAccumulator and Runtime
frame(timestamp). First frame seeds timestamp. Positive frame delta is clamped to 0.25 s, at most
five 1/60 s steps execute, excess whole steps are discarded, substep remainder < 1/60 retained.
Invalid/nonpositive/backwards timestamps do no work, as the current accumulator specifies.

World/stepper accept finite `0 < dt <= 1/60 + 1e-9`; dt within tolerance of 1/60 normalizes to 1/60.
Invalid/larger dt leaves time, pets, events and random source unchanged. Runtime always supplies
1/60; there is **no nested accumulator or hidden substepping**. Existing large-dt walking tests
must execute equivalent fixed steps while retaining speed/rate assertions; add direct rejection tests.

For airborne motion (semi-implicit Euler), with h = dt:

```text
v1.x = v0.x + ax*h
v1.y = max(v0.y + (ay − gravity)*h, −terminalFallSpeed)
p1 = p0 + v1*h
```

M7 uses ax = ay = 0 after detach, horizontal momentum is preserved. Walking sets desired vx from
`walk.nominalSpeed ?? fallbackWalkSpeed` × speedScale × scale with facing sign; gravity is suppressed,
y is attachment surface.y, x advances by vx*h within the stable walk range. Turning holds position,
vx = vy = 0 for existing turnHold. Remove positional integration from the old walk helper when
world adopts the stepper; walking policy produces only intent/edge transitions.

## Swept landing and continuous contact

Surface geometry is constant for a step. Runtime commits notifications synchronously between steps;
no mid-step callbacks. Reject nonfinite surfaces/zero width from collision candidates, with one
transition diagnostic when environment changes (no string formatting in the tick).

For descending motion (`v1.y < 0`, `p1.y < p0.y`) test each horizontal surface in the host world:

1. Crossing: `p0.y >= y − epsilon` and `p1.y <= y + epsilon`.
2. `lambda = clamp((p0.y − y)/(p0.y − p1.y), 0...1)`; evaluate
   `xHit = p0.x + lambda*(p1.x − p0.x)` at crossing, **not p1.x**.
3. Require xHit in `[minX + halfWidth, maxX − halfWidth]` within epsilon, plus stable visual
   screen bounds. A near-boundary epsilon clamp changes x by at most epsilon.
4. Choose smallest lambda (first/highest crossed surface); treat hits as tied only when their
   vertical separation is ≤contactTolerance (equivalently |Δlambda| × |p0.y−p1.y|≤epsilon). Dock before
   floor, then SurfaceID.rawValue lexicographic. Never depend on dictionary iteration or input order.
5. Commit `(xHit, surface.y)`, set velocity to zero, create attachment with parameter(atX:),
   emit one landed event, enter Landing. Discard unused fraction of this fixed step; no bounce,
   second landing or horizontal drift in impact step. M8 solver uses the same convention.

No collision ascending, from underneath, or against a surface above the start point. A foot exactly
on a floor with negative velocity lands at lambda 0 once; attached contact skips the sweep next step.
This catches terminal-speed crossing of a zero-thickness mathematical line (including the legacy
“1 pt thick” acceptance case); it needs no extra substeps for tunneling prevention.

Continuous contact: valid attachment + foot in support interval + |foot.y − surface.y| ≤ epsilon
means grounded. Physics maintains y exactly; no repeated landed events. Movement to an edge turns
by default; explicit loss of support detaches once. Logical and visual ranges have distinct jobs.

## Surfaces and environment transitions

Reuse Surface, SurfaceID, SurfaceMap diffs, DockGeometryEstimator and DockSurfaceProvider. Add a
pure floor builder in Core (refines old T7.3 ScreenEdgeSurfaceProvider proposal):
`SurfaceMap.screenBottoms(for: [ScreenDescriptor]) -> [Surface]`. Platform already provides all
geometry; a new observer-owning provider adds no value. Runtime merges the preferred Dock walkway
with host floor, deduplicating by SurfaceID; collision world contains only the currently hosted
screen until M14, although the builder can produce floors for all descriptors.

Separate **preferred spawn surface** (existing spawnSurface Dock-first) from **existing contact**.
Adding a Dock must not move a pet already on a surviving floor. Attached, same-ID Dock resize or
manual offset reprojects the existing parameter and clamps visual bounds (M6 behavior). This is an
explicit environment correction, resets velocity, does not emit a physical landed event. Surface
removal on a surviving host detaches in place → visible Falling → swept landing. No random respawn
for ordinary surface loss. No fall onto a floor on a non-hosted screen.

| Environment input | M7/M8 policy (automated coverage; manual closure accepted by owner report) |
|---|---|
| Bottom Dock hidden or moved left/right, same host | Remove Dock, retain floor; detach once with current vx, start Falling, land on floor; default 64 pt reservation fall < 1 s |
| Auto-hidden Dock reveals on hover | No new notification/geometry; keep floor contact and level below Dock; no polling |
| Dock shown again while pet is on floor | Keep floor contact. No instant elevation; M8 may explicitly request a reachable floor→Dock jump |
| Dock resize/offset while attached | Same-ID reproject/clamp through world; no competing runtime coordinate write |
| Dock geometry changes during flight | Keep current body; cancel jump target if changed (M8); sweep current valid surfaces only. Surface newly raised above foot cannot capture from underneath |
| Dock host moves or display removed | Existing overlay-host selection wins. Cancel flight; exceptional world recovery places once on preferred valid host surface, clamped same x if usable, else existing seeded place; log reason. Not a physical teleport during ordinary flight |
| Resolution/scaling/arrangement | Rebuild converter/host geometry before next step; valid attachment reprojects; airborne still inside host continues with current state, otherwise coordinated safe recovery |
| Space change | Existing detector decides visibility/suspension. Ordinary desktop Space preserves state; confirmed full screen stops/hides. No new Space polling or clock |
| Pause/hide/sleep/display sleep/lock/session/occlusion | Freeze integrated motion, velocity, elapsed and animation; no steps/catch-up. Existing between-step same-ID reprojection/explicit offset may still correct geometry as in M6; removed-support fall waits until resume. Visibility remains RunStatus policy |
| Resume | Existing coordinator refreshes descriptors; apply latest geometry, resolve invalid contact before advancing; reset accumulator so first callback only seeds time |
| No screens or no valid recovery surface | Suspend/no frame demand; keep pending placement, wait for notification. No retry timer or busy loop |
| Nonfinite body / foot outside host + margin / airborne > 3 s | Enter existing recovering pipeline; clear velocity/attachment/jump plan; invisible until one bounded safe placement; emit one recovery event |

Recovery uses world.place/resettle through runtime-fed inputs, not a second recovery service. Ordinary
surface loss becomes a physical event; exceptional recovery remains necessary when no continuous
path exists (invalid numbers/removed display). Recovering attempts placement at most once per valid
step; if no safe surface exists, spawning waits for an environment update, no repeated events.
Validate airborne pets too (HEAD validates attached pets only). Landing completes by a bounded
simulation timer (M7 0.10 s provisional); missing art cannot hold Landing forever.

## Fixed update order and frame demand

1. MainActor environment callback: screens → Dock/host/overlay → world screens + merged surfaces.
   Resolve attachment reprojection/detachment in world; callbacks cannot interleave a world step.
2. Frame driver → existing accumulator; for each eligible step, validate input and reconcile contact.
3. Existing PetState handles safety/events and produces MovementIntent; M8 launch timer is processed here.
4. PhysicsStepper computes motion and sweep; PetWorld commits position/velocity/contact once.
5. Emit typed `WorldEvent.surfaceLost(PetID, SurfaceID)`, `landed(PetID, SurfaceID)`, edge/state
   events; M8 adds tookOff/apex. Safety wins over ordinary requests; duplicates cannot retrigger.
6. Resolve resulting locomotion and animation request in the same step (contact shows Landing immediately).
7. Advance animation dt; frame events remain presentation output; validate final finite/host invariants.
8. After all steps publish snapshot → renderer → hit tester; coordinator samples cursor against that snapshot.
9. Recompute work demand from world; gate the existing driver with RunStatus. No independent scheduler.

Implemented `PetWorld.needsSimulationSteps: Bool` includes walking/turning, airborne, Landing timers,
M8 preparation and pending recovery/placement when a usable surface exists. `needsAnimationFrames`
includes a visible clip actually advancing. `PetRuntime.renderNow` uses their OR for
OverlayCoordinator.needsFrames; only actual demand false resets accumulator. System/user permission
always dominates demand. Replace attachment-based visibility with state validity (grounded AND
airborne visible; spawning/recovering hidden). Add `PetRenderState.isAnimating: Bool` (public initializer argument default true preserves current
constructors); world sets it from actual playback (loop/unfinished once, positive rate, non-held
presentation), not from physical/timer demand. RenderSnapshot.isAnimating becomes any visible pet
with this flag. Runtime scheduling uses world queries so a still/hidden recovery snapshot cannot
stop physics. No stored position or separate scheduler is added.
While running permission has zero work demand, actual driver pause must enable event-driven
cursor monitoring if visible/unoccluded (current RunStatus assumes permission equals active driver;
T7.6 refines coordinator effective-frame policy, preserving click-through without polling).
On demand false→true or host driver replacement, reset accumulator as well; on new environment,
recompute demand even with zero elapsed steps. Retain the 2f7f33f regression as a liveness test.

An idle looping clip still needs animation updates; a held frame on a static floor needs none.
M7's default walking remains at preferred 60 fps; static-paused work stays ~0. In M8, physical
movement/preparation/landing requests 60 fps; grounded Idle with a real loop requests 30 fps through
the existing coordinator (driver accepts 15 minimum, at most four fixed steps per callback). A held
static Idle has no frames once its bounded simulated cooldown expires and no reconciliation is pending. Do not lower animation-only rate below this envelope now: below 12 Hz,
five-step backlog dropping would slow simulation timers/animation; M9 must review its sleep-rate
policy against this cap before adding lower rates. M8 preparatory/landing timers need fixed steps
even with a held fallback. No interpolation now: snapshot and hit masks
match exactly. Consider only if measured judder justifies it; future interpolation must flush history
on recovery/reprojection, or it draws through the Dock and desynchronizes hit tests.

## Verification and measurement contract

Tests drive explicit dt and SeededRandomSource. Cover semi-implicit values (from rest at y=100:
first dy=−40, y=99⅓ at h=1/60), acceleration, terminal clamp, swept x at crossing, ties, exact
contact, narrow/removed/raised surfaces, nonfinite body/geometry, 10k seeded terminal drops,
continuous contact, step rejection, stable replay, and frame-demand suspension/recovery.
Acceptance IDs and task ownership are in [acceptance-criteria.md](../planning/acceptance-criteria.md).

Measure Release outside Xcode with existing frame/simulationStep/render signposts: walk/fall/land,
paused/hidden/full-screen, after 30 s warmup, ≥ 60 s per scenario, current hardware/settings logged.
Physics only executes for required simulation steps. Reuse result/event/snapshot storage; single
linear sweep over small stable arrays, no filtering/sorting/allocation in the frame path. Target
step p95 ≤ 0.3 ms, moving CPU ≤ 5%, paused/hidden ≤ 0.2%, ≤ 1 idle wakeup/s, footprint ≤ 100 MB.
Compare with a rerun of HEAD 2f7f33f under the same conditions and historical M6 2.06%; >20%
regressions require explanation and owner acceptance. No future performance claim is made here.

## Implementation details verified in review

Swept contact uses two allocation-free linear scans: find highest eligible crossing, then choose
Dock/lexical ID within its epsilon band. This prevents insertion-order drift in near-equal chains.
Only a moved attached surface reprojects a body; unrelated surface changes preserve exact position.
Held Idle wakes on lost/invalid support or invalid/out-of-bounds body when a usable surface exists.
Without a usable surface the world waits for a notification. A simulated jump cooldown uses bounded
30 Hz callbacks until expiry, then held Idle stops; pause/hide/suspension freezes this countdown.
