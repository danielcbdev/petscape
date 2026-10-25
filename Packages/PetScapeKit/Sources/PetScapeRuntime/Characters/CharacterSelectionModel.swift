import Foundation
import Observation
import PetScapeCore
import PetScapePlatform

public enum CharacterSelectionIssue: Equatable, Sendable {
    /// Retained for source compatibility with the M18 bundled-only selector.
    case noBundledCharacters
    case noCharactersAvailable
    case characterCouldNotLoad
    case waitForSafeBoundary
}

/// Validates first, applies synchronously on MainActor, then persists only a successful transaction.
@Observable
public final class CharacterSelectionModel {
    public private(set) var characters: [CharacterCatalogEntry] = []
    public private(set) var activeID: CharacterID?
    public private(set) var isLoading = true
    public private(set) var isInstalling = false
    public private(set) var unavailableCount = 0
    public private(set) var installationSucceeded = false
    /// A semantic selection issue for the app layer to localize in its current SwiftUI environment.
    public private(set) var issue: CharacterSelectionIssue?
    /// A semantic import issue for the app layer to localize in its current SwiftUI environment.
    public private(set) var installIssue: CharacterPackImportError?
    public var onApplied: ((LoadedCharacter) -> Void)?
    public var canSelect: Bool { characters.count > 1 && !isLoading && !isInstalling }
    public var activeName: String? { characters.first { $0.id == activeID }?.displayName }
    public var activeOrigin: CharacterPackOrigin? { characters.first { $0.id == activeID }?.origin }

    @ObservationIgnored private let preferences: any PreferencesStore
    @ObservationIgnored private let apply: (LoadedCharacter) -> Bool
    @ObservationIgnored private let load: (URL) async -> LoadedCharacter
    @ObservationIgnored private let installer: CharacterPackInstaller?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var isStopped = false

    public init(
        preferences: any PreferencesStore,
        installedPacksRoot: URL? = nil,
        apply: @escaping (LoadedCharacter) -> Bool,
        load: @escaping (URL) async -> LoadedCharacter = { await CharacterLoader().loadForSelection(packURL: $0) }
    ) {
        self.preferences = preferences
        self.apply = apply
        self.load = load
        installer = installedPacksRoot.map(CharacterPackInstaller.init(rootURL:))
    }

    /// Startup fallback order is stable across directory order, filenames and display-name translations.
    public func start(catalog: CharacterCatalog) async {
        generation += 1
        let token = generation
        isStopped = false
        isLoading = true
        isInstalling = false
        activeID = nil
        issue = nil
        installIssue = nil
        installationSucceeded = false
        characters = catalog.characters.sorted { $0.id.rawValue < $1.id.rawValue }
        unavailableCount = catalog.unavailableCount
        defer { if generation == token { isLoading = false } }
        let preferred = preferences.selectedCharacterID ?? "cat"
        let ordered = characters.sorted {
            func rank(_ entry: CharacterCatalogEntry) -> Int {
                entry.id.rawValue == preferred ? 0 : (entry.id.rawValue == "cat" ? 1 : 2)
            }
            return rank($0) == rank($1) ? $0.id.rawValue < $1.id.rawValue : rank($0) < rank($1)
        }
        for candidate in ordered {
            let character = await load(candidate.packURL)
            guard isCurrent(token) else { return }
            if isValid(character, for: candidate) {
                if commit(character) { return }
                issue = .waitForSafeBoundary
                return
            }
            exclude(candidate.id)
        }
        guard isCurrent(token) else { return }
        let placeholder = CharacterLoader.placeholder(failure: .manifestMissing)
        if apply(placeholder) { onApplied?(placeholder) }
        issue = .noCharactersAvailable
    }

    public func select(_ id: CharacterID) async {
        guard !isStopped, !isLoading, !isInstalling, id != activeID,
            let candidate = characters.first(where: { $0.id == id })
        else { return }
        isLoading = true
        issue = nil
        installIssue = nil
        installationSucceeded = false
        let token = generation
        defer { if generation == token { isLoading = false } }
        let character = await load(candidate.packURL)
        guard isCurrent(token) else { return }
        guard isValid(character, for: candidate) else {
            exclude(id)
            issue = .characterCouldNotLoad
            return
        }
        if !commit(character) { issue = .waitForSafeBoundary }
    }

    public func installPack(from sourceURL: URL) async {
        guard !isStopped, !isLoading, !isInstalling else { return }
        guard let installer else {
            installIssue = .storageUnavailable
            installationSucceeded = false
            return
        }

        isInstalling = true
        installIssue = nil
        issue = nil
        installationSucceeded = false
        let token = generation
        defer { if generation == token { isInstalling = false } }

        let bundledIDs = Set(characters.lazy.filter { $0.origin == .bundled }.map(\.id))
        let installedIDs = Set(characters.lazy.filter { $0.origin == .installed }.map(\.id))
        do {
            let entry = try await installer.install(
                from: sourceURL, bundledIDs: bundledIDs, installedIDs: installedIDs,
                shouldContinue: { [weak self] in self?.isCurrent(token) == true })
            guard isCurrent(token) else { return }
            characters.append(entry)
            characters.sort { $0.id.rawValue < $1.id.rawValue }
            installationSucceeded = true
        } catch let error as CharacterPackImportError {
            guard isCurrent(token) else { return }
            if error != .cancelled { installIssue = error }
        } catch {
            guard isCurrent(token) else { return }
            installIssue = .installationFailed
        }
    }

    public func reportImportPickerFailure() {
        guard !isStopped else { return }
        installationSucceeded = false
        installIssue = .installationFailed
    }

    public func stop() {
        generation += 1
        isStopped = true
        isLoading = false
        isInstalling = false
    }

    private func isCurrent(_ token: Int) -> Bool {
        generation == token && !isStopped && !Task.isCancelled
    }

    private func isValid(_ character: LoadedCharacter, for candidate: CharacterCatalogEntry) -> Bool {
        !character.isPlaceholder && !character.isDegraded && character.definition.id == candidate.id
    }

    private func exclude(_ id: CharacterID) {
        characters.removeAll { $0.id == id }
        unavailableCount += 1
    }

    private func commit(_ character: LoadedCharacter) -> Bool {
        guard apply(character) else { return false }
        activeID = character.definition.id
        preferences.selectedCharacterID = character.definition.id.rawValue
        onApplied?(character)
        return true
    }
}
