import Darwin
import Foundation
import PetScapeCore

public enum CharacterPackOrigin: String, Equatable, Sendable {
    case bundled
    case installed
}

public struct CharacterCatalogEntry: Identifiable, Sendable {
    public let id: CharacterID
    public let displayName: String
    public let packURL: URL
    public let origin: CharacterPackOrigin

    public init(
        id: CharacterID, displayName: String, packURL: URL, origin: CharacterPackOrigin
    ) {
        self.id = id
        self.displayName = displayName
        self.packURL = packURL
        self.origin = origin
    }

    public init(
        character: LoadedCharacter, packURL: URL, origin: CharacterPackOrigin = .bundled
    ) {
        id = character.definition.id
        displayName = character.definition.displayName
        self.packURL = packURL
        self.origin = origin
    }
}

/// Source-compatible name retained for the M18 tests and public package consumers.
public typealias BundledCharacter = CharacterCatalogEntry

public struct CharacterCatalog: Sendable {
    public let characters: [CharacterCatalogEntry]
    public let unavailableCount: Int

    public init(characters: [CharacterCatalogEntry] = [], unavailableCount: Int = 0) {
        self.characters = characters
        self.unavailableCount = unavailableCount
    }

    /// Compatibility entry point for M18 bundled-only catalog tests.
    public static func discover(in root: URL) async -> CharacterCatalog {
        await discover(bundledRoot: root, installedRoot: nil)
    }

    public static func discover(bundledRoot: URL, installedRoot: URL?) async -> CharacterCatalog {
        var candidates: [CharacterCatalogEntry] = []
        var unavailable = 0

        let bundled = await discoverCandidates(in: bundledRoot, origin: .bundled)
        candidates.append(contentsOf: bundled.entries)
        unavailable += bundled.unavailableCount

        if let installedRoot {
            let installed = await discoverCandidates(in: installedRoot, origin: .installed)
            candidates.append(contentsOf: installed.entries)
            unavailable += installed.unavailableCount
        }

        let groups = Dictionary(grouping: candidates, by: \.id)
        var unique: [CharacterCatalogEntry] = []
        for group in groups.values {
            let bundledEntries = group.filter { $0.origin == .bundled }
            let installedEntries = group.filter { $0.origin == .installed }
            if bundledEntries.count == 1 {
                unique.append(bundledEntries[0])
                unavailable += installedEntries.count
            } else if bundledEntries.count > 1 {
                unavailable += group.count
            } else if installedEntries.count == 1 {
                unique.append(installedEntries[0])
            } else {
                unavailable += installedEntries.count
            }
        }

        if unavailable > 0 {
            Log.assets.error("Character catalog excluded \(unavailable) invalid or duplicate pack(s)")
        }
        return CharacterCatalog(
            characters: unique.sorted { $0.id.rawValue < $1.id.rawValue },
            unavailableCount: unavailable)
    }

    private static func discoverCandidates(
        in root: URL, origin: CharacterPackOrigin
    ) async -> (entries: [CharacterCatalogEntry], unavailableCount: Int) {
        let folders = await packFolders(in: root)
        var candidates: [CharacterCatalogEntry] = []
        var unavailable = 0

        for folder in folders {
            guard !Task.isCancelled else { return ([], unavailable) }

            if origin == .installed {
                guard let descriptor = await validateInstalledFolder(folder),
                    descriptor.id.rawValue == folder.lastPathComponent
                else {
                    unavailable += 1
                    continue
                }
                let loaded = await CharacterLoader().loadForSelection(packURL: folder)
                guard !loaded.isPlaceholder, !loaded.isDegraded,
                    loaded.definition.id == descriptor.id
                else {
                    unavailable += 1
                    continue
                }
                candidates.append(
                    CharacterCatalogEntry(
                        id: descriptor.id, displayName: descriptor.displayName,
                        packURL: folder, origin: .installed))
            } else {
                let loaded = await CharacterLoader().loadForSelection(packURL: folder)
                guard !loaded.isPlaceholder, !loaded.isDegraded else {
                    unavailable += 1
                    continue
                }
                candidates.append(CharacterCatalogEntry(character: loaded, packURL: folder, origin: .bundled))
            }
        }
        return (candidates, unavailable)
    }

    private static func validateInstalledFolder(_ folder: URL) async -> (id: CharacterID, displayName: String)? {
        do {
            let snapshot = try await CharacterPackFileSystem.readSnapshot(from: folder)
            let pack = try await CharacterPackPolicy.validate(snapshot)
            return (pack.id, pack.displayName)
        } catch {
            return nil
        }
    }

    @concurrent
    nonisolated private static func packFolders(in root: URL) async -> [URL] {
        var rootInfo = stat()
        let rootURL = root.standardizedFileURL
        let status = rootURL.path.withCString { Darwin.lstat($0, &rootInfo) }
        guard status == 0, (rootInfo.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
            let rootValues = try? rootURL.resourceValues(forKeys: [.isAliasFileKey]),
            rootValues.isAliasFile != true
        else { return [] }

        guard
            let children = try? FileManager.default.contentsOfDirectory(
                at: rootURL, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isAliasFileKey],
                options: [.skipsHiddenFiles])
        else { return [] }
        return children.filter { child in
            guard
                let values = try? child.resourceValues(
                    forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isAliasFileKey])
            else { return false }
            return values.isDirectory == true
                && values.isSymbolicLink != true
                && values.isAliasFile != true
                && ManifestValidator.isValidIdentifier(child.lastPathComponent)
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

/// Source-compatible catalog name retained for M18.
public typealias BundledCharacterCatalog = CharacterCatalog
