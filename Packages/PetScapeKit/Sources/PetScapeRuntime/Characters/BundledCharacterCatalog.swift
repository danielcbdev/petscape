import Foundation
import PetScapeCore

/// Metadata only: catalog discovery releases its validation images before loading another pack.
public struct BundledCharacter: Identifiable, Sendable {
    public let id: CharacterID
    public let displayName: String
    public let packURL: URL

    public init(character: LoadedCharacter, packURL: URL) {
        id = character.definition.id
        displayName = character.definition.displayName
        self.packURL = packURL
    }
}

/// Only immediate pack directories below the root supplied by AppContainer are inspected.
public struct BundledCharacterCatalog: Sendable {
    public let characters: [BundledCharacter]
    public let unavailableCount: Int

    public init(characters: [BundledCharacter] = [], unavailableCount: Int = 0) {
        self.characters = characters
        self.unavailableCount = unavailableCount
    }

    public static func discover(in root: URL) async -> BundledCharacterCatalog {
        let folders = await packFolders(in: root)
        var candidates: [BundledCharacter] = []
        var unavailable = 0
        for folder in folders {
            guard !Task.isCancelled else { return BundledCharacterCatalog() }
            // A fresh loader/cache per candidate prevents duplicate IDs from sharing/evicting images.
            let loaded = await CharacterLoader().loadForSelection(packURL: folder)
            if loaded.isPlaceholder || loaded.isDegraded {
                unavailable += 1
            } else {
                candidates.append(BundledCharacter(character: loaded, packURL: folder))
            }
        }
        let counts = Dictionary(grouping: candidates, by: \.id)
        let valid = candidates.filter { counts[$0.id]?.count == 1 }
        unavailable += candidates.count - valid.count
        if unavailable > 0 {
            Log.assets.error("Bundled catalog excluded \(unavailable) invalid or duplicate pack(s)")
        }
        return BundledCharacterCatalog(
            characters: valid.sorted { $0.id.rawValue < $1.id.rawValue }, unavailableCount: unavailable)
    }

    @concurrent
    nonisolated private static func packFolders(in root: URL) async -> [URL] {
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        guard
            let children = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        else { return [] }
        return children.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                && $0.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(canonicalRoot)
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
