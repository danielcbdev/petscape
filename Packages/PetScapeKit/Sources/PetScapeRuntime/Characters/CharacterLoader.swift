import Foundation
import PetScapeCore
import PetScapeRendering

/// Loads a character pack: reads and validates `character.json`, decodes and caches the frames, checks the
/// files, and resolves the definition (docs/architecture/animation-system.md#error-handling).
///
/// Never throws: any failure yields the placeholder character with `failure` set, and every problem is
/// logged (`assets` category) so the app keeps running and the failure is visible (FR-15).
public final class CharacterLoader {
    public static let manifestFileName = "character.json"

    private let store: FrameImageStore

    public init(store: FrameImageStore = FrameImageStore()) {
        self.store = store
    }

    public func load(packURL: URL) async -> LoadedCharacter {
        await load(packURL: packURL, confinedToPack: false)
    }

    private func load(packURL: URL, confinedToPack: Bool) async -> LoadedCharacter {
        let signpostID = Signposts.signposter.makeSignpostID()
        let interval = Signposts.signposter.beginInterval(Signposts.Interval.characterLoad, id: signpostID)
        defer { Signposts.signposter.endInterval(Signposts.Interval.characterLoad, interval) }

        let packName = packURL.lastPathComponent
        do {
            let character = try await loadPack(at: packURL, confinedToPack: confinedToPack)
            Log.assets.notice(
                "Loaded character '\(character.definition.id.rawValue, privacy: .public)': \(character.definition.clips.count) clip(s), \(character.pixelSize) px, \(character.decodedByteCount) bytes decoded"
            )
            return character
        } catch {
            Log.assets.error(
                "Character pack '\(packName, privacy: .public)' failed to load, using the placeholder: \(error.description, privacy: .public)"
            )
            return Self.placeholder(failure: error, store: store)
        }
    }

    /// Strict bundled-selection gate: all declared clips and sources must work. Validate full decoding,
    /// then discard noninitial buffers so M14 lazy family residency remains unchanged.
    public func loadForSelection(packURL: URL) async -> LoadedCharacter {
        let character = await load(packURL: packURL, confinedToPack: true)
        guard !character.isPlaceholder else { return character }
        guard !character.isDegraded else {
            return Self.placeholder(failure: .invalidPack(character.issues))
        }
        let definition = character.definition
        let sources = Set(definition.clips.values.flatMap { $0.frames.map(\.source) })
        let result = await store.preload(
            character: definition.id, packURL: packURL, sources: sources, pixelSize: character.pixelSize)
        guard result.failures.isEmpty else {
            Log.assets.error("Bundled character has undecodable resources")
            store.evict(character: definition.id)
            return Self.placeholder(failure: .manifestUnreadable("Character resources could not be decoded"))
        }
        let family = CharacterFrameCatalog.family(for: definition.defaultClipName)
        let initialSources = Set(
            definition.clips.filter { CharacterFrameCatalog.family(for: $0.key) == family }
                .values.flatMap { $0.frames.map(\.source) })
        store.evict(character: definition.id, keeping: initialSources)
        return character
    }

    @concurrent
    nonisolated private static func sourcesStayInsidePack(
        _ sources: Set<AnimationClip.FrameSource>, packURL: URL
    ) async -> Bool {
        let root = packURL.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        return sources.allSatisfy {
            packURL.appending(path: $0.imagePath).resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(root)
        }
    }

    // MARK: - Steps

    private func loadPack(at packURL: URL, confinedToPack: Bool) async throws(CharacterLoadError) -> LoadedCharacter {
        if confinedToPack,
            !(await Self.sourcesStayInsidePack([.image(Self.manifestFileName)], packURL: packURL))
        {
            throw .manifestUnreadable("Manifest outside character pack")
        }
        let data = try await Self.readManifest(at: packURL.appending(path: Self.manifestFileName))
        let decoded: DecodedManifest
        do {
            decoded = try CharacterManifest.decode(data)
        } catch {
            throw CharacterLoadError(error)
        }
        let manifest = decoded.manifest

        // 1. Structure only: drop clips that are already invalid before touching any file.
        let structural = ManifestValidator.validate(decoded)
        let provisional: CharacterDefinition
        do {
            provisional = try CharacterDefinition.resolve(manifest, report: structural)
        } catch {
            throw Self.loadError(error)
        }

        // 2. Probe all remaining sources without allocating decoded frame buffers.
        let characterID = provisional.id
        let pixelSize = FrameImageStore.targetPixelSize(for: manifest.displaySize)
        let sources = Set(provisional.clips.values.flatMap { $0.frames.map(\.source) })
        if confinedToPack, !(await Self.sourcesStayInsidePack(sources, packURL: packURL)) {
            throw .manifestUnreadable("Resource outside character pack")
        }
        let probe = await store.probe(packURL: packURL, sources: sources)
        var report = ManifestValidator.validate(decoded, images: probe.probes)
        Self.log(report.issues, pack: manifest.id)

        var definition: CharacterDefinition
        do {
            definition = try CharacterDefinition.resolve(manifest, report: report)
        } catch {
            store.evict(character: characterID)
            throw Self.loadError(error)
        }

        var initialFamily = CharacterFrameCatalog.family(for: definition.defaultClipName)
        let initialClips = definition.clips.filter {
            CharacterFrameCatalog.family(for: $0.key) == initialFamily
        }
        var initialSources = Set(initialClips.values.flatMap { $0.frames.map(\.source) })
        let initialLoad = await store.preload(
            character: characterID, packURL: packURL, sources: initialSources, pixelSize: pixelSize)
        if !initialLoad.failures.isEmpty {
            var probes = probe.probes
            probes.merge(initialLoad.probes) { _, decoded in decoded }
            report = ManifestValidator.validate(decoded, images: probes)
            Self.log(report.issues, pack: manifest.id)
            do {
                definition = try CharacterDefinition.resolve(manifest, report: report)
            } catch {
                store.evict(character: characterID)
                throw Self.loadError(error)
            }
            initialFamily = CharacterFrameCatalog.family(for: definition.defaultClipName)
            let resolvedClips = definition.clips.filter {
                CharacterFrameCatalog.family(for: $0.key) == initialFamily
            }
            initialSources = Set(resolvedClips.values.flatMap { $0.frames.map(\.source) })
            _ = await store.preload(
                character: characterID, packURL: packURL, sources: initialSources, pixelSize: pixelSize)
        }
        // The default behavior family is ready for the first frame; all other families remain undecoded.
        store.evict(character: characterID, keeping: initialSources)
        let catalog = CharacterFrameCatalog(
            definition: definition, packURL: packURL, pixelSize: pixelSize, store: store,
            loadedFamilies: [initialFamily])
        return LoadedCharacter(
            definition: definition, pixelSize: pixelSize, catalog: catalog,
            issues: report.issues.filter { $0.scope != .pack || $0.severity == .warning },
        )
    }

    @concurrent
    nonisolated private static func readManifest(at url: URL) async throws(CharacterLoadError) -> Data {
        guard FileManager.default.fileExists(atPath: url.path) else { throw .manifestMissing }
        do {
            return try Data(contentsOf: url)
        } catch {
            // A filesystem error description can contain the user's full pack path; keep logs path-free.
            throw .manifestUnreadable("filesystem read failed")
        }
    }

    private static func loadError(_ error: CharacterDefinitionError) -> CharacterLoadError {
        switch error {
        case .invalidPack(let issues): .invalidPack(issues)
        }
    }

    /// Clip errors at `.error` (they change what is shown), canvas mismatches at `.fault` in DEBUG and
    /// `.error` in release (animation-system.md), other warnings at `.info`, unknown fields at `.debug`.
    private static func log(_ issues: [ManifestIssue], pack: String) {
        for issue in issues {
            switch (issue.severity, issue.code) {
            case (.error, _):
                Log.assets.error("[\(pack, privacy: .public)] \(issue.description, privacy: .public)")
            case (.warning, .canvasMismatch):
                #if DEBUG
                    Log.assets.fault("[\(pack, privacy: .public)] \(issue.description, privacy: .public)")
                #else
                    Log.assets.error("[\(pack, privacy: .public)] \(issue.description, privacy: .public)")
                #endif
            case (.warning, .unknownField):
                Log.assets.debug("[\(pack, privacy: .public)] \(issue.description, privacy: .public)")
            case (.warning, _):
                Log.assets.info("[\(pack, privacy: .public)] \(issue.description, privacy: .public)")
            }
        }
    }

    // MARK: - Placeholder

    /// The programmatically drawn stand-in character: one still frame, 96 × 96 pt, used for every clip name.
    public static func placeholder(failure: CharacterLoadError, store: FrameImageStore = FrameImageStore())
        -> LoadedCharacter
    {
        let clipName = "placeholder"
        let imagePath = "placeholder.png"
        let manifest = CharacterManifest(
            id: clipName,
            displayName: "Placeholder",
            defaultAnimation: clipName,
            canvas: .init(width: 288, height: 288),
            displaySize: .init(width: 96, height: 96),
            anchor: .init(x: PlaceholderArtwork.anchor.x, y: PlaceholderArtwork.anchor.y),
            animations: [clipName: .init(fps: 1, frames: [.init(image: imagePath)])])
        let pixelSize = FrameImageStore.targetPixelSize(for: manifest.displaySize)
        guard
            let definition = try? CharacterDefinition.resolve(manifest, report: ManifestValidator.validate(manifest))
        else {
            // The manifest above is valid by construction (covered by CharacterLoaderTests).
            preconditionFailure("The placeholder manifest is invalid")
        }

        if let image = PlaceholderArtwork.makeImage(pixelSize: pixelSize), let frame = FrameImage(image: image) {
            store.insert(frame, character: definition.id, source: .image(imagePath), pixelSize: pixelSize)
        } else {
            Log.assets.fault("The placeholder artwork could not be drawn")
        }
        let family = CharacterFrameCatalog.family(for: clipName)
        let catalog = CharacterFrameCatalog(
            definition: definition, packURL: nil, pixelSize: pixelSize, store: store, loadedFamilies: [family])
        return LoadedCharacter(
            definition: definition, pixelSize: pixelSize, catalog: catalog, failure: failure)
    }
}
