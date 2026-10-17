/// Why a manifest could not be turned into a `CharacterDefinition`.
public enum CharacterDefinitionError: Error, Equatable, Sendable {
    /// The report has pack-scope errors (or no usable default clip); the character cannot be shown.
    case invalidPack([ManifestIssue])
}

/// The validated, resolved model of a character pack: every default applied, only valid clips kept, and a
/// precomputed table from any known clip name to a playable clip (fallback chains, then `defaultAnimation`).
/// Lookups at runtime are O(1) and never fail.
public struct CharacterDefinition: Equatable, Sendable {
    public var id: CharacterID
    public var displayName: String
    public var defaultFacing: Facing
    /// On-screen size of the canvas in points at user scale 1.0 (layer bounds come from here, never from pixels).
    public var displaySize: CharacterManifest.Size
    public var personality: CharacterManifest.Personality?
    /// Valid clips by name.
    public private(set) var clips: [String: AnimationClip]
    /// The clip used when nothing else resolves.
    public private(set) var defaultClipName: String
    private var resolution: [String: String]

    /// Builds the definition from a manifest and its validation report.
    ///
    /// Clips listed in `report.invalidClips` are dropped and resolve through `fallbacks` like missing clips.
    public static func resolve(
        _ manifest: CharacterManifest,
        report: ManifestValidationReport
    ) throws(CharacterDefinitionError) -> CharacterDefinition {
        guard report.isPackValid, let defaultClipName = report.resolvedDefaultClip else {
            throw .invalidPack(report.errors)
        }
        let fallbacks = manifest.fallbacks ?? [:]
        let validNames = Set(manifest.animations.keys).subtracting(report.invalidClips)
        func resolve(_ name: String) -> String? {
            FallbackResolver.resolve(name, fallbacks: fallbacks) { validNames.contains($0) }
        }

        var resolution: [String: String] = [:]
        let knownNames = Set(manifest.animations.keys).union(fallbacks.keys).union(fallbacks.values)
        for name in knownNames {
            resolution[name] = resolve(name) ?? defaultClipName
        }

        let defaultFacing = manifest.defaultFacing ?? .right
        var clips: [String: AnimationClip] = [:]
        for name in validNames {
            // Invariant: `validNames` is a subset of the manifest's clip names.
            let clip = manifest.animations[name]!
            clips[name] = makeClip(
                name, clip, manifest: manifest, defaultFacing: defaultFacing,
                next: clip.next.map { resolve($0) ?? defaultClipName },
                variants: (clip.variants ?? [:]).compactMapValues { resolve($0) })
        }

        return CharacterDefinition(
            id: CharacterID(manifest.id),
            displayName: manifest.displayName,
            defaultFacing: defaultFacing,
            displaySize: manifest.displaySize,
            personality: manifest.personality,
            clips: clips,
            defaultClipName: defaultClipName,
            resolution: resolution)
    }

    /// The playable clip name a request for `name` resolves to (fallback chain, else the default clip).
    public func resolvedClipName(for name: String) -> String {
        resolution[name] ?? defaultClipName
    }

    /// The playable clip for `name`; never fails.
    public func clip(named name: String) -> AnimationClip {
        // Invariant: every resolution target and the default clip are keys of `clips` (built together in `resolve`).
        clips[resolvedClipName(for: name)]!
    }

    /// The clip to show for `name` when the pet faces `facing`, and whether the layer must be mirrored.
    ///
    /// Uses the clip itself when it already faces that way, else a dedicated `variants` clip, else mirroring
    /// when the clip is `mirrorable`. A non-mirrorable clip without a variant is shown as authored.
    public func clip(named name: String, facing: Facing) -> (clip: AnimationClip, mirrored: Bool) {
        let base = clip(named: name)
        if base.facing == facing { return (base, false) }
        if let variantName = base.variants[facing], let variant = clips[variantName] {
            return (variant, variant.facing != facing && variant.mirrorable)
        }
        return (base, base.mirrorable)
    }

    /// Every image file the valid clips need (frame images and sheet images), pack-relative.
    public var imagePaths: Set<String> {
        Set(clips.values.flatMap { $0.frames.map(\.source.imagePath) })
    }

    private static func makeClip(
        _ name: String,
        _ clip: CharacterManifest.Clip,
        manifest: CharacterManifest,
        defaultFacing: Facing,
        next: String?,
        variants: [Facing: String]
    ) -> AnimationClip {
        let anchor = clip.anchor ?? manifest.anchor
        let canvas = clip.canvas ?? manifest.canvas
        let frames = (clip.frames ?? []).map { frame in
            // Invariant: the validator guarantees an fps when a frame has no duration.
            let duration = frame.duration ?? 1 / clip.fps!
            return AnimationClip.Frame(
                source: frameSource(frame, sheets: manifest.sheets ?? [:]), duration: duration,
                events: frame.events ?? [])
        }
        return AnimationClip(
            name: name,
            playback: clip.playback ?? .loop,
            frames: frames,
            next: next,
            nominalSpeed: clip.nominalSpeed,
            facing: clip.facing ?? defaultFacing,
            mirrorable: clip.mirrorable ?? true,
            variants: variants,
            anchor: anchor,
            canvas: canvas,
            alignment: clip.alignment ?? .bottom,
            interruptible: clip.interruptible ?? true)
    }

    private static func frameSource(
        _ frame: CharacterManifest.Frame,
        sheets: [String: CharacterManifest.Sheet]
    ) -> AnimationClip.FrameSource {
        if let sheetName = frame.sheet, let cell = frame.cell, let sheet = sheets[sheetName] {
            return .sheetCell(
                AnimationClip.Sheet(image: sheet.image, columns: sheet.columns, rows: sheet.rows), cell: cell)
        }
        // Invariant: the validator guarantees exactly one source per frame of a valid clip.
        return .image(frame.image!)
    }
}

extension CharacterManifest {
    /// Image files referenced by the given clips (frame images and the images of the sheets they use).
    public func imagePaths(ofClips names: some Sequence<String>) -> Set<String> {
        var paths: Set<String> = []
        for name in names {
            for frame in animations[name]?.frames ?? [] {
                if let image = frame.image { paths.insert(image) }
                if let sheet = frame.sheet.flatMap({ sheets?[$0] }) { paths.insert(sheet.image) }
            }
        }
        return paths
    }
}
