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
frame. The stable candidate order is Walk, Idle, Jump, Sit, Sleep, Stretch, Observe, Explore,
WindowExcursion.
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
| Idle | 0.1 | 2–5 s | 0 |
| Jump | 1.2 × (0.5 + playfulness) | M8 physical phases | 8 s |
| Sit | 0.1 × (0.5 + laziness) | 2–4.4 s, plus 0.6 s transitions | 0 |
| Sleep | 0 above energy 0.25; otherwise 0.2 × (0.5 + laziness) | 2–4.2 s, plus 0.8 s transitions | 20 s |
| Stretch | 0.15 × (0.5 + playfulness) | 1.5 s | 20 s |
| Observe | 0.15 × (0.5 + curiosity) | 3–5 s | 0 |
| Explore | 1.0 × (0.5 + curiosity) | 6–10 s | 0 |
| Window excursion | 1.5 × (0.5 + curiosity), only from Dock with an eligible visible window side | jump to lower side, climb, 7–19 s top walk, Dock return | 20 s |

At energy≤0.08 with rest enabled and the sleep cooldown expired, the next eligible decision forces Sleep. Activity weights are
ordinary injectable BehaviorTuning data for deterministic scenarios; production uses the table.
The seed-42 tired/lazy scenario enters sleep within two decisions. Separate M8 explicit-jump
launch cooldowns remain intact. Toggling autonomy off during automatic flight records the eight-
second cooldown at cancellation, preserving position/velocity/physical phase until contact.

## Execution and interruption

Walk/Explore use existing supported walking, including edge turning; Explore is a short supported
walk, not a new window/surface service. Automatic Jump submits a validated M8 vertical request;
WindowExcursion is a separate weighted activity available only while opted-in window surfaces
include a visible reachable side. It chooses an eligible window with the injected random source,
approaches along Dock when needed, attaches near the lower third of the exposed side using the bounded M13 solver,
reuses M11 climbing, walks on the top for 7–19 simulated seconds and walks to a launch point before
jumping back to Dock. Explicit commands retain their target types. Unreachable/rejected requests produce a two-second
Idle, never another choice in the same call. A walk with no progress for two simulated seconds also
ends in bounded Idle.

The 2026-10-25 owner-requested pacing refinement raises the seeded choice weights for Jump, Explore
and WindowExcursion, reduces the window-excursion cooldown from 30 to 20 simulated seconds, and
increases the top-walk interval. Window jumps target 30% of the available contact span above its lower
contact bound (with at least 48 pt of ascent when feasible), leaving more of the side to climb. This
uses existing states, clips and manifest fallbacks; it adds no art, animation state, or permission.

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

PetSettings is a Sendable value: scale 0.5–1.5, speed 0.5–4 (default 2 for unset preferences) and AutonomySettings toggles. Core
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

## Owner pacing refinement — 2026-10-23

The owner accepted the improved animation fluency and requested less standing still and faster
configurable walking. Autonomous supported rest/expression/turn states now share a five-second
stationary budget across state changes, including fallback idle and cursor/click reactions. Reaching
the budget starts a guaranteed eight-second walk before another ordinary activity choice. Held pets,
explicit interaction sessions, disabled autonomy, pause/hide/suspension and physical flight/climb
phases are exempt. Sleep still restores energy and respects its 20-second cooldown, including the
critical-energy override; shortened sleep/sit durations reserve time for their entry/exit phases.
Rest/expression weights are reduced as shown above. After automatic jumps and Dock-return landings,
the cat gets an eight-second walk instead of immediately drawing another rest action. Explicit jump
return intents remain honored.

The single shared Speed range is 0.5–4, default 2 for missing/nonfinite values. Existing finite stored
values remain intact; preference keys and schema version are unchanged. The V8 stride remains
13.5 pt at 96 pt: displacement and clip rate scale together, so default speed is 27 pt/s and maximum
54 pt/s (previous maximum 27 pt/s). No PNG or manifest is modified by this refinement.

## M16 explicit activities

Music edges arrive as Sendable WorldInput values from the opt-in Platform service via Runtime.
`MusicSessionDetector` applies confidence/time hysteresis outside the simulation frame pipeline.
PetWorld consumes each start once even if ineligible; only a confirmed stop then start permits the
next automatic dance. Manual requests have no audio dependency. Inclusive 5–30 s random deadlines
reuse the injected RandomSource; dance and finite post-Dock-fall cleanup extend the existing
GroundedState and held fallback convention. Physical/interaction/run-state precedence and flight
provenance are specified in [state machines](../specifications/state-machines.md#m16-dance-and-cleanup).
No activity weights, physical integration or M15 closeout are changed.
