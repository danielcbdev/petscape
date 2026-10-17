# Character Manifest Schema (v1)

File: `character.json` at the root of a character pack. Encoding: UTF-8 JSON. Decoded by
`CharacterManifest` (Codable) and validated by `ManifestValidator` in `PetScapeCore`.
Image rules: [asset-format.md](asset-format.md). Runtime behavior:
[animation-system.md](../architecture/animation-system.md).

## Example (the cat, MVP)

```json
{
  "schemaVersion": 1,
  "id": "cat",
  "displayName": "Cat",
  "defaultAnimation": "walk",
  "defaultFacing": "right",
  "canvas": { "width": 512, "height": 512 },
  "displaySize": { "width": 96, "height": 96 },
  "anchor": { "x": 0.5, "y": 0.074 },
  "fallbacks": {
    "idle": "walk",
    "fall": "walk",
    "land": "walk"
  },
  "animations": {
    "walk": {
      "playback": "loop",
      "fps": 9,
      "nominalSpeed": 20,
      "frames": [
        { "image": "walk/frames/walk_01.png" },
        { "image": "walk/frames/walk_02.png" },
        { "image": "walk/frames/walk_03.png", "events": ["footstep"] },
        { "image": "walk/frames/walk_04.png" },
        { "image": "walk/frames/walk_05.png" },
        { "image": "walk/frames/walk_06.png" },
        { "image": "walk/frames/walk_07.png", "events": ["footstep"] },
        { "image": "walk/frames/walk_08.png" }
      ]
    }
  }
}
```

`nominalSpeed: 20` and the `footstep` frames (3 and 7) were measured in T5.3 (F14 in the [audit](asset-format.md#current-asset-audit-2026-10-16)).

## Top-level fields

| Field | Type | Required | Rules |
|---|---|---|---|
| `schemaVersion` | Int | yes | Must be `1` for this spec |
| `id` | String | yes | `^[a-z0-9][a-z0-9-]*$`; unique among loaded packs |
| `displayName` | String | yes | Shown in Settings (localizable later) |
| `defaultAnimation` | String | yes | Must name a valid clip; used as the last fallback |
| `defaultFacing` | `"left"` \| `"right"` | no (default `"right"`) | Direction the art faces |
| `canvas` | `{width, height}` (pixels) | yes | Default canvas for clips; frames whose image size differs produce a warning |
| `displaySize` | `{width, height}` (points) | yes | On-screen size of the canvas at user scale 1.0; > 0 |
| `anchor` | `{x, y}` (0…1, origin bottom-left) | yes | Contact point within the canvas |
| `fallbacks` | `{clip: clip}` | no | Maps a missing/invalid clip name to another; chains allowed, cycles forbidden |
| `sheets` | `{name: Sheet}` | no | Sprite sheets referenced by frames (see below) |
| `personality` | `{curiosity, playfulness, laziness, sociability}` (0…1) | no | Defaults for the behavior engine (M9) |
| `animations` | `{clip: Clip}` | yes, non-empty | Clip names `^[a-z0-9][a-z0-9-]*$` |

## Clip fields

| Field | Type | Required | Rules |
|---|---|---|---|
| `playback` | `"loop"` \| `"once"` \| `"pingPong"` | no (default `"loop"`) | |
| `fps` | Number | required unless every frame has `duration` | 0 < fps ≤ 60 |
| `frames` | `[Frame]` | yes | ≥ 1 frame; any count |
| `next` | String | no | Only with `"once"`; clip to play when finished; must exist |
| `nominalSpeed` | Number (pt/s at user scale 1.0) | no | Ground speed matching the art; used by locomotion clips |
| `facing` | `"left"` \| `"right"` | no (default `defaultFacing`) | |
| `mirrorable` | Bool | no (default `true`) | If `false`, the opposite direction needs a `variants` entry |
| `variants` | `{"left"|"right": clip}` | no | Dedicated clip per direction |
| `anchor` | `{x, y}` | no (default top-level) | Override for poses with a different contact point |
| `canvas` | `{width, height}` | no (default top-level) | Override for clips needing more room |
| `alignment` | `"bottom"` \| `"left"` \| `"right"` \| `"top"` | no (default `"bottom"`) | Which canvas side touches the surface (climbing uses `left`/`right`) |
| `interruptible` | Bool | no (default `true`) | If `false`, only priority ≥ 90 requests interrupt (see [state-machines.md](state-machines.md)) |

## Frame fields

Exactly one source per frame:

| Field | Type | Rules |
|---|---|---|
| `image` | String | Relative path inside the pack; `.png`; no absolute paths, no `..` |
| `sheet` + `cell` | String + Int | `sheet` names an entry in `sheets`; `cell` is 0-based, row-major |
| `duration` | Number (s) | Optional; overrides `1/fps`; 0 < duration ≤ 10 |
| `events` | `[String]` | Optional; names `^[a-z0-9][a-z0-9-]*$`; emitted when the frame is entered |

Sheet: `{ "image": "walk/walk_atlas.png", "columns": 4, "rows": 2 }` — cells are equal-size
rectangles; cell size = image size / grid. Sheet support is optional for the MVP loader (T4.6b).

## Well-known event names

| Name | Meaning |
|---|---|
| `footstep` | A paw touches the ground (sound/particle hooks later) |
| `takeoff` | Jump leaves the surface — physics applies the jump velocity on this frame (M8) |
| `apex` | Top of the jump (M8) |
| `contact` | Landing impact frame (M7/M8) |

Engine-generated (not declared in data): `loopCompleted`, `finished`.
Unknown event names are allowed and passed through (logged in DEBUG).

## Validation

Errors make a clip invalid (it then resolves through `fallbacks`); errors on the default clip or at
the top level make the whole pack invalid.

| Code | Level | Condition |
|---|---|---|
| `unsupportedSchemaVersion` | pack error | `schemaVersion` ≠ 1 |
| `invalidIdentifier` | pack/clip error | `id`, clip or event name fails its pattern |
| `missingDefaultAnimation` | pack error | `defaultAnimation` absent or invalid after fallback resolution |
| `emptyFrames` | clip error | `frames` is empty |
| `invalidTiming` | clip error | no `fps` and a frame lacks `duration`; values out of range |
| `invalidFrameSource` | clip error | none or both of `image` / `sheet`+`cell`; bad path; unknown sheet; cell out of range |
| `missingFile` | clip error | referenced image not found (checked at load time) |
| `undecodableImage` | clip error | ImageIO cannot decode |
| `invalidNext` | clip error | `next` on a looping clip, or target missing |
| `fallbackCycle` | pack error | cycle in `fallbacks` |
| `invalidAnchor` / `invalidSize` | pack/clip error | out-of-range numbers |
| `canvasMismatch` | warning | image pixel size ≠ declared canvas |
| `unusedSheet` | warning | sheet never referenced |
| `unknownField` | warning (DEBUG log) | forward-compatible; ignored |

Validation is pure (no file I/O) except `missingFile` / `undecodableImage`, which the loader adds.
All bundled packs are validated by a unit test so broken manifests fail CI, not users.

## Versioning

- Additive, optional fields do **not** bump `schemaVersion`.
- Renames, removals, semantic changes **do** bump it. The loader supports the current version and
  migrates the previous one in code (`ManifestMigrator`), with tests per migration.
- A newer, unsupported version is rejected with `unsupportedSchemaVersion` (no partial loading).

## How to add a new animation

1. Put frames under `assets/characters/<id>/<clip>/frames/` following [asset-format.md](asset-format.md).
2. Add a clip entry: `playback`, `fps` (or per-frame `duration`), `frames`, optional `anchor`,
   `alignment`, `events`, `next`, `nominalSpeed`.
3. If the clip replaces a fallback (e.g. a real `fall`), remove that entry from `fallbacks`.
4. Run `make test` — the manifest validation test must pass.
5. Launch the app with the DEBUG "Animation preview" menu (T4.10) to check anchor and timing.
6. No code changes are needed unless a **new behavior** must use the clip.
