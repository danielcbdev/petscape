# ADR-0007: Data-driven character packs (JSON manifest + PNG frames)

- Status: Proposed
- Date: 2026-10-16
- Related: [animation-schema.md](../specifications/animation-schema.md), [asset-format.md](../specifications/asset-format.md)

## Context

Current sprites are prototypes (8 frames, 512 px) and will be replaced with longer, better
animations. New characters are planned. Original source files must not be modified.

## Problem

How characters and animations are described, stored and bundled so art can change without code
changes.

## Alternatives

| Option | Pros | Cons |
|---|---|---|
| Hard-coded clip definitions in Swift | Type-safe | Every art change needs code; violates NFR-07 |
| Xcode asset catalog sprite atlases (`.spriteatlas`) | Build-time packing | Not loadable from user folders at runtime; metadata (anchors, events) still needs another file |
| **JSON manifest + PNG files in a pack folder, loaded at runtime with ImageIO** | Art-as-data; same loader for bundled and future user packs; validated by tests | We own validation, downsampling and caching |
| Third-party formats (Aseprite JSON, TexturePacker) | Tooling ecosystem | External dependency/format coupling; can be added later as an importer |

## Decision

- A **character pack** is a folder with `character.json` (schema v1) and the PNGs it references.
- The cat pack lives at `assets/characters/cat/` with a new `character.json`; original files there
  are read-only and referenced in place.
- Bundling: the app bundle contains `Resources/characters/<id>/` with the manifest and referenced
  frames. MVP mechanism (implemented in T4.9): an Xcode folder reference to `assets/characters`
  (simplest; also ships the unused originals — README, source `manifest.json`, atlas, GIF — about
  3.3 MB for the cat; `.DS_Store` is skipped by Xcode's copy), to be replaced in M14 by a build step that
  copies only manifest-referenced files.
- All bundled manifests are validated by unit tests.

## Rationale

Data-driven packs satisfy "replace art without code changes" and open the door to user packs
(FR-44). Runtime loading with downsampling keeps memory proportional to on-screen size.

## Consequences

- `ManifestValidator` and loader error handling are first-class, tested components.
- Schema evolution follows the versioning rules in the schema spec.

## Risks

| Risk | Mitigation |
|---|---|
| Large frame libraries blow the memory budget | Downsampling, lazy clip loading by behavior family (M14) |
| Bundling extra files (previews) | Accepted for MVP; M14 task to strip |
| Invalid user packs (future) | Same validation; failures isolated per pack |
