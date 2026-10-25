import Foundation
import PetScapeCore

/// Imports a selected schema-v1 pack into Application Support using a validated, private staging folder.
@MainActor
final class CharacterPackInstaller {
    private struct PreparedImport {
        let id: CharacterID
        let displayName: String
        let staging: CharacterPackStaging
    }

    private let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL
    }

    func install(
        from sourceURL: URL,
        bundledIDs: Set<CharacterID>,
        installedIDs: Set<CharacterID>,
        shouldContinue: () -> Bool
    ) async throws -> CharacterCatalogEntry {
        var staging: CharacterPackStaging?

        do {
            let prepared = try await prepare(
                from: sourceURL, bundledIDs: bundledIDs, installedIDs: installedIDs,
                shouldContinue: shouldContinue)
            staging = prepared.staging
            guard shouldContinue(), !Task.isCancelled else { throw CharacterPackImportError.cancelled }
            guard try await CharacterPackFileSystem.destinationExists(id: prepared.id.rawValue, in: rootURL) == false
            else { throw CharacterPackImportError.duplicateInstalledID }
            guard await stagedPackIsValid(at: prepared.staging.url, id: prepared.id) else {
                throw CharacterPackImportError.invalidPack
            }
            guard shouldContinue(), !Task.isCancelled else { throw CharacterPackImportError.cancelled }

            try await CharacterPackFileSystem.promote(prepared.staging, id: prepared.id.rawValue, in: rootURL)
            staging = nil
            return CharacterCatalogEntry(
                id: prepared.id, displayName: prepared.displayName,
                packURL: rootURL.appending(path: prepared.id.rawValue, directoryHint: .isDirectory),
                origin: .installed)
        } catch let error as CharacterPackImportError {
            if let staging { await CharacterPackFileSystem.removeStaging(staging) }
            throw error
        } catch {
            if let staging { await CharacterPackFileSystem.removeStaging(staging) }
            throw CharacterPackImportError.installationFailed
        }
    }

    private func prepare(
        from sourceURL: URL,
        bundledIDs: Set<CharacterID>,
        installedIDs: Set<CharacterID>,
        shouldContinue: () -> Bool
    ) async throws(CharacterPackImportError) -> PreparedImport {
        let snapshot = try await CharacterPackFileSystem.readSnapshot(from: sourceURL)
        guard shouldContinue(), !Task.isCancelled else { throw .cancelled }
        let pack = try await CharacterPackPolicy.validate(snapshot)
        guard shouldContinue(), !Task.isCancelled else { throw .cancelled }
        if bundledIDs.contains(pack.id) { throw .duplicateBundledID }
        if installedIDs.contains(pack.id) { throw .duplicateInstalledID }
        let staging = try await CharacterPackFileSystem.createStaging(pack, in: rootURL)
        guard shouldContinue(), !Task.isCancelled else {
            await CharacterPackFileSystem.removeStaging(staging)
            throw .cancelled
        }
        return PreparedImport(id: pack.id, displayName: pack.displayName, staging: staging)
    }

    private func stagedPackIsValid(at url: URL, id: CharacterID) async -> Bool {
        let character = await CharacterLoader().loadForSelection(packURL: url)
        return !character.isPlaceholder && !character.isDegraded && character.definition.id == id
    }
}
