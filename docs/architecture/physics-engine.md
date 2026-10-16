# Physics Engine

Decision: [ADR-0005](../decisions/0005-kinematic-physics.md). Loop: [ADR-0013](../decisions/0013-simulation-loop.md).

Goal: **convincing** motion (weight, anticipation, arcs), not physical realism. Pets are characters
in a platformer, not rigid bodies.

## SpriteKit physics evaluated

SpriteKit is no longer used for rendering ([ADR-0015](../decisions/0015-core-animation-renderer.md));
this comparison is kept because it also rules out adopting SpriteKit for physics alone.

| Need | `SKPhysicsBody` | Custom kinematic controller |
|---|---|---|
| Surfaces from external geometry (Dock, windows) that move/disappear every frame | Bodies must be recreated/moved in scene space per overlay; edges across multiple overlays/screens impossible | Surfaces are plain segments in global space |
| Pet crossing between screens (separate overlays/scenes) | Body cannot move between scenes | Pet lives in global space; any overlay renders it |
| Walking *along* a surface, snapping, climbing walls | Fights the solver (friction, bounce, rotation) | Native concept (attachment + parameter) |
| Determinism and unit tests | Variable step tied to rendering; needs a live scene | Fixed step; pure functions |
| Pause/resume semantics | Scene-level | Simulation-level, identical to animation |

Conclusion: use a small custom **kinematic** controller. This is not a general physics engine:
no rigid-body dynamics, rotation, stacking or friction solving.

## Units and constants (initial, tunable)

| Quantity | Unit | Initial value | Notes |
|---|---|---|---|
| Distance | points (global) | — | never pixels |
| Time step | s | 1/60 | fixed |
| Gravity | pt/s² | 2400 | tuned for ~0.35 s fall per 150 pt; "snappy" cartoon feel |
| Terminal fall speed | pt/s | 1800 | clamp |
| Walk speed | pt/s | from clip `nominalSpeed` × rate | keeps feet in sync with art |
| Max steps per frame | — | 5 | avoids the spiral of death after hitches |

Constants live in a `PhysicsTuning` value (per character overridable in the manifest later).

## Motion modes

| Mode | Integration | Exit conditions |
|---|---|---|
| `attached(surface, t)` | Move `t` along the surface segment by `speed × dt / length`; position = surface.point(at: t) | End of segment → `edgeReached`; surface removed → detach |
| `airborne` | Semi-implicit Euler: `v += g·dt; p += v·dt` (clamped) | Swept test vs walkable segments → `landed`; out of bounds → recovery |
| `climbing(surface, t)` (M11) | Like attached, along a vertical segment | Top/bottom reached → transition |
| `dragged` (M10) | Position = cursor + grab offset; velocity estimated from recent cursor samples | Release → `airborne` with that velocity (throw) |

### Landing detection (swept, not overlap)

For each walkable horizontal segment whose x-range contains the pet's x: landing occurs when the
contact point crosses the segment's y from above between `p_prev` and `p_next` (`p_prev.y ≥ y ≥ p_next.y`).
Choose the highest crossed segment. This prevents tunneling at high fall speeds without
continuous collision machinery.

### Moving surfaces (M13)

Attached pets keep `(surfaceID, t)`. When a surface moves, the pet's position is recomputed from
the new segment; its velocity is not altered (the pet "rides" the window). If the surface delta per
step exceeds a threshold (window thrown or teleported), the pet detaches and falls — a reaction
opportunity for behavior.

### Removed surfaces

A removed surface (Dock hidden, window closed/minimized, display disconnected) detaches all pets
on it: MVP → respawn on the fallback surface; M7+ → `airborne` (fall), landing on whatever is below,
ultimately the screen bottom, which always exists.

### Jumps (M8)

`JumpSolver` computes an initial velocity to reach a target point with a chosen apex height
(`v_y = sqrt(2·g·h)`, time to apex, horizontal velocity from total flight time). Behavior chooses
targets; physics executes. Animation events (`takeoff`, `apex`, `land`) align art with motion.

## Fixed timestep, interpolation, determinism

- Simulation uses a fixed `dt`; the frame driver accumulates real elapsed time and runs `n` steps.
- The renderer may interpolate between the last two simulation states (`α = accumulator / dt`).
  Interpolation is **deferred**: at 60 Hz render with 60 Hz simulation it is unnecessary; enable it
  only if 120 Hz (ProMotion) judder is observed (measure in M14).
- Determinism: no wall clock, no `Double.random()`; randomness from an injected `RandomSource`;
  iteration order over pets is stable. Same inputs + seed ⇒ same trajectory (tested).

## Testability

Physics functions are pure (`(state, surfaces, dt) -> (state, events)`). Tests cover: walking
speed and edge events, landing at various speeds (no tunneling), surface removal mid-walk,
moving-surface riding, jump reaching its target within tolerance, NaN guards and recovery.
