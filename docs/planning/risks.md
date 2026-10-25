# Risks, Open Decisions and Questions to Validate

## Risk register

Probability/Impact: L/M/H.

| ID | Risk | P | I | Mitigation | Where |
|---|---|---|---|---|---|
| R-01 | Dynamic click-through (toggling `ignoresMouseEvents`) is laggy or loses events | M | H | PoC E2; fallback to per-pet windows | M1, ADR-0003 |
| R-02 | Dock shelf position cannot be estimated precisely with public APIs | **L** (PoC E3: constant +1.0 pt) | M | Offset preference; AX enhancement later; walk full width | M1 E3, ADR-0009 |
| R-03 | Screen-parameter notifications do not fire for Dock changes | **Retired** (PoC E3: all changes notified) | M | Only the auto-hide *reveal* is silent → overlay below Dock level (ADR-0003) | M1 E3 |
| R-04 | Rendering costs too much energy/memory | **Mitigated** | H | Materialized with SpriteKit (PoC E7: ~115 MB, 5.7% CPU walking); renderer switched to Core Animation (~19 MB, 1.0%) | ADR-0015 |
| R-05 | Overlay above Dock level interferes with Dock or system UI | L | H | PoC E8; lower level option | M1 |
| R-06 | Prototype art quality (translucent body F6, fringe F7, no idle/turn clips) limits the experience | H | M | Hit threshold 128; request re-export; fallbacks; art roadmap | M4+ |
| R-07 | Foot sliding / unnatural walk speed | M | M | Measure stride, `nominalSpeed`, playback rate coupling | T5.3 |
| R-08 | Active packs' combined decoded assets exceed memory budget | M | M | Downsampling, lazy loading, target-size authoring, profile simultaneous pets | M14, M20 |
| R-09 | Accessibility API limitations (no AX→CGWindowID mapping, coalesced notifications, hung apps) | H | M | PID+frame correlation and timeouts; Accessibility-required policy (D-11); native event/timeout validation remains a follow-up for M13 | M12–M13 |
| R-10 | Window-level/Spaces behavior changes across macOS versions (14 → 27) | M | M | Manual matrix on a macOS 14 VM and current OS per release | M14 |
| R-11 | Toolchain drift: Xcode 27 features not available on CI runners | M | L | Swift 6.2 compatibility rule (ADR-0001) | M2 |
| R-12 | No Developer ID → Gatekeeper friction; Accessibility grants reset between differently signed builds | M | M | Ad-hoc pre-releases with instructions; stable dev signing | M21 |
| R-13 | Scope creep (pet-to-pet interactions) before the core feels good | M | M | Keep pet-to-pet interaction in future FR-41; M20 is limited to independent pets and Settings | All |
| R-14 | AI-generated art licensing/provenance unclear for an open-source release | M | M | Owner decision D-08 before public release | M21 |
| R-15 | Agents produce inconsistent changes across sessions | M | M | AGENTS.md process, task IDs, PR template, docs as source of truth | All |
| R-16 | Overlay shows over full-screen apps; the detection rule (no Dock window on screen) is undocumented behavior and could change between macOS versions | M | M | PoC-validated rule (T3.10); re-check per release; opt-in AX fallback (M12) | M3, ADR-0003 |

## Open decisions (owner)

| ID | Decision | Recommendation | Needed by |
|---|---|---|---|
| D-01 | Source code license | **Decided 2026-10-16: MIT** (`LICENSE`). Art license still open (D-08) | — |
| D-02 | Documentation and code language | **Decided 2026-10-16: English**; conversation may stay in Portuguese | — |
| D-03 | Final bundle identifier | Keep `io.github.danielcbdev.petscape` unless you own a domain | Before M21 |
| D-04 | Minimum macOS | 14.0 (ADR-0001) | Now |
| D-05 | Approve PoC (M1) as the next step | **Decided 2026-10-16: approved** (T1.1–T1.3 started) | — |
| D-06 | Enable GitHub Actions CI in M2 | Approved by owner closure instruction 2026-10-18; workflow authored, first remote run follows an authorized push | M2 closed |
| D-07 | Apple Developer Program enrollment | Needed for notarized releases | Before M21 |
| D-08 | Art provenance/license for AI-generated sprites | Document source tool and terms; choose an asset license (e.g. CC BY 4.0) if allowed | Before public release |
| D-09 | Default pet size (96 pt canvas ≈ 75–80 pt visible cat) | Confirm after PoC E3 visual check | M1 |
| D-10 | Behavior over fullscreen apps (post-MVP) | Keep hidden over fullscreen apps | M14 |
| D-11 | Window interaction degraded mode without Accessibility (CGWindowList only) | **Decided 2026-10-22: do not offer; Accessibility is required.** Native field/lag/CPU measurements remain validation work, not open product decision. See [ADR-0022](../decisions/0022-window-tracking-consent-and-sources.md) | — |
| D-12 | Intel support | Best-effort; drop if unverifiable by M21 | M21 |
| D-14 | Renderer: keep SpriteKit or switch to Core Animation | **Decided 2026-10-16: Core Animation** ([ADR-0015](../decisions/0015-core-animation-renderer.md)) | — |
| D-13 | Source of future animations (who produces, which tool, target sizes) | Author at ≥ 288 px tall, opaque bodies, per asset-format.md | M6–M9 |

## Questions that require practical validation

1. Does a transparent overlay in a borderless non-activating panel composite cleanly over the
   desktop and Dock? (E1) — **yes on macOS 27**; macOS 14 still to check.
2. Does toggling `ignoresMouseEvents` from per-frame cursor sampling give reliable, ≤ 1-frame click
   routing? Does a global `.mouseMoved` monitor work without any permission? (E2) — **yes on macOS 27**
   (0.9–9.1 ms; no permission; clicks around the pet reach the apps underneath).
3. How far is the Dock shelf top from `visibleFrame.minY`, and is it constant across Dock sizes?
   Which Dock changes post screen-parameter notifications? (E3)
4. Can the pet be clicked/dragged without activating the app or stealing focus? (E4)
5. Do `.canJoinAllSpaces`/`.stationary` give the expected Spaces, Mission Control, Stage Manager and
   fullscreen behavior? (E6)
6. ~~What do walking/paused cost in CPU and energy?~~ Answered by E7 → Core Animation (ADR-0015).
7. Does the overlay above the Dock level interfere with Dock or system UI? (E8)
8. Can XCUITest reach the menu bar status item reliably? (T2.7)
9. Are CGWindowList bounds available without Screen Recording on the current macOS, and are AX move
   notifications continuous during window drags? (T12.1)
10. Is the cat's walk speed/stride consistent enough for a single `nominalSpeed`? (T5.3)

## M7/M8 planning revision — 2026-10-18 (unvalidated)

The request's directions **D1…D10** are distinct from the historical owner-decision IDs **D-01…**
in this file. Compatibility: [technical review](m7-m8-technical-review.md). Causes, impacts,
probabilities, prevention, concrete tests and recovery are owned by the
[regression matrix](../development/testing.md#m7m8-regression-matrix), not duplicated here.

| ID | Risk | P | I | Mitigation / gate | Where |
|---|---|---|---|---|---|
| R-17 | Literal SpriteKit clause conflicts with accepted renderer/code/import checks | H | H | Block literal clause for review; minimum correction retain Core Animation, no rewrite | ADR-0016 review gate |
| R-18 | New airborne state loses visibility or frame demand (2f7f33f regression) | H | H | Explicit world work demand, state visibility, both side Dock tests | T7.4/6, RG-03/04 |
| R-19 | Landing at wrong x or using analytic jump prediction misses actual target | M | H | Swept x at contact and bounded discrete replay with same stepper | T7.2/T8.1, RG-02 |
| R-20 | Frame event controls launch/contact or fallback prevents phase completion | M | H | Simulation deadlines/velocity/contact, art-count-independent tests | ADR-0017, RG-09/10 |
| R-21 | V4 exceeds MVP image budget or changes character registration | M | M | Proposed 16 MiB approval, measure actual bytes/process footprint, anchor/identity QA | T8.5, RG-11/15 |
| R-22 | Target geometry mutates during preparation/flight/suspension | M | H | Launch revalidation, cancel target not body, existing recovery on host loss | T7.7/T8.3, RG-07/08 |
| R-23 | Physics scope expands into unknown Dock shelf ends / multi-display/window behavior | M | M | Keep full-width heuristic, reject unavailable target; later geometry/M9/M14 request | T7.3/5/T8.3 |
| R-24 | Window snapshots are too sparse for smooth riding or stale geometry can reappear | H | H | Current refresh is ≤2 Hz, so AC-M13-01 cannot be inferred; reject delayed samples, preserve IDs by visible boundary, run physical support-loss path, profile only with owner opt-in | T13.2/3/5/6; ADR-0012 review if frame-cadence AX is proposed |

### Additional owner approval gates

| ID | Decision | Recommendation / proposed resolution | Needed by |
|---|---|---|---|
| D-15 | Approve M7/M8 planning and ADR-0016–0018 | Confirm retaining Core Animation (literal request D4 blocked), stricter dt API, logical box, host floor coexistence/no automatic Dock lift, simulation-timed takeoff/landing, simple weighted M9 preparation | **Approved 2026-10-18** with subsequent continuous M7/M8 engineering authorization; M7/M8 implemented and closed by explicit owner acceptance after reporting all remaining tests complete |
| D-16 | V4 decoded-image budget above MVP 10 MB | Approve provisional ≤16 MiB for V4 only, total footprint≤100 MB unchanged, actual measurements required; current walk-only budget unchanged | **Approved and measured 2026-10-18**: V4 integrated, 10.125 MiB decoded / 32–33 MB full-app footprint; owner accepted M8 closure |
| D-17 | M5/M6 evidence/deviation closeout or named early-M7 exception | Complete ≥20-point AC-14; keep resolution owner acceptance plus missing logs and absent external hardware explicit; decide full-screen exposure, CPU >20% vs PoC, paused Dock-height behavior, D-06 CI | M6 acceptance / runtime M7 adoption gate |

Gravity/jump/phase/logical-volume defaults are provisional design parameters; visual calibration
and performance validation are still required. D-15/D-16 were accepted by the owner on 2026-10-18 after reviewing the planning. D-17 closeout
remains open; continuous M7/M8 engineering was explicitly authorized later, without accepting
M5/M6 evidence or deviations.
No pending M5/M6 evidence has been marked passed. Subsequent owner instruction closed M7/M8
by test confirmation and explicitly deferred M9; see [owner closeout](m7-m8-technical-review.md#owner-m7m8-closeout-2026-10-18).

## M10 planning risks

Status: proposed mitigations, no native M10 results. [Full contracts/tasks and regression gates](m10-implementation.md#acceptance-risk-and-regression-matrix).

| Risk | Likelihood / impact | Mitigation, verification and owner |
|---|---|---|
| M10-R1 Off-mask input swallowed by stale window gate | High / High | Compare full overlay vs bounded input; POC-02/03, zero swallowed actions; T10.0/9. No-go if failure |
| M10-R2 Focus theft despite nonactivation flags | Medium / High | No key/main/activate, foreground typing matrix POC-05; T10.0/9 |
| M10-R3 Lost up, secondary masking primary release, teardown without frames | High / High | Exact primary sample + synchronous pre-teardown cancel, session IDs; T10.6a |
| M10-R4 Two position writers or final move after release | Medium / High | World-only authority, atomic final target+release; T10.3b/4 deterministic tests |
| M10-R5 Sleep cadence/input events add energy cost | Medium / High | Shared frame reads, event-driven route, 10/2 Hz behavior, no timer; paired Instruments CPU/wakeup/WindowServer profile; T10.1/9 |
| M10-R6 Held invisibility, stopped demand, airborne timeout | Medium / High | Audit all enum switches/snapshot/work/passive sleep; >10 s held test; T10.3b |
| M10-R7 Constant curiosity or expired activity on resumption | Medium / Medium | Dwell/hysteresis/3 s cap/cooldown, save remaining duration; T10.2/5 |
| M10-R8 Display/Dock/Space invalidates target midgesture | Medium / High | Cancel before panel/geometry changes, single-host clamp, existing recovery; T10.4/6a plus native matrix |
| M10-R9 V5 absent/invalid changes trajectory or memory | Medium / Medium | Held fallback, art-independent replay and ≤16 MiB reference budget; T10.7/8 |
| M10-R10 New toggles/migration/accessibility leave live capture | Medium / High | v3 preserve/restore tests, live cancellation, VoiceOver/Reduce Motion; T10.6b |
| M10-R11 Native mouse monitoring refused or privilege behavior differs | Low / High | Fail direct acquisition closed, no privilege escalation, awareness fallback; POC + T10.1 |
| M10-R12 Baseline warnings or missing hardware confused with clean gates | Medium / Medium | Record current UI actor warnings, distinguish package/native results, explicitly accept named hardware gaps; T10.9 |

No new permissions, event injection, Dock-level elevation or silent requirement weakening may
be used to hide these failures. M9 evidence gaps remain accepted historical limits, not M10 work.

## M19 planning risks

Status: implementation and automated evidence recorded 2026-10-24; M19 was closed by explicit owner
acceptance with the real external pack and manual review evidence limits accepted and retained.

| ID | Risk | P | I | Mitigation / gate |
|---|---|---|---|---|
| R-25 | A selected pack contains traversal paths, links, aliases, special files, deceptive image data or oversized resources | M | H | Restrict to a user-selected folder; snapshot referenced resources without following links; reuse schema-v1 validation; enforce path, file, image and decoded-byte limits; promote only a fully revalidated staged copy |
| R-26 | Interrupted/concurrent import leaves a partial destination or overwrites an installed pack | L | H | Same-volume private staging, cleanup on every error/cancellation, exclusive atomic promotion and no update/overwrite policy |
| R-27 | Installed ID collision shadows bundled content or makes ID-only preferences ambiguous | M | H | Keep origin as catalog metadata; reject bundled/installed and installed/installed collisions; retain ID-only preference only while combined catalog IDs are unique |
| R-28 | Lazy image reads fail after an installed pack is changed or removed externally | M | M | Revalidate on discovery, keep current runtime selection on failed swap, omit corrupt pack without blocking launch, and document restart-based rediscovery/removal |
| R-29 | Synthetic fixtures pass while no real external pack has been installed and visually reviewed | M | M | M19 closed by owner acceptance with this evidence gap retained as unverified; do not claim a real-pack pass or reinterpret M18's bundled-content criterion |

M19 has no unresolved product choice: the selected-folder flow, no archives, duplicate rejection,
no overwrite/update, no in-app removal, restart-based external refresh and resource bounds are
specified in the M19 task plan. No ADR is proposed because module boundaries and the existing
manifest/runtime contract are preserved.
