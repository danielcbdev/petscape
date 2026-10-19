# M5/M6 Evidence and Closeout Plan

Date: 2026-10-18. **M2/M3/M5/M6 Done by owner acceptance.** Historical procedures and evidence limits are retained.
Source of recorded results: [milestones.md](milestones.md#m6--dock-integration--mvp-hardening),
[testing.md](../development/testing.md), [performance.md](../specifications/performance.md).
M4 is Done; M6 implementation is merged at HEAD 2f7f33f. v0.1.0 is not tagged/released by this work.

## Owner closure update (2026-10-18)

The owner explicitly instructed closing M2, M3, M5 and M6, reporting that everything works
perfectly, and reauthorized M9 implementation through completion. All four milestones are
**Done by owner acceptance**. C-01…C-08 below are retained as the historical check/evidence plan,
not outstanding approval requests. Acceptance includes the documented CPU/full-screen/paused-height
limitations; missing point-by-point logs and unavailable external hardware are not invented passes.
CI D-06/T2.8 is implemented in `.github/workflows/ci.yml` (lint, package tests, Debug build on
push/PR to develop). Equivalent commands run locally; no remote run is claimed before an authorized
push. No commit, push, release or tag is authorized by the closure; v0.1.0 remains untagged.

## Historical work and gates (closed by owner acceptance)

| ID | Owner / dependency | Concrete procedure and evidence | Close condition / risk for M7 |
|---|---|---|---|
| C-01 / T6.10 / AC-14 | Owner-assisted desktop check on current build | Execute point/event matrix below; record date, HEAD/config, OS, display points/backing scale, Dock settings, target app, point, expected recipient/result, overlay key/app-active log. Partial Dock success is preserved but is insufficient | Every required cell passes or owner explicitly accepts named exception. Direct regression risk: new airborne silhouettes/masks must repeat in M7/M8 |
| C-02 / M3 PoC S8 / AC-17 | Owner-assisted resolution/scaling change, no external monitor required for built-in scaling | Preserve 2026-10-18 owner acceptance. Optionally close evidence gap by capturing `Screen parameters changed` and subsequent `Walkway …` lines before/after changing built-in scaling, with correct visible cat/bounds. Restore original setting | No fabricated logs. If not run, owner-accepted behavior + missing diagnostic evidence stays explicit. Direct M7 risk: stale surfaces/host bounds |
| C-03 / T6.6 / AC-17 | External hardware unavailable | Defer connect/disconnect, Dock on secondary, negative placement and mixed-DPI checks to hardware availability/M14; record exact untested combinations. Use deterministic descriptor tests for M7 logic meanwhile | Hardware test not marked Pass/N/A-as-pass. Does not block planning, blocks claiming multi-display validation; physical host migration remains unverified |
| C-04 / R-16 / full-screen exposure | Owner decision | Repeat launch inside full-screen Space and desktop→full-screen transition; record exposure duration/build/OS and detection logs. Evaluate existing ~0.4 s launch exposure against “never cover full screen” product requirement | Explicit accept-for-v0.1.0 with limitation or separate scoped hardening task before release. Do not silently rewrite AC or change detector in M7 |
| C-05 / T2.8 / D-06 | Owner CI decision | Record enable/defer. If enable, authorize T2.8 separately, use existing build/test commands and obtain actual green run; no workflow created now | CI remains pending until approved/run, not a physics architecture blocker; local future checks still required |
| C-06 / T6.8 / AC-19 | Owner accepts/rejects explained CPU deviation | Existing 2.06% walking vs PoC 1.0% (>20%) is within 5% target but needs explicit acceptance; explanation is full sim/cursor/mask pipeline vs simple sprite spike | Accepted explanation or scoped profiling task; do not label already accepted. Direct M7 risk: baseline budget regression |
| C-07 / T6.10 | Owner decision on paused Dock height behavior | Current paused pet remains at old height after Dock hide/show until Resume; record as named deviation or require separate change | Preserve evidence; M7 freezes physical time and reconciles on resume. No automatic Done |
| C-08 / AC-M6-01 | Owner acceptance of all criteria/deviations | Collate C-01…07, prior 2 h soak/leaks/UI/visual results, retain missing Energy Impact/frame-pacing results as unmeasured where applicable; owner decides remaining measurement/waiver needs | Only after explicit sign-off change M5/M6 Status to Done. Release/tag remains a separate explicit instruction |

## AC-14 repeatable point/event matrix

Use **at least 20 distinct transparent points**, both facings and paused + walking snapshots. Before
classifying a point transparent, use current silhouette and DEBUG mask: body alpha threshold plus
mask dilation can make a visually faint margin interactive. Record geometric relative position and
current clip/frame/facing/scale so each point is reproducible. No product code to automate external
clicks, no app permissions added, and no background screenshot collection.

| Point IDs | Where to place points (confirm each is outside current hit mask) |
|---|---|
| P01–P04 | 5 pt outside upper-left, upper-right, lower-left, lower-right sprite silhouette |
| P05–P08 | Above left ear, above right ear, left of muzzle, right of back/torso |
| P09–P12 | Below chin, between forelegs, between fore/rear legs, between rear legs (use closest transparent gap if pose overlaps) |
| P13–P16 | Under tail base, under tail tip, above tail tip, outside curved-tail hollow |
| P17–P20 | Left of front paw, right of rear paw, below forepaw baseline, below hindpaw baseline |

Map translated equivalent pet-relative points over **Finder, desktop icons, Dock, menu bar and app
windows** using current motion/paused position and available desktop targets. If a point cannot
physically align with a target on this build, record the limitation and choose another transparent
point to meet ≥20 unique points, not a fabricated pass. For each point exercise click, double-click,
right-click, drag-through (starting in the underlying app) and scroll wherever meaningful; record
recipient/observable action. Make distribution across target classes and event kinds explicit.
Also click an opaque pet pixel while typing: underlying app stays frontmost and typing continues
(AC-21). Pass-through tests alone do not establish typing/VoiceOver/alpha quality.

Evidence format (fill during actual check): `point ID | clip/frame/facing | relative/global point |
target | event | expected action | actual action | pass/fail | log/evidence reference`. Keep matrix in
the milestone evidence/PR when available; do not create an empty result file now. Preserve prior owner
checks as dated records rather than replacing them with this plan.

## Historical relationship to M7 start

Planning can proceed while C-01…08 remain open. Default implementation predecessor remains M6
acceptance; owner may explicitly authorize T7.1 before closeout with these gaps acknowledged.
T7.1/T7.2 pure helpers do not change overlay behavior. Runtime adoption T7.4–T7.8 directly touches
C-01/C-02/C-06 risk, so require baseline evidence or a named owner exception before that gate.
External hardware/CI gaps must remain listed even if the owner authorizes implementation.
No closeout item authorizes release, new permissions, or committing documentation.
