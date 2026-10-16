# ADR-0012: Concurrency model — MainActor engine, Sendable values

- Status: Proposed
- Date: 2026-10-16
- Related: [conventions.md](../development/conventions.md#swift-concurrency)

## Context

AppKit, Core Animation (display links, layer trees) and AX observer callbacks are main-thread APIs. The simulation is small (≤ 0.3 ms
per step target). Only image decoding is heavy enough to justify background work. Swift 6 mode checks
data races at compile time.

## Problem

Where code runs, and how isolation is expressed so the compiler can verify it.

## Alternatives

1. Simulation on a background actor, rendering on main → cross-actor hops every frame, snapshot
   copying, latency, complexity.
2. **Everything frame-related on the main actor; pure value types for the domain; background only for
   I/O and decoding.**
3. GCD queues with manual locking → unchecked by the compiler.

## Decision

- `PetScapeCore`: nonisolated, value types, `Sendable`. `PetWorld` is a struct mutated by its owner.
- `PetScapePlatform`, `PetScapeRendering`, `PetScapeRuntime`, app target: **default isolation
  `MainActor`**.
- Background work: image decoding and manifest file reading via `nonisolated`/`@concurrent async`
  functions returning `Sendable` results (`CGImage` is treated as immutable and passed via
  `sending`). No `Task.detached` unless justified in code review.
- C callbacks (AX observers, CG callbacks) hop to the main actor with `MainActor.assumeIsolated` only
  when registered on the main run loop; otherwise via `Task { @MainActor in … }`.
- Forbidden without written justification in the code: `@unchecked Sendable`, `nonisolated(unsafe)`,
  `DispatchQueue` for new code, locks.

## Rationale

The frame loop is tiny and must interact with main-thread frameworks every frame; isolating it on the
main actor removes a whole class of races and hops. Background concurrency is reserved for the one
place where it pays off (decoding).

## Consequences

- Long main-thread work is a bug; asset loading must never block the main actor.
- Tests of Core are synchronous and fast.

## Risks

| Risk | Mitigation |
|---|---|
| AX calls block the main thread on hung apps (M12) | Messaging timeout; move AX queries to a dedicated actor if measurements show stalls |
| Main-actor default hides accidental heavy work | Signposts around the tick; hitch measurements |
