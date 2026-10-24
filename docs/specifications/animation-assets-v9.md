# V9 art handoff — M16 dance and cleanup

**Owner acceptance:** on 2026-10-24 the owner confirmed all behavior works and closed M16,
including these integrated clips. Original delivery metrics/deviations below remain unchanged;
no additional pixel, performance or frame-pacing measurement is inferred. See the
[M16 closeout](../planning/m16-implementation.md#owner-m16-closeout--2026-10-24).

**V9 art delivered with the V8 cut-out rig (owner-approved method change) and integrated in the runtime
manifest on 2026-10-23 (T16.8, steps 4–6 below).** The owner chose the rig over hand-drawn frames, so the "original authored drawings"
requirement of the prompts below is replaced by the method in [Delivered V9 art](#delivered-v9-art--2026-10-23).
Packs without these clips keep the semantic missing-clip held-frame fallback. M15/V8 source, manifests, exception and acceptance remain unchanged.

## Delivered V9 art — 2026-10-23

Produced by `scripts/build-m15-rig.swift` (`RIG_CLIPS=dance,cleanup`) from the authored key
`walk/frames/walk_01.png`: rigid part rotation/translation only, eyelids and a cleanup tongue painted
as overlays. Hashes and the build command: [`PROVENANCE.md`](../../assets/characters/cat/v9/PROVENANCE.md).

| Clip | Files | Timing | Playback |
|---|---|---|---|
| `dance` | `v9/dance/frames/dance_01.png` … `dance_30.png` | 30 drawings × 1/30 s = 1.0 s | loop (30 → 01 continuous) |
| `cleanup` | `v9/cleanup/frames/cleanup_01.png` … `cleanup_36.png` | 36 drawings × 5/60 s (12 FPS) = 3.0 s | once, ends near idle |

Counts, names and timing match the proposals. Measured on the delivered files: 512 × 512, 8-bit RGBA,
sRGB profile, right-facing; transparent pixels carry no colour; all 66 drawings distinct and none
equal to an existing pack image; ≥ 8 px margin; a single visible island; the V8 pack test's seam rule
(4 px opaque neighbourhood ⇒ alpha ≥ 235, at most 3 exceptions ≥ 160) passes; lowest solid row 474 in
every drawing (as idle_01, landing_04 and the key); every planted paw keeps its exact contact
(farHind 250, nearHind 162, nearFront 328, farFront 386 at y 472) — no skating.

Interpretation and deviations for owner review:

- The rig keeps the key's side view, so the dance "shoulder/body sway" is a fore–aft rock (lean and
  weight shift forward, then back) with a bob on each beat, the head nodding against it and the tail
  counterbalancing with follow-through. The near hind paw taps on the forward sway and the near fore
  paw on the back sway (14 of 30 drawings each have one paw briefly lifted); supporting paws never move.
- Keys follow the brief's grouping (dance: every 5 drawings; cleanup: every 6, drawing n at n/6) with a
  monotone cubic through them, so motion continues through each key instead of stopping.
- Cleanup: the crouch is a 7–8 px lowering with the weight leaning back; the paw reaches the chin
  beside the mouth; the lick is a small painted tongue with closed eyes; the wipe crosses the cheek to
  below the eye, not all the way to the ear. The near fore leg is lifted 23 of 36 drawings.
- Rig limits visible at full size: the raised arm is a rigid rounded cut-out (no true wrist bend or
  pad view); the chest underside is a drawn arch while the arm is up; a short flat top of the far fore
  leg can show under the chest. The head pitch is limited to 11° to avoid exposing the head cut.
- cleanup_36 is a breath away from the key (mean difference 9.9/px versus idle_01) so it is not a
  duplicate; cleanup_01 differs from landing_04 by 10.8/px. dance_01 differs from idle_01 by 40.4/px
  (about two idle drawings), a possible small pop at entry to check in playback.
- Not verified: playback in the app, 96 pt / 0.5× / 1.5× inspection on wallpapers, CPU/texture memory in
  the running app (checklist steps 7–9).

## Shared measured contracts and proposals

The runtime [cat manifest](../../assets/characters/cat/character.json) declares 512 × 512 px,
96 × 96 pt at scale 1, facing right, anchor (0.5, 0.074) from bottom-left. The ground contact is
x=256, y≈474 from the top (512 × (1−0.074)=474.112). Use the visible paw-baseline of the actual
reference, not a newly centered cat. Compare idle_01 and landing_04 visually; both are read-only
V8 references. Tail/ear silhouette must remain at least 8 px inside every edge. Body fully opaque;
soft alpha is allowed only on silhouette edges. PNG RGBA8, straight alpha, sRGB. No GIF, sheet,
background, caption, shadow plane or altered reference is required.

Frame counts below are **art direction proposals requiring owner confirmation**, not quantities
already present or imposed by the schema. They reuse established pack cadence/counts: dance uses
the walk's 30-frame/30-FPS one-second cycle; cleanup uses the curious clip's 36-pose capacity with
12 FPS (five 60-Hz ticks per pose), yielding a three-second finite action. Six narrative poses
with five or six distinct authored drawings per phase explain these counts. Increase or reduce
only after checking fluency and corresponding manifest timing; never pad with duplicate frames.
Core dance duration (5–30 s) and cleanup bound (3 s) are behavior deadlines, not image constants.
No code needs frame-count/FPS/anchor edits during integration.

## Prompt 1 — dance (ready to copy)

```text
Create a coherent sequence of original animation frames for PetScape's existing cat, using the
attached immutable references: assets/characters/cat/v8/idle/frames/idle_01.png,
assets/characters/cat/v8/walk/frames/walk_01.png through walk_30.png, and
assets/characters/cat/v8/landing/frames/landing_04.png. The owner must attach those files.
Match that exact kitten: plush blue-grey fur, pale cream muzzle/chest/paws, large amber eyes,
pink nose and inner ears, large ears, curled fluffy tail, rounded cute 2.5D cartoon proportions,
soft top-left lighting. No collar, accessories, instruments, notes, particles or extra characters.
Do not redesign or edit any supplied reference image.

Deliver a right-facing, in-place dance on four paws: a cheerful alternating shoulder/body sway,
small head nod and counterbalancing tail wave. There is no physical jump, translation, spin,
foot skating or scale/camera motion. Keep at least one clear support paw planted on each side
of the body; paws that support the weight stay on the same ground line. The body should feel
light and rhythmic while remaining the same cat at the same screen position.

Proposal to confirm with the owner before production: 30 DISTINCT authored PNG frames for a
one-second seamless loop at 30 FPS, matching the current walk cadence. Do not duplicate drawings
to achieve the count, interpolate screenshots or copy/warp the source frames. Narrative order:
01–05 ease from neutral into the first shoulder sway; 06–10 deepen the sway with a gentle head
nod and opposite tail counterbalance; 11–15 recover toward center; 16–20 sway to the other side;
21–25 deepen the second sway, following the same rhythm; 26–30 recover smoothly toward frame 01.
Within each five-frame range, author progress at 0%, 20%, 40%, 60%, and 80% toward the next
key pose; continue at the next key on the following range. This specifies every frame's place
in the action, not a request for automated image interpolation. There must be continuous
position/velocity across 30→01 without a duplicate endpoint. First/last
poses must allow a natural transition from/to the provided idle/landing reference at any loop end.
Do not imply physical displacement; every pose shares the canonical contact point.

Canvas: 512×512 pixels for every file. Use the exact cat scale and framing of the references;
the full canvas displays as 96×96 points at scale 1. Anchor is x=256, approximately y=474 from
the top (normalized 0.5,0.074 from bottom-left). Never auto-center or trim individual frames.
Keep ears, tail and all opaque pixels at least 8 pixels inside the canvas. Transparent pixels
around the character have alpha 0; body interiors have alpha 255; soft edges only at silhouette.
Output individual PNG files, 8-bit RGBA, straight alpha, sRGB, fully transparent background.
No checkerboard baked into pixels, matte halo, text, numbers, border, scenery, ground or floor shadow.

Return only new files under assets/characters/cat/v9/dance/frames/:
dance_01.png, dance_02.png, ... dance_30.png, in that exact narrative order.
Do not overwrite, rename, convert or re-export any existing pack/reference. Supply a separate
text note describing frame count, right-facing orientation, intended 30-FPS loop and any artistic
constraint that required changing this proposal. Do not claim this artwork is already integrated.
```

## Prompt 2 — cleanup (ready to copy)

```text
Create an original finite post-landing grooming sequence for PetScape's existing cat. The owner
must attach immutable references assets/characters/cat/v8/idle/frames/idle_01.png,
assets/characters/cat/v8/landing/frames/landing_01.png through landing_04.png,
and assets/characters/cat/v8/curious/frames/curious_01.png. Match the precise reference identity:
plush blue-grey kitten, cream muzzle/chest/paws, amber eyes, pink nose/inner ears, fluffy curled
tail, rounded 2.5D cartoon proportions and soft upper-left light. No redesign or reference editing.

Action: after a fall has already landed and physically settled, the cat briefly tidies its fur.
It stays in place, lowers into a small supported crouch, raises one front paw, gives that paw
a quick lick, brushes the paw over its cheek/ear, lowers the paw and regains the reference neutral
four-paw stance. No extra fall, rebound, landing impact, jumping, translation, foot sliding or
physics motion belongs in this clip. The pose must visually connect from landing_04 to idle_01.
Keep the supporting paws registered; the raised cleaning paw may leave the ground naturally.

Proposal to confirm with the owner before production: 36 DISTINCT authored frames at 12 FPS
(one frame every five 60-Hz simulation steps), three seconds total, played ONCE, no loop. This
uses the existing curious sequence's 36-frame capacity with a deliberate slower grooming cadence.
Narrative order: 01–06 settle from the neutral reference into the supported grooming crouch;
07–12 lift the near front paw toward the muzzle; 13–18 one small visible lick/inspection of that
paw; 19–24 one continuous gentle wipe across cheek toward the ear; 25–30 lower that paw while
re-centering weight; 31–36 return smoothly to the exact neutral reference stance. Frame 36 is a
clean idle-compatible exit, not another crouch. Within each six-frame phase, draw six successive
steps toward that phase's destination (1/6, 2/6, 3/6, 4/6, 5/6, 6/6); make the next phase continue
from there, with no duplicated key endpoints. These are narrative progress positions, not a request
for automatic interpolation or pixel transformation. Every frame must be a distinct intentional drawing;
do not duplicate, mechanically warp, interpolate or re-export the attached originals.

All files: 512×512 px, same scale/camera/framing as references, full canvas displayed at 96×96 pt
at scale 1. Canonical anchor x=256, y≈474 from top (normalized 0.5,0.074 from bottom-left).
Keep the supporting paw baseline fixed; do not recenter/crop the crouching body. Keep the entire
tail/ears within at least 8 px transparent margins. PNG RGBA8, straight alpha, sRGB, transparent
background alpha 0, body alpha 255, edge softness only at the silhouette. No text, labels,
scenery, ground, shadows on a floor, props, bubbles, particles, accessories or other characters.

Return only new files under assets/characters/cat/v9/cleanup/frames/:
cleanup_01.png, cleanup_02.png, ... cleanup_36.png, in narrative order.
Never alter, overwrite, rename or re-export the original pack or supplied references. Return a
separate text note with the confirmed frame count, finite 12-FPS/3-second timing and any changes
the owner must review. The files are source art awaiting integration, not a completed milestone.
```

## Owner acceptance and integration checklist

1. Confirm the proposed counts/narrative with the art provider; attach the references above.
2. Receive separate PNGs with exact names in the two new V9 paths; preserve all preexisting files.
3. Check dimensions, RGBA8/sRGB/straight alpha, opaque interior, empty background, ≥8 px margin,
   no specks/halos/cropping, distinct poses and no paw/scale registration jumps. Inspect at 96 pt
   and user scales 0.5/1.5 against light/dark wallpapers. Record source/tool/date and SHA-256 hashes
   in new V9 provenance text after delivery. Do not inherit or hide the V8 QA exception.
4. Add actual `dance` (`loop`, proposed fps 30, 30 ordered image paths) and `cleanup` (`once`,
   proposed fps 12, 36 ordered image paths) entries to the runtime `character.json` only after the
   files exist. Retain top-level canvas/displaySize/anchor/defaultFacing. Both bottom alignment,
   mirrorable true, no nominalSpeed, no physical events or `next`; set interruptible true so
   behavior/safety policy remains authoritative. Do not alias another clip as either new action.
5. Existing lazy family mapping loads unknown names as their own family; no family code change
   is needed. Bundling automatically copies only referenced PNGs. Add pack tests for the new clips
   and update the M15 pack-inventory assertion to preserve all ten V8 entries/contracts while
   admitting the two V9 clips; do not weaken the existing pixel QA.
6. Run `make lint`, `make test-core`, app/UI tests, Debug and Release builds. Run all manifest/path,
   decode/alpha/baseline/hash/memory checks, retaining the separate preexisting V8 failure.
7. Native app: Dance 5–30 s, auto confirmed stop, duration expiry/continuous-music nonrepeat,
   manual takeover, transitions from both facings, eligible Dock fall → landing → cleanup → idle/walk,
   grab/support loss during either action. Verify hit masks, bounds, focus and click-through.
8. Measure loaded texture/CPU deltas using the current performance protocol. The proposal adds
   66 × 288 × 288 × 4 = 21,897,216 decoded bytes (~20.88 MiB) when both families load, excluding
   masks/overhead. Existing lazy loading means no initial default-family increase; full-memory
   acceptance must be checked rather than assumed. No new budget is approved by this proposal.
9. Record visual owner acceptance and remaining native results before requesting M16 closure.
   Until then M16 stays In progress / awaiting external art and validation.
