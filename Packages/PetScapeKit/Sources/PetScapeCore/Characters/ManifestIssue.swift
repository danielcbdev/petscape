/// Validation codes from docs/specifications/animation-schema.md#validation.
///
/// The raw values are part of the contract: they appear in logs and in the per-code test fixtures.
public enum ManifestIssueCode: String, CaseIterable, Sendable {
    case unsupportedSchemaVersion
    case invalidIdentifier
    case missingDefaultAnimation
    case emptyFrames
    case invalidTiming
    case invalidFrameSource
    case missingFile
    case undecodableImage
    case invalidNext
    case fallbackCycle
    case invalidAnchor
    case invalidSize
    case canvasMismatch
    case unusedSheet
    case unknownField
}

public enum ManifestIssueSeverity: Sendable {
    /// Makes a clip invalid (it then resolves through `fallbacks`) or, at pack scope, the whole pack.
    case error
    /// Reported and logged; loading continues.
    case warning
}

/// What an issue applies to.
public enum ManifestIssueScope: Hashable, Sendable {
    case pack
    case clip(String)
}

/// One validation finding, with enough context (clip, field, path) for a useful log line.
public struct ManifestIssue: Equatable, Sendable, CustomStringConvertible {
    public var code: ManifestIssueCode
    public var severity: ManifestIssueSeverity
    public var scope: ManifestIssueScope
    public var detail: String

    public init(code: ManifestIssueCode, severity: ManifestIssueSeverity, scope: ManifestIssueScope, detail: String) {
        self.code = code
        self.severity = severity
        self.scope = scope
        self.detail = detail
    }

    public var description: String {
        let level =
            switch severity {
            case .error: "error"
            case .warning: "warning"
            }
        let target =
            switch scope {
            case .pack: "pack"
            case .clip(let name): "clip '\(name)'"
            }
        return "\(level) \(code.rawValue) (\(target)): \(detail)"
    }
}

/// What metadata inspection found for one image file referenced by a manifest (input for file checks).
public enum ImageProbe: Equatable, Sendable {
    case missing
    case undecodable
    /// Readable image metadata; size is the source file's pixel size (before downsampling).
    case decoded(pixelWidth: Int, pixelHeight: Int)
}

/// Result of `ManifestValidator.validate`.
public struct ManifestValidationReport: Equatable, Sendable {
    public var issues: [ManifestIssue]
    /// Clips with at least one clip-scope error; they resolve through `fallbacks`.
    public var invalidClips: Set<String>
    /// The clip `defaultAnimation` resolves to, or `nil` when the pack has no usable default.
    public var resolvedDefaultClip: String?

    public init(issues: [ManifestIssue], invalidClips: Set<String>, resolvedDefaultClip: String?) {
        self.issues = issues
        self.invalidClips = invalidClips
        self.resolvedDefaultClip = resolvedDefaultClip
    }

    public var errors: [ManifestIssue] { issues.filter { $0.severity == .error } }
    public var warnings: [ManifestIssue] { issues.filter { $0.severity == .warning } }

    /// `false` when any pack-scope error exists; the character then fails to load (placeholder).
    public var isPackValid: Bool {
        !issues.contains { $0.severity == .error && $0.scope == .pack }
    }

    public func contains(_ code: ManifestIssueCode) -> Bool {
        issues.contains { $0.code == code }
    }
}
