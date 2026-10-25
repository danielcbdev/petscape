import Foundation
import Observation
import PetScapeCore
import PetScapePlatform

public enum CharacterRosterIssue: Equatable, Sendable {
    case noBundledCharacters
    case noCharactersAvailable
    case characterCouldNotLoad
    case characterAlreadyActive
}

public struct CharacterRosterEntry: Identifiable, Sendable {
    public let petID: PetID
    public let character: CharacterCatalogEntry

    public var id: PetID { petID }
}

/// Catalog, loading and persisted active-roster intents. Simulation and rendering stay in PetRuntime.
@Observable
public final class CharacterRosterModel {
    public private(set) var characters: [CharacterCatalogEntry] = []
    public private(set) var activeCharacters: [CharacterRosterEntry] = []
    public private(set) var isLoading = true
    public private(set) var isInstalling = false
    public private(set) var unavailableCount = 0
    public private(set) var installationSucceeded = false
    public private(set) var issue: CharacterRosterIssue?
    public private(set) var failedAdditionID: CharacterID?
    public private(set) var installIssue: CharacterPackImportError?
    public private(set) var danceAvailability: [PetID: PetDanceAvailability] = [:]
    public private(set) var addingIDs: Set<CharacterID> = []

    @ObservationIgnored private let preferences: any PreferencesStore
    @ObservationIgnored private let runtime: PetRuntime
    @ObservationIgnored private let load: (URL) async -> LoadedCharacter
    @ObservationIgnored private let installer: CharacterPackInstaller?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var operationTokens: [CharacterID: Int] = [:]
    @ObservationIgnored private var loadTasks: [CharacterID: Task<LoadedCharacter, Never>] = [:]
    @ObservationIgnored private var isStopped = false

    public init(
        preferences: any PreferencesStore,
        runtime: PetRuntime,
        installedPacksRoot: URL? = nil,
        load: @escaping (URL) async -> LoadedCharacter = { await CharacterLoader().loadForSelection(packURL: $0) }
    ) {
        self.preferences = preferences
        self.runtime = runtime
        self.load = load
        installer = installedPacksRoot.map(CharacterPackInstaller.init(rootURL:))
        runtime.onPetDanceAvailabilityChange = { [weak self] availability in
            self?.danceAvailability = availability
        }
    }

    public var isImportDisabled: Bool { isInstalling || isLoading }

    public func isActive(_ id: CharacterID) -> Bool {
        activeCharacters.contains { $0.character.id == id }
    }

    public func isAdding(_ id: CharacterID) -> Bool { addingIDs.contains(id) }

    public func canAdd(_ id: CharacterID) -> Bool {
        !isStopped && !isLoading && !isInstalling && !isActive(id) && !addingIDs.contains(id)
            && characters.contains { $0.id == id }
    }

    public func canDance(_ petID: PetID) -> Bool { danceAvailability[petID]?.canDance == true }
    public func canStopDance(_ petID: PetID) -> Bool { danceAvailability[petID]?.canStopDance == true }
    public func isSpecialArtworkPending(_ petID: PetID) -> Bool {
        danceAvailability[petID]?.specialArtworkPending ?? true
    }

    public var canDanceAny: Bool { activeCharacters.contains { canDance($0.petID) } }
    public var canStopDanceAny: Bool { activeCharacters.contains { canStopDance($0.petID) } }

    public func dance(_ petID: PetID) { runtime.requestDance(for: petID) }
    public func stopDance(_ petID: PetID) { runtime.stopDance(for: petID) }

    /// A nil stored roster means first launch; an empty roster is intentional and remains empty.
    public func start(catalog: CharacterCatalog) async {
        generation += 1
        let token = generation
        isStopped = false
        isLoading = true
        isInstalling = false
        activeCharacters = []
        issue = nil
        failedAdditionID = nil
        installIssue = nil
        installationSucceeded = false
        characters = catalog.characters.sorted { $0.id.rawValue < $1.id.rawValue }
        unavailableCount = catalog.unavailableCount
        defer { if generation == token { isLoading = false } }

        let storedIDs = preferences.activeCharacterIDs
        if storedIDs == [] {
            if characters.isEmpty { issue = .noCharactersAvailable }
            return
        }
        guard !characters.isEmpty else {
            runtime.show(CharacterLoader.placeholder(failure: .manifestMissing))
            issue = .noCharactersAvailable
            return
        }

        let indexedCharacters = Dictionary(uniqueKeysWithValues: characters.map { ($0.id, $0) })
        let defaultOrder = characters.sorted {
            let leftRank = $0.id.rawValue == "cat" ? 0 : 1
            let rightRank = $1.id.rawValue == "cat" ? 0 : 1
            return leftRank == rightRank ? $0.id.rawValue < $1.id.rawValue : leftRank < rightRank
        }

        if let storedIDs {
            var seenIDs: Set<String> = []
            let uniqueIDs = storedIDs.filter { seenIDs.insert($0).inserted }
            let requested = uniqueIDs.compactMap { rawID -> CharacterCatalogEntry? in
                let id = CharacterID(rawID)
                guard let candidate = indexedCharacters[id] else { return nil }
                return candidate
            }
            var attemptedIDs: Set<CharacterID> = []
            for candidate in requested {
                guard isCurrent(token) else { return }
                attemptedIDs.insert(candidate.id)
                _ = await loadAndAdd(candidate, startupToken: token)
            }
            if !activeCharacters.isEmpty {
                persistRoster()
                return
            }
            if !storedIDs.isEmpty {
                for candidate in defaultOrder where !attemptedIDs.contains(candidate.id) {
                    guard isCurrent(token) else { return }
                    if await loadAndAdd(candidate, startupToken: token) { break }
                }
            }
        } else {
            for candidate in defaultOrder {
                guard isCurrent(token) else { return }
                if await loadAndAdd(candidate, startupToken: token) { break }
            }
        }

        guard isCurrent(token) else { return }
        if activeCharacters.isEmpty {
            runtime.show(CharacterLoader.placeholder(failure: .manifestMissing))
            issue = characters.isEmpty ? .noCharactersAvailable : .characterCouldNotLoad
        } else {
            persistRoster()
        }
    }

    /// Concurrent requests for one ID are rejected before I/O; commits revalidate after every await.
    public func add(_ id: CharacterID) async {
        guard canAdd(id), let candidate = characters.first(where: { $0.id == id }) else { return }
        issue = nil
        failedAdditionID = nil
        installIssue = nil
        installationSucceeded = false
        if await loadAndAdd(candidate, startupToken: nil) {
            persistRoster()
        } else {
            if characters.contains(where: { $0.id == id }) { failedAdditionID = id }
        }
    }

    /// Removes one active instance by its ephemeral runtime identity and persists the remaining stable IDs.
    @discardableResult
    public func remove(_ petID: PetID) -> Bool {
        guard let index = activeCharacters.firstIndex(where: { $0.petID == petID }) else { return false }
        guard runtime.removeCharacter(petID) else { return false }
        activeCharacters.remove(at: index)
        persistRoster()
        return true
    }

    /// Invalidates an in-flight load for an inactive catalog entry. Late results cannot add the pet.
    public func cancelAdd(_ id: CharacterID) {
        cancelLoad(for: id)
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
        for task in loadTasks.values { task.cancel() }
        loadTasks.removeAll()
        addingIDs.removeAll()
        for id in Array(operationTokens.keys) { operationTokens[id, default: 0] += 1 }
    }

    private func loadAndAdd(_ candidate: CharacterCatalogEntry, startupToken: Int?) async -> Bool {
        let id = candidate.id
        guard !isActive(id), !addingIDs.contains(id), !isStopped else { return false }
        let operationToken = operationTokens[id, default: 0] + 1
        operationTokens[id] = operationToken
        addingIDs.insert(id)
        let task = Task { await load(candidate.packURL) }
        loadTasks[id] = task
        let character = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        guard operationTokens[id] == operationToken, isCurrent(startupToken), !Task.isCancelled else {
            if operationTokens[id] == operationToken {
                loadTasks[id] = nil
                addingIDs.remove(id)
            }
            return false
        }
        loadTasks[id] = nil
        addingIDs.remove(id)
        guard !isActive(id) else { return false }
        guard !character.isPlaceholder, !character.isDegraded, character.definition.id == id else {
            exclude(id)
            issue = .characterCouldNotLoad
            return false
        }
        guard let petID = runtime.addCharacter(character) else {
            issue = .characterAlreadyActive
            return false
        }
        issue = nil
        activeCharacters.append(CharacterRosterEntry(petID: petID, character: candidate))
        return true
    }

    private func cancelLoad(for id: CharacterID) {
        operationTokens[id, default: 0] += 1
        loadTasks.removeValue(forKey: id)?.cancel()
        addingIDs.remove(id)
    }

    private func isCurrent(_ token: Int?) -> Bool {
        !isStopped && !Task.isCancelled && (token == nil || token == generation)
    }

    private func exclude(_ id: CharacterID) {
        characters.removeAll { $0.id == id }
        unavailableCount += 1
    }

    private func persistRoster() {
        preferences.activeCharacterIDs = activeCharacters.map { $0.character.id.rawValue }
    }
}
