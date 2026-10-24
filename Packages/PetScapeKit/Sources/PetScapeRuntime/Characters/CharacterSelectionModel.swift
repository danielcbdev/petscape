import Foundation
import Observation
import PetScapeCore
import PetScapePlatform

/// Validates first, applies synchronously on MainActor, then persists only a successful transaction.
@Observable
public final class CharacterSelectionModel {
    public private(set) var characters: [BundledCharacter] = []
    public private(set) var activeID: CharacterID?
    public private(set) var isLoading = true
    public private(set) var unavailableCount = 0
    public private(set) var error: String?
    public var onApplied: ((LoadedCharacter) -> Void)?
    public var canSelect: Bool { characters.count > 1 && !isLoading }
    public var activeName: String? { characters.first { $0.id == activeID }?.displayName }

    @ObservationIgnored private let preferences: any PreferencesStore
    @ObservationIgnored private let apply: (LoadedCharacter) -> Bool
    @ObservationIgnored private let load: (URL) async -> LoadedCharacter
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var isStopped = false

    public init(
        preferences: any PreferencesStore,
        apply: @escaping (LoadedCharacter) -> Bool,
        load: @escaping (URL) async -> LoadedCharacter = { await CharacterLoader().loadForSelection(packURL: $0) }
    ) {
        self.preferences = preferences
        self.apply = apply
        self.load = load
    }

    /// Startup fallback order is stable across directory order, filenames and display-name translations.
    public func start(catalog: BundledCharacterCatalog) async {
        generation += 1
        let token = generation
        isStopped = false
        isLoading = true
        activeID = nil
        error = nil
        characters = catalog.characters.sorted { $0.id.rawValue < $1.id.rawValue }
        unavailableCount = catalog.unavailableCount
        defer { if generation == token { isLoading = false } }
        let preferred = preferences.selectedCharacterID ?? "cat"
        let ordered = characters.sorted {
            func rank(_ entry: BundledCharacter) -> Int {
                entry.id.rawValue == preferred ? 0 : (entry.id.rawValue == "cat" ? 1 : 2)
            }
            return rank($0) == rank($1) ? $0.id.rawValue < $1.id.rawValue : rank($0) < rank($1)
        }
        for candidate in ordered {
            let character = await load(candidate.packURL)
            guard isCurrent(token) else { return }
            if isValid(character, for: candidate) {
                if commit(character) { return }
                error = Self.retryMessage
                return
            }
            exclude(candidate.id)
        }
        guard isCurrent(token) else { return }
        let placeholder = CharacterLoader.placeholder(failure: .manifestMissing)
        if apply(placeholder) { onApplied?(placeholder) }
        error = String(localized: "No bundled characters could be loaded.")
    }

    public func select(_ id: CharacterID) async {
        guard !isStopped, !isLoading, id != activeID,
            let candidate = characters.first(where: { $0.id == id })
        else { return }
        isLoading = true
        error = nil
        let token = generation
        defer { if generation == token { isLoading = false } }
        let character = await load(candidate.packURL)
        guard isCurrent(token) else { return }
        guard isValid(character, for: candidate) else {
            exclude(id)
            error = String(localized: "This character could not be loaded. Your current pet is unchanged.")
            return
        }
        if !commit(character) { error = Self.retryMessage }
    }

    public func stop() {
        generation += 1
        isStopped = true
        isLoading = false
    }

    private static var retryMessage: String {
        String(localized: "Wait until your pet is walking or idle with enough room, then try again.")
    }

    private func isCurrent(_ token: Int) -> Bool {
        generation == token && !isStopped && !Task.isCancelled
    }

    private func isValid(_ character: LoadedCharacter, for candidate: BundledCharacter) -> Bool {
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
