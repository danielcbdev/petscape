# Animation Assets V5 — interaction briefs

Status: **Three V5 interaction clips generated and integrated; owner visual review pending.**
2026-10-22. This supersedes the earlier rejected-generation history below. The delivered pack is
documented in [cat V5 production record](../../assets/characters/cat/v5/README.md); rejected previews
remain in [docs/assets/v5](../assets/v5/) as historical evidence. Integration preserves V4 sources,
schema v1, display size and anchor.
[Interaction states](interaction.md), [schema](animation-schema.md),
[asset rules](asset-format.md), [tasks T10.7/T10.8](../planning/m10-implementation.md).

## Minimum delivery and naming

Produce only three optional clips for initial M10: **curious**, **picked-up**, **held**.
Use hyphen identifiers because schema v1 rejects underscores. Requested `picked_up` maps to
`picked-up` in future manifest, with no rename of an existing source. Dedicated look_up,
look_left_right, released and petting are deferred: curious covers looking/click feedback;
existing fall/landing cover release. Petting would imply a continuous stroking gesture not planned.
Do not add startled/run/chase art to this milestone.

Blue-grey fur, light chest/muzzle, amber eyes, pink inner ears, rounded body, expressive tail,
Cartoon 2.5D and soft top-left key light must match the accepted V4 cat. Native display remains
96×96 pt at scale 1, source canvas 512×512 px. All new frames keep virtual foot reference
**anchor (0.5,0.074)**, even when paws are lifted. This is a virtual body reference in held poses,
not an assertion that paws touch a surface. Changing anchor to the hand/cursor would jump the
sprite; grab offset handles pickup. Physics contact geometry stays pose-independent.

| Field | curious | picked-up | held |
|---|---|---|---|
| Purpose / state | Head turn, attention; cursor reaction and click | Brief lift response on entry to Core held | Calm dangling/breathing while held |
| Initial pose | Current approved idle silhouette, all planted paws aligned | Neutral upright cat with same virtual foot origin | Final picked-up pose |
| Final pose | Neutral attentive pose; loop joins beginning | Relaxed lifted pose, paws tucked/lowered naturally | Matches initial for seamless loop |
| Primary motion | Eyes/head tilt up and toward current facing | Body extends subtly, forepaws draw in | Low-amplitude breathing and paws |
| Secondary motion | One blink, delayed tail tip | Ear/tail lag, no canvas translation | Sparse blink/tail tip; no pendulum physics |
| Recommended frames / FPS | 6 / 6 fps | 4 / 20 fps | 6 / 6 fps |
| Playback | loop (world reaction deadline caps duration) | once, last held if deadline not yet reached | loop |
| Orientation | Right by default, mirrorable left | Same | Same |
| Anchor / foot contact | (0.5,0.074), planted baseline drift≤1 px | Same virtual anchor, no physical support | Same virtual anchor, no physical support |
| Bounding box | All body/ears/tail inside canvas, ≥8 px alpha-zero border | Same through full extension; do not stretch by layer transforms | Same; breathing cannot clip paws/tail |
| Optional events | blink | none required | blink |
| Entry / exit | Enter at reaction; physical motion cancels immediately; deadline→saved activity | Enter once at hold acceptance, presentation phase 0.2 s→held | After 0.2 s; release→existing fall immediately |
| Missing-art fallback | Held resolved idle frame (then default frame) | Held idle frame; same 0.2 s logical phase | Held idle frame |
| Quality focus | Attention readable at 48/96/144 pt without exaggerated movement | No foot-reference/canvas jump on cut from idle or airborne | No implied mouse-velocity force, no severe alpha-mask silhouette flicker |

These are proposed art timing recommendations. Final actual counts/FPS/events go into
`character.json`, never hard-coded in animation playback. The simulation's 0.2 s pickup phase is
an interaction deadline independent of art length, just as preparation/landing already are. If art
finishes earlier hold its last frame; if longer interrupt it. Release is immediate even during
picked-up. No `next` transition may control hold authority, gravity or contact. Fallback never
plays walk-in-place. Render/mask must use the same final frame/anchor in either facing.

## Existing schema capability audit

Schema **1** supports optional clips through fallbacks, ≥1 variable frames, per-clip fps in (0,60],
per-frame duration, loop/once/pingPong, optional events, per-clip facing/variants/anchor and sheets.
Current manifest actually includes walk/idle/jump-start/jump/fall/landing (32 unique PNG frames).
No new schema field, version or migration is needed. Add fallback aliases for curious/picked-up/held
only during later engineering, and later replace missing clips with delivered art. Invalid optional
clip uses existing loader fallback; invalid default uses existing placeholder/error status.
No new manifest attributes such as hand anchor, pose physics or eye tracking are justified.

The existing schema text's old takeoff→velocity claim is historical and superseded by ADR-0017;
V5 events are likewise presentation observations, never input or force commands.

## Future production and integration pipeline

### Rejected candidates — 2026-10-18

- [Curious six-pose sheet](../assets/v5/curious-candidate-opaque-rejected.png): 1536×1024 RGBA;
  alpha range 0–254 with 293,608 partially transparent pixels and 715,642 pixels at alpha ≥128.
  Studio background is present throughout; it fails the alpha-zero requirement and was not split
  into runtime frames.
- [Single-frame base candidate](../assets/v5/curious-base-candidate-not-clip.png): 1254×1254 RGBA;
  alpha bounding box reaches x=0 and y=1254, so the full border fails. It is not a 512×512 clip.
- Original V4 source hashes recorded before and after generation matched; no V4 frame, manifest,
  atlas, GIF or README was changed. Neither candidate is called production V5 art or visual approval.

- [V4-referenced curious edit](../assets/v5/curious-v4-referenced-candidate-rejected.png): generated
  from `assets/characters/cat/idle/frames/idle_01.png` with a request to preserve the standing pose
  and change only the gaze/ear. It changed head/body proportions and its alpha bounds touch x=0;
  reject for identity/silhouette and border requirements.
- [V4-referenced pickup pose](../assets/v5/picked-up-v4-referenced-candidate-rejected.png): generated
  from the same V4 source with a request for gently lifted paws and otherwise matching proportions.
  The pose is usable as a concept reference, but its head proportions differ and alpha reaches x=0
  and y=1254. Reject it from runtime; no clip was exported or integrated. SHA-256:
  `7f517663c46b55a9aa620a7d7e7db76ba7887ec3bdc7db05b8fddcfeef48d15a` (curious),
  `4d17423165a0249a3c16a5151561a10d5e587cb57a2414d8b0e021524d514569` (pickup).

- [Six-frame curious strip](../assets/v5/curious-six-frame-strip-overlap-rejected.png): a transparent
  2172×724 output with six side-by-side poses, but the inferred 362×724 cells have alpha touching
  their left/right edges and frames overlap across cell boundaries. Reject; do not split or scale
  into runtime frames. SHA-256: `2c5b67793a992a11a8e8ab163ba9d7e09e1f2ea367460f4b911c00857ff9be70`.
- A later 1536×1024 six-pose sheet had a consistent 3×2 composition and readable curiosity poses,
  but its studio background remained opaque after a transparency-edit attempt. It is not included
  in `assets/` or counted as production art. Archived as
  [curious six-pose opaque sheet](../assets/v5/curious-six-pose-opaque-sheet-rejected.png),
  SHA-256 `97e71735ab42ec823a171a727e1937c864546730daaf3cb48461d95089e459b8`.
- A V4-referenced pickup pose was reframed to 1254×1254 with alpha bounds `(33,69)-(1176,1165)`;
  it is a single concept frame, not the required animated clip. Preview:
  [picked-up single-frame concept](../assets/v5/picked-up-single-frame-concept-not-clip.png),
  SHA-256 `5a32ad1029f73b3345f2effa97f77034dccfde89ff90233b46c355e75c88a7ee`.
- A four-pose 2×2 pickup sheet retained true alpha and similar poses, but frame-level alpha crossed
  cell boundaries after repeated registration attempts. It cannot be sliced without clipping or
  changing registration, so it remains rejected:
  [picked-up four-frame sheet](../assets/v5/picked-up-four-frame-sheet-registration-rejected.png),
  SHA-256 `c0ef7b189771d2f5ee71447faef9b89ba9d1c86d01cc229ea8df36c13d8abd39`.
- Another reframed single pose did not pass frame margin checks and was archived at
  [picked-up margin-rejected concept](../assets/v5/picked-up-v4-referenced-margin-rejected.png),
  SHA-256 `80fdc3c7aa852ad6d075f74d92ad716cf87ead59b1e672a8c516f3df2aa9f4bf`.
- A new six-frame curious grid was generated on 2026-10-22 at the requested 3×2, 1536×1024
  dimensions. The poses are legible, but the background is opaque and the alpha bounding box spans
  `(0,0)-(1522,1024)` (alpha extrema 0–254), so the transparent-cell-border contract fails. It is
  archived as [rejected grid](../assets/v5/curious-six-frame-grid-transparent-background-rejected.png),
  SHA-256 `29b465131ccd3b233140706947f9174663cbdea9effb24d048b9e3b5dc9d228b`. No frame was split or
  integrated.

1. **Production authorization received** (T10.7). Inspect approved V4 source references, then add new
   versioned sources/provenance under a new V5 location. Preserve every original frame/atlas/GIF/
   README/manifest; never re-export V4 in place.
2. Produce candidate RGBA sRGB frames; validate true alpha-zero background and ≥8 px full border,
   alpha255 body except silhouette antialiasing. Reject detached visible specks/halos.
3. Validate 512 px dimensions, consistent canvas, virtual anchor and planted-contact drift≤1 px;
   held clips validate virtual registration rather than nonexistent ground contact.
4. Review all frames on checker/light/dark at 48/96/144 pt, both facings, and cuts from existing
   idle/jump/fall. Owner approves identity and readable, restrained motion.
5. Optional new V5 atlas/contact sheet and GIF are review artifacts only; do not create an atlas
   if individual frames meet runtime needs. Existing loader already consumes PNG frames; atlas
   generation is not a prerequisite or an optimization claim.
6. T10.8 references approved new paths in character.json with unchanged schema/display size/anchor.
   Additive fallbacks remain for absent/invalid optional files. Do not replace V4 clip definitions.
7. Run the loader/manifest/real-mask audits, V5 assertions in `V4CharacterPackTests` and the
   connected-silhouette audit in `CatArtAuditTests`, then use DEBUG Animation preview and verify
   native pickup/release with grounded and airborne starts.
8. Compare identical seeded command streams using no V5, delivered V5, invalid optional V5 and
   1/8/12/24/32-frame synthetic clips. Body position, velocity, contact, phase timers and resulting
   autonomous return must match exactly.
9. Measure decoded frame bytes and process footprint. Proposed **≤16 MiB total decoded pack**:
   32 old +16 new frames at 288²×4 = 15,925,248 bytes (15.1875 MiB), plus separately measured masks
   and cache overhead. At higher backing scale report actual bytes and downsample consistently
   under existing policy; do not pretend this estimate covers every future display.
10. Record provenance, frame-level QA, byte totals, previews, original-file hash preservation and
    owner approval in the new V5 production record; synchronize task/acceptance evidence.

### Production update — 2026-10-22

Delivered `curious` (6 frames / 6 fps / loop), `picked-up` (4 / 20 fps / once) and `held`
(6 / 6 fps / loop) under `assets/characters/cat/v5/`. Each generated pose was normalized to a
512×512 RGBA canvas with transparent margin and solid-alpha virtual foot row 474. Runtime clip
metadata was added to the existing schema-v1 manifest. Loader, timing, frame-count, memory-budget,
border and registration audits are covered by the V5 pack tests. See the
[production record](../../assets/characters/cat/v5/README.md).

This is engineering integration, not owner visual approval. Color-fringe antialiasing remains
faintly visible around some source-scale edges; it is reduced when rendered at the app's 96 pt
display size. Final owner review should use the DEBUG Animation preview before visually approving
the pack. Earlier text in this brief records the state before the 2026-10-22 production update.
