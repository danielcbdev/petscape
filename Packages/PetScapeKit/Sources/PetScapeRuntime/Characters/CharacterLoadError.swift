import PetScapeCore

/// Why a character pack could not be shown (the placeholder is used instead, FR-15).
public enum CharacterLoadError: Error, Equatable, Sendable, CustomStringConvertible {
    /// `character.json` does not exist at the pack location.
    case manifestMissing
    /// The file exists but could not be read.
    case manifestUnreadable(String)
    /// Not valid JSON, or valid JSON that does not match schema v1.
    case malformedManifest(String)
    case unsupportedSchemaVersion(Int?)
    /// Pack-scope validation errors (including a default clip whose files are missing or broken).
    case invalidPack([ManifestIssue])

    public var description: String {
        switch self {
        case .manifestMissing:
            "character.json is missing"
        case .manifestUnreadable(let reason):
            "character.json could not be read: \(reason)"
        case .malformedManifest(let reason):
            "character.json is malformed: \(reason)"
        case .unsupportedSchemaVersion(let version):
            "character.json has unsupported schemaVersion \(version.map(String.init) ?? "(none)")"
        case .invalidPack(let issues):
            "character pack is invalid: \(issues.map(\.description).joined(separator: "; "))"
        }
    }

    init(_ error: ManifestDecodingError) {
        switch error {
        case .malformedJSON(let reason), .schemaMismatch(let reason):
            self = .malformedManifest(reason)
        case .unsupportedSchemaVersion(let version):
            self = .unsupportedSchemaVersion(version)
        }
    }
}
