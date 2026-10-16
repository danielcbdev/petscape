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
| R-08 | Future art volume exceeds memory budget | M | M | Downsampling, lazy loading, target-size authoring | M14 |
| R-09 | Accessibility API limitations (no AX→CGWindowID mapping, coalesced notifications, hung apps) | H | M | Spike T12.1; PID+frame correlation; timeouts; degraded mode | M12 |
| R-10 | Window-level/Spaces behavior changes across macOS versions (14 → 27) | M | M | Manual matrix on a macOS 14 VM and current OS per release | M14 |
| R-11 | Toolchain drift: Xcode 27 features not available on CI runners | M | L | Swift 6.2 compatibility rule (ADR-0001) | M2 |
| R-12 | No Developer ID → Gatekeeper friction; Accessibility grants reset between differently signed builds | M | M | Ad-hoc pre-releases with instructions; stable dev signing | M15 |
| R-13 | Scope creep (multi-pet, interactions) before the core feels good | M | M | Milestone gates; FR-40+ unscheduled | All |
| R-14 | AI-generated art licensing/provenance unclear for an open-source release | M | M | Owner decision D-08 before public release | M15 |
| R-15 | Agents produce inconsistent changes across sessions | M | M | AGENTS.md process, task IDs, PR template, docs as source of truth | All |

## Open decisions (owner)

| ID | Decision | Recommendation | Needed by |
|---|---|---|---|
| D-01 | Source code license | **Decided 2026-10-16: MIT** (`LICENSE`). Art license still open (D-08) | — |
| D-02 | Documentation and code language | **Decided 2026-10-16: English**; conversation may stay in Portuguese | — |
| D-03 | Final bundle identifier | Keep `io.github.danielcbdev.petscape` unless you own a domain | Before M15 |
| D-04 | Minimum macOS | 14.0 (ADR-0001) | Now |
| D-05 | Approve PoC (M1) as the next step | **Decided 2026-10-16: approved** (T1.1–T1.3 started) | — |
| D-06 | Enable GitHub Actions CI in M2 | Yes for build + package tests (free for public repos) | M2 |
| D-07 | Apple Developer Program enrollment | Needed for notarized releases | Before M15 |
| D-08 | Art provenance/license for AI-generated sprites | Document source tool and terms; choose an asset license (e.g. CC BY 4.0) if allowed | Before public release |
| D-09 | Default pet size (96 pt canvas ≈ 75–80 pt visible cat) | Confirm after PoC E3 visual check | M1 |
| D-10 | Behavior over fullscreen apps (post-MVP) | Keep hidden over fullscreen apps | M14 |
| D-11 | Window interaction degraded mode without Accessibility (CGWindowList only) | Decide after T12.1 spike | M12 |
| D-12 | Intel support | Best-effort; drop if unverifiable by M15 | M15 |
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
