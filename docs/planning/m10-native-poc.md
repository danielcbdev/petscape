# M10.0 native interaction PoC

Status: **Experiment record partial/inconclusive; M10 accepted by owner on 2026-10-22 with this
evidence limit retained.** T10.0 ran under explicit owner authorization on 2026-10-18. An isolated
prototype was built and candidates A and B launched. No individual underlying-app observations or
candidate-selection measurements were supplied in the closeout; no routing strategy change is
claimed. Results belong in this document.
[Architecture](../architecture/interaction-system.md),
[ADR-0020](../decisions/0020-selective-input-and-focus.md).

## Question and boundaries

Can a public-API, nonactivating overlay deliver cat-only primary down/drag/up while leaving
transparent regions and Dock/other-app input intact under rapid motion and geometry changes?
Historic M1/M3 tests support the existing approach but do not establish this larger contract.

PoC: isolated native Swift/AppKit executable in `/tmp/PetScapeM10PoC`, outside production
sources, macOS 14+, MainActor, existing panel flags/level, one existing loaded cat frame/mask or
simple shape with deliberate transparent holes. Never modify source assets, production targets,
Swift tests or dependencies. Build with Swift 6 and warnings as errors. Do not add a second physics
simulation: the PoC moves its test representation directly; production still uses PetWorld.
No AX, CGEventTap, keyboard monitors, screen capture, event synthesis or Apple Events.
The owner performs underlying-app clicks; do not inject them into other applications.

## Experiment sequence

1. Record OS/toolchain/hardware/display origins/backing scale, Dock position/autohide/magnification,
   app activation state, focus, exact inspected commit and candidate configuration.
2. A: reproduce current full-screen panel + coarse alpha gate + capture-until-up, event-driven
   pointer updates and existing frame updates. Test stationary/moving cat and deliberate holes.
3. B: keep render overlay permanently ignoring mouse; bounded nonactivating input panel exactly
   follows canvas, uses same mask gate and same level. No input-window expansion during sequence.
4. Compare with C (resizing existing render panel) **only if** A and B fail for a diagnosed reason;
   update proposal before expanding scope. Never “fix” by placing above Dock or replaying clicks.
5. Route valid primary down into responder, verify continuation outside panel/screen edge under
   event-driven three-method handling, recover missing up through primary-button frame sampling.
6. Run matrix below for A/B. Record actual events received by test view and owner-observed action
   in underlying app. “No cat action” alone cannot prove click-through.
7. Measure event→gate and event→presented-target latency with aggregate timestamps/signposts;
   never persist cursor trails, foreign-window titles, text contents or screenshots of other apps.
8. Publish results, selected candidate, failure modes and decision to go/no-go. Owner reviews
   ADR-0020/topology before production adoption. Do not proceed automatically after partial passes.

## Native matrix and objective criteria

All rows were **not run** at planning time. Use built-in display and external display when available;
record unavailable hardware as an unverified row requiring explicit acceptance, never a pass.

| ID | Trials / observable success |
|---|---|
| POC-01 Mask and capture | At each scale 0.5/1/1.5 and both facings, 20 valid body primary down/up sequences each: exactly one target, no unintended app activation. Include idle/walk/fall/landing silhouettes |
| POC-02 Transparent targets | ≥20 distinct off-mask points (corners, alpha holes, tail gaps, margins, 1/5/20 pt outside); click, secondary-click, scroll and externally started drag at each. Underlying Finder/editor target receives intended action; zero swallowed actions or cat sessions |
| POC-03 Routing races | 100 rapid enter/leave/click sweeps per candidate, including click within one frame of boundary, moving cat under stationary pointer, queued rapid events and 4 Hz sleeping cat. Zero off-mask swallowed actions. Record failures individually; mean latency cannot hide one lost click |
| POC-04 Dock | Bottom/left/right × auto-hide off/on; magnification on. Open at least 3 icons, invoke a context menu, scroll where supported, drag an icon normally, reveal hidden Dock. No cat interception or Dock obstruction, including overlap |
| POC-05 Focus and typing | Foreground native editor then another app, 50 cat click/drag cycles total; editor retains keyboard focus/key window and receives subsequent manually typed text. PetScape inactive throughout except explicit Settings/menu activation; overlay never key/main |
| POC-06 Capture outside bounds | 50 drags out of canvas and host edges, stationary held button, return and up. Same responder/session receives sequence or safe recovery; no screen-wide input panel; no stuck capture |
| POC-07 Lost up | Suppress forwarding of test view's up in PoC only, 20 cycles; primary-button sample clears capture by next delivered frame (target≤50 ms at measured 60 Hz). Release secondary while primary held must not end session |
| POC-08 Lifecycle | 10 each: Pause/Hide toggle, Space change, full screen entry/exit, lock/unlock, display sleep/wake, panel removal. Cancel before teardown, no retained capture/monitor, no unprompted resume movement/catch-up |
| POC-09 Geometry | 10 Dock resizes/moves, display arrangement/resolution changes and external unplug when available. Invalidate targeting before replacing panel; latest transform, bounded target, no orphan input window |
| POC-10 Energy and motion | Compare A/B Release 30 s warmup + ≥60 s still/walk/drag windows; record CPU + WindowServer CPU delta, footprint and allocation profile. Bounds and performance gates from M10 plan; Reduce Motion and VoiceOver Settings/menu remain usable |

Latency target: sample→gate p95≤2 ms and maximum≤one measured callback interval; native event→visible
held response p95≤33.4 ms, max≤50 ms on 60 Hz under ordinary load. Record event interval separately
from processing time: asynchronous global delivery cannot establish cursor-crossing latency.
High-load failures need explicit investigation, not deletion from result sets.

Go: zero observed focus/transparent/Dock/capture failures in applicable rows and bounded resource
cost; reviewed data supports the selected candidate. These finite trials are evidence, not proof
of every possible macOS timing. No-go: any swallowed off-mask click, focus theft, extra permission,
stuck capture or unbounded panel. Stop direct-interaction implementation, diagnose and revise ADR;
awareness-only engineering may be separately approved. Missing hardware cannot be silently waived.

## Results record

The partial launch/configuration result follows. No POC-01…10 interaction trials have completed.
For each future POC ID record candidate A/B, trials, pass/fail/unverified, aggregate latencies,
underlying-target observation, logs/tool paths, machine/OS and specific limitation.
### Partial run record — 2026-10-18

| Field | Observation |
|---|---|
| Repository state | `develop`, HEAD `9ecc8a0abe70f6a295ea242fa0479aae3c4ebb32` |
| Host | macOS 27.0.1 (26A434), Xcode 27.1 (27A9275), arm64 MacBook Air |
| Display | Built-in 1470×956 points, origin (0,0); external display not tested |
| Dock / Space | Not recorded; no Dock or Space interaction performed |
| Build | Swift 6 `swiftc -warnings-as-errors` succeeded for the isolated prototype |
| Candidate A | Full-screen render panel `{{0,0},{1470,956}}`, `ignoresMouseEvents=false`, no separate input panel; launched |
| Candidate B | Full-screen render panel `ignoresMouseEvents=true` and a 220×220 nonactivating panel at `{{650,423},{220,220}}`; launched |
| Input, focus, latency, cost | **Not verified**. No click was sent to another app and no timing/resource trial was run |
| Decision | **Inconclusive; neither A nor B is adopted.** Actual underlying target actions and focus behavior remain owner-observed gates before production capture changes |

The prototype source and binary are outside the repository. Opening both windows verifies their
configuration only; panel flags, masks, transparency and absence of cat-side events do not prove
click-through. POC-01…10 remain unrun unless listed above.
