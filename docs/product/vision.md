# Product Vision

## One-liner

PetScape is a native macOS app that turns the desktop into a place where small, expressive,
autonomous pets live: they walk on the Dock, climb screen edges, hop between windows, nap and play,
without ever getting in the way of real work.

## Why

Desktop pets are a well-loved genre, but most implementations are either dated (low-res sprites,
jittery movement), heavy (always-on Electron or high CPU), or invasive (steal focus, block clicks).
PetScape aims to show what the genre looks like when built with native frameworks and serious
engineering: smooth motion, believable behavior, near-zero idle cost, and full respect for the
user's workflow.

PetScape is an **open-source portfolio project**. It is not a commercial product: no payments,
accounts, backend, cloud sync or external telemetry. Everything runs locally.

## Experience principles

1. **Alive, not noisy.** Pets act on their own with believable rhythms (activity, rest, curiosity).
   Long quiet stretches are a feature.
2. **Never in the way.** Clicks pass through everything that is not a pet. Pets never steal focus,
   never cover system alerts on purpose, never manipulate other apps' windows.
3. **Native and refined.** Menu bar presence only, minimal settings that look and behave like macOS.
4. **Cheap to keep running.** It may run all day; idle cost must be close to zero.
5. **Grounded in the real desktop.** Pets stand on things that visually exist (Dock, screen edges,
   window title bars) and react when those things move or disappear.

## Visual identity

- Modern cartoon 2.5D: soft volumes and shadows, expressive faces, natural animation.
- First character: a blue-grey cat with light muzzle and chest, amber eyes, pink ears, expressive
  tail, rounded body. Personality: curious, playful, a bit lazy, expressive.
- Current sprites are **prototypes** and will be replaced with richer animations. The architecture
  treats art as data so that replacement requires no code changes
  (see [asset-format.md](../specifications/asset-format.md)).

## Long-term capabilities (vision, not commitments)

| Area | Examples |
|---|---|
| Movement | walk, run, stop, turn, jump, fall, land, climb, descend |
| Natural behaviors | sit, sleep, wake up, stretch, observe, show curiosity, play, rest |
| macOS interactions | walk on the Dock and screen edges, climb screen sides, walk on window tops, hop between windows, ride moving windows, react to the cursor, be dragged |
| Pet-to-pet | meet, chase, play, sleep together, react to each other |

These are delivered incrementally; see [roadmap.md](roadmap.md) and [scope.md](scope.md).

## Success looks like

- A first-time user launches the app, sees the cat walking along the Dock within a second, and keeps
  working normally without noticing any interference.
- Activity Monitor shows negligible CPU while the cat is resting.
- A new contributor (human or AI agent) can add a new animation by dropping frames and editing one
  JSON file.
