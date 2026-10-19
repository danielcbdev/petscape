# Behavior Engine

Status: **M9 implementation integrated and closed by explicit owner acceptance, 2026-10-18.**
Core and Runtime/Settings code, package/UI tests and Debug/Release builds are complete. Native sleep
cadence, actual installed-app login behavior and the installed-app playtest remain unverified evidence limits accepted at closeout; see [the execution record](../planning/m9-implementation.md#execution-record-2026-10-18). Accepted direction:
[ADR-0018](../decisions/0018-simple-weighted-behaviors.md), superseding historical ADR-0006.

## Ownership and decision boundaries

PetWorld remains the sole body writer. One Grounded/Airborne HSM executes activities; no separate
engine object or movement state machine. Runtime owns clock/permissions/platform facts. Physics
computes candidates, the world commits them, animation presents the resulting phase. A missing clip
or visual marker never completes an activity or triggers takeoff/contact.

Activity choice occurs at a simulated deadline/completion or a safety interruption, never every
frame. The stable candidate order is Walk, Idle, Jump, Sit, Sleep, Stretch, Observe, Explore.
Availability/toggles and simulated cooldowns filter candidates. ActivitySelector performs one
weighted draw using the injected RandomSource. Nonfinite/nonpositive weights are unavailable;
normalization prevents overflow for large finite weights. Zero total gives bounded Idle. There is
no recursive select-until-success loop, utility ranking/top-k, Behavior Tree, GameplayKit or LLM.

After three consecutive selections, exclude that action when another positive eligible candidate
exists. Critical-low-energy Sleep and forced safety/rejection Idle are exempt; when no alternative
exists, a safe available action may repeat. Candidate buffers allocate at decision boundaries,
not as continuous per-frame selection work.

## Needs and personality

Needs stores finite clamped energy in [0,1], initially 0.7. Enabled autonomous awake time drains
1/300 per simulated second; sleeping restores 1/45. Paused/hidden/suspended time does not step,
so it changes neither needs, deadlines, cooldowns nor randomness. Invalid/nonpositive dt is ignored.
Disabling autonomy leaves explicit-command clients compatible with M8.

Personality maps the existing optional manifest curiosity/playfulness/laziness/sociability DTO
into finite [0,1] values with 0.5 defaults. No schema field was added; sociability is preserved for
future interaction rather than inventing pet-to-pet behavior now.

| Activity | Base weight | Simulated duration | Automatic cooldown after completion/cancellation |
|---|---|---|---|
| Walk | 4 × (1.5 − laziness) | 8–16 s | 0 |
| Idle | 2 | 2–5 s | 0 |
| Jump | 0.7 × (0.5 + playfulness) | M8 physical phases | 8 s |
| Sit | 1.5 × (0.5 + laziness) | 8–15 s, plus transitions | 0 |
| Sleep | 0 above energy 0.25; otherwise 8 +10 × laziness | 30–60 s, plus transitions | 20 s |
| Stretch | 0.5 × (0.5 + playfulness) | 1.5 s | 20 s |
| Observe | 1 × (0.5 + curiosity) | 3–5 s | 0 |
| Explore | 0.8 × (0.5 + curiosity) | 6–10 s | 0 |

At energy≤0.08 with rest enabled, the next eligible decision forces Sleep. Activity weights are
ordinary injectable BehaviorTuning data for deterministic scenarios; production uses the table.
The seed-42 tired/lazy scenario enters sleep within two decisions. Separate M8 explicit-jump
launch cooldowns remain intact. Toggling autonomy off during automatic flight records the eight-
second cooldown at cancellation, preserving position/velocity/physical phase until contact.

## Execution and interruption

Walk/Explore use existing supported walking, including edge turning; Explore is a short supported
walk, not a new window/surface service. Automatic Jump submits a validated M8 vertical request;
explicit commands retain their target types. Unreachable/rejected requests produce a two-second
Idle, never another choice in the same call. A walk with no progress for two simulated seconds also
ends in bounded Idle.

Sit-down, stand-up and lie-down take 0.3 s each; wake-up takes 0.5 s. Explicit WorldInput.wake exits
sleep through the bounded waking phase. Observe is an ambient look-around, without new cursor
sampling/reaction before M10. Surface loss interrupts every rest state through the shared falling
handler; invalid bodies use the existing recovery path and clear interrupted activity bookkeeping.

Every rest/expression phase has a semantic clip request and fixed logical deadline. The current
cat pack aliases sit-down/sit/stand-up/lie-down/sleep/wake-up/stretch/observe (plus look-around compatibility) to existing idle.
Missing semantic artwork is held at its resolved fallback frame: no walking-in-place, animation-
finished deadlock or claim of new rest art. Dedicated rest art is optional for this delivery.
The complete state/clip/motion/priority catalogue lives in [state-machines.md](../specifications/state-machines.md).

## Live settings boundary

PetSettings is a Sendable value: scale 0.5–1.5, speed 0.5–2 and AutonomySettings toggles. Core
WorldInput handles configureBehavior, setDisplayScale, setSpeedScale and wake between steps.
Resizing updates contact geometry and visual bounds together, preserves finite foot/facing and
revalidates preparation; airborne physical motion is not teleported by settings. World defaults
to autonomy disabled for explicit-command clients. Production Runtime restores enabled defaults
from preferences before spawning. No view mutates a Pet or writes its position.

## Verification and limits

AutonomyTests cover finite/clamped data, deterministic/overflow-safe choice, repeat filtering,
bounded fallback, tired sleep/wake, every unsupported rest phase falling, no-time/no-randomness
advance when not stepped, cooldowns, live toggles during flight, no-progress recovery and resizing.
Existing M7/M8 tests remain intact. Exact body/state/energy replay is checked with missing and
variable idle/jump/fall/landing art; missing rest completion and authored two-FPS sleep have
separate cases. This does not claim every possible future resting-art permutation was tested.
Runtime low-FPS accounting is unit-tested. Settings interactions pass the UI test; actual OS login
behavior, native sleep cadence and installed-app playtest evidence belong to M9 verification, not to
the Core test result alone.
