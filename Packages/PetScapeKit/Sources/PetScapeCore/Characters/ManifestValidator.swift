/// Checks a decoded manifest against schema v1 (docs/specifications/animation-schema.md#validation).
///
/// Pure: no file I/O. The file checks (`missingFile`, `undecodableImage`, `canvasMismatch`) run only when the
/// loader passes `images`, the probe result for every image path it tried to decode.
public enum ManifestValidator {
    /// Inclusive frame-rate limits; `fps` must be in `(0, maxFPS]`.
    public static let maxFPS = 60.0
    /// Per-frame `duration` must be in `(0, maxFrameDuration]` seconds.
    public static let maxFrameDuration = 10.0

    public static func validate(
        _ decoded: DecodedManifest,
        images: [String: ImageProbe]? = nil
    ) -> ManifestValidationReport {
        var context = Context(manifest: decoded.manifest, images: images)
        context.run(unknownFields: decoded.unknownFields)
        return context.report
    }

    public static func validate(
        _ manifest: CharacterManifest,
        images: [String: ImageProbe]? = nil
    ) -> ManifestValidationReport {
        validate(DecodedManifest(manifest: manifest), images: images)
    }

    /// `^[a-z0-9][a-z0-9-]*$`, used for the character id, clip names and event names.
    public static func isValidIdentifier(_ value: String) -> Bool {
        guard let first = value.utf8.first, isLowercaseAlphanumeric(first) else { return false }
        return value.utf8.allSatisfy { isLowercaseAlphanumeric($0) || $0 == UInt8(ascii: "-") }
    }

    /// A pack-relative PNG path: not empty, not absolute, no `..` component, `.png` extension.
    public static func isValidImagePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasPrefix("~"), !path.contains("\\") else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.contains(where: { $0 == ".." || $0.isEmpty }) else { return false }
        return path.lowercased().hasSuffix(".png") && path.count > ".png".count
    }

    private static func isLowercaseAlphanumeric(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte) || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
    }

    // MARK: - Implementation

    private struct Context {
        let manifest: CharacterManifest
        let images: [String: ImageProbe]?
        var issues: [ManifestIssue] = []
        var invalidClips: Set<String> = []
        var resolvedDefaultClip: String?

        init(manifest: CharacterManifest, images: [String: ImageProbe]?) {
            self.manifest = manifest
            self.images = images
        }

        var report: ManifestValidationReport {
            ManifestValidationReport(
                issues: issues, invalidClips: invalidClips, resolvedDefaultClip: resolvedDefaultClip)
        }

        mutating func run(unknownFields: [String]) {
            for field in unknownFields {
                warn(.unknownField, .pack, "Unknown field '\(field)' is ignored")
            }
            guard manifest.schemaVersion == CharacterManifest.supportedSchemaVersion else {
                packError(.unsupportedSchemaVersion, "schemaVersion \(manifest.schemaVersion) is not supported")
                return
            }
            if !isValidIdentifier(manifest.id) {
                packError(.invalidIdentifier, "Character id '\(manifest.id)' must match ^[a-z0-9][a-z0-9-]*$")
            }
            checkSize(manifest.canvas, field: "canvas", scope: .pack)
            checkSize(manifest.displaySize, field: "displaySize", scope: .pack)
            checkAnchor(manifest.anchor, field: "anchor", scope: .pack)

            let validSheets = checkSheets()
            for name in manifest.animations.keys.sorted() {
                // Invariant: `name` comes from the dictionary's own keys.
                checkClip(name, manifest.animations[name]!, validSheets: validSheets)
            }
            checkFallbacks()
            resolveDefault()
        }

        // MARK: Top level

        /// Reports sheet problems once; returns the sheets frames may use.
        mutating func checkSheets() -> Set<String> {
            let sheets = manifest.sheets ?? [:]
            var valid: Set<String> = []
            let referenced = Set(manifest.animations.values.flatMap { ($0.frames ?? []).compactMap(\.sheet) })
            for (name, sheet) in sheets.sorted(by: { $0.key < $1.key }) {
                if !referenced.contains(name) {
                    warn(.unusedSheet, .pack, "Sheet '\(name)' is never referenced by a frame")
                }
                if isValidImagePath(sheet.image), sheet.columns >= 1, sheet.rows >= 1 {
                    valid.insert(name)
                }
            }
            return valid
        }

        mutating func checkFallbacks() {
            let fallbacks = manifest.fallbacks ?? [:]
            for (source, target) in fallbacks.sorted(by: { $0.key < $1.key }) {
                for name in [source, target] where !isValidIdentifier(name) {
                    packError(.invalidIdentifier, "Fallback clip name '\(name)' must match ^[a-z0-9][a-z0-9-]*$")
                }
            }
            for cycle in FallbackResolver.cycles(in: fallbacks) {
                let path = (cycle + [cycle[0]]).joined(separator: " → ")
                packError(.fallbackCycle, "Fallback cycle \(path)")
            }
        }

        mutating func resolveDefault() {
            guard let name = manifest.defaultAnimation else {
                packError(.missingDefaultAnimation, "defaultAnimation is missing")
                return
            }
            let fallbacks = manifest.fallbacks ?? [:]
            let invalid = invalidClips
            let clips = manifest.animations
            let resolved = FallbackResolver.resolve(name, fallbacks: fallbacks) {
                clips[$0] != nil && !invalid.contains($0)
            }
            guard let resolved else {
                let reason = clips[name] == nil ? "does not name a clip" : "is invalid and has no valid fallback"
                packError(.missingDefaultAnimation, "defaultAnimation '\(name)' \(reason)")
                return
            }
            resolvedDefaultClip = resolved
        }

        // MARK: Clips

        mutating func checkClip(_ name: String, _ clip: CharacterManifest.Clip, validSheets: Set<String>) {
            let scope = ManifestIssueScope.clip(name)
            if !isValidIdentifier(name) {
                clipError(.invalidIdentifier, name, "Clip name '\(name)' must match ^[a-z0-9][a-z0-9-]*$")
            }
            if let canvas = clip.canvas { checkSize(canvas, field: "canvas", scope: scope) }
            if let anchor = clip.anchor { checkAnchor(anchor, field: "anchor", scope: scope) }
            checkNext(name, clip)

            let frames = clip.frames ?? []
            guard !frames.isEmpty else {
                clipError(.emptyFrames, name, "Clip has no frames")
                return
            }
            checkTiming(name, clip, frames)
            let canvas = clip.canvas ?? manifest.canvas
            for (index, frame) in frames.enumerated() {
                for event in frame.events ?? [] where !isValidIdentifier(event) {
                    clipError(.invalidIdentifier, name, "Event name '\(event)' on frame \(index) is invalid")
                }
                checkFrameSource(name, index, frame, canvas: canvas, validSheets: validSheets)
            }
        }

        mutating func checkNext(_ name: String, _ clip: CharacterManifest.Clip) {
            guard let next = clip.next else { return }
            if (clip.playback ?? .loop) != .once {
                clipError(.invalidNext, name, "'next' is only allowed on clips with playback \"once\"")
            } else if manifest.animations[next] == nil {
                clipError(.invalidNext, name, "'next' names the missing clip '\(next)'")
            }
        }

        mutating func checkTiming(_ name: String, _ clip: CharacterManifest.Clip, _ frames: [CharacterManifest.Frame]) {
            if let fps = clip.fps, !(fps.isFinite && fps > 0 && fps <= maxFPS) {
                clipError(.invalidTiming, name, "fps \(fps) must be in (0, \(Int(maxFPS))]")
            }
            for (index, frame) in frames.enumerated() {
                if let duration = frame.duration {
                    if !(duration.isFinite && duration > 0 && duration <= maxFrameDuration) {
                        clipError(.invalidTiming, name, "Frame \(index) duration \(duration) must be in (0, 10] s")
                    }
                } else if clip.fps == nil {
                    clipError(.invalidTiming, name, "Frame \(index) has no duration and the clip has no fps")
                }
            }
        }

        mutating func checkFrameSource(
            _ name: String,
            _ index: Int,
            _ frame: CharacterManifest.Frame,
            canvas: CharacterManifest.Size,
            validSheets: Set<String>
        ) {
            switch (frame.image, frame.sheet, frame.cell) {
            case (let image?, nil, nil):
                guard isValidImagePath(image) else {
                    clipError(
                        .invalidFrameSource, name, "Frame \(index) image path '\(image)' is not a pack-relative .png")
                    return
                }
                checkFile(image, clip: name, expectedPixelSize: canvas, cells: (1, 1))
            case (nil, let sheetName?, let cell?):
                guard let sheet = manifest.sheets?[sheetName] else {
                    clipError(.invalidFrameSource, name, "Frame \(index) references the unknown sheet '\(sheetName)'")
                    return
                }
                guard validSheets.contains(sheetName) else {
                    clipError(.invalidFrameSource, name, "Frame \(index) uses the invalid sheet '\(sheetName)'")
                    return
                }
                guard cell >= 0, cell < sheet.columns * sheet.rows else {
                    clipError(.invalidFrameSource, name, "Frame \(index) cell \(cell) is outside sheet '\(sheetName)'")
                    return
                }
                checkFile(sheet.image, clip: name, expectedPixelSize: canvas, cells: (sheet.columns, sheet.rows))
            default:
                clipError(
                    .invalidFrameSource, name, "Frame \(index) needs exactly one source: 'image' or 'sheet' + 'cell'")
            }
        }

        mutating func checkFile(
            _ path: String,
            clip name: String,
            expectedPixelSize canvas: CharacterManifest.Size,
            cells: (columns: Int, rows: Int)
        ) {
            guard let images else { return }
            switch images[path] ?? .missing {
            case .missing:
                clipError(.missingFile, name, "Image '\(path)' was not found in the pack")
            case .undecodable:
                clipError(.undecodableImage, name, "Image '\(path)' could not be decoded")
            case .decoded(let width, let height):
                let cellWidth = Double(width) / Double(cells.columns)
                let cellHeight = Double(height) / Double(cells.rows)
                let detail =
                    "Image '\(path)' is \(width)×\(height) px; expected cells of \(format(canvas.width))×\(format(canvas.height))"
                if cellWidth != canvas.width || cellHeight != canvas.height,
                    !issues.contains(where: {
                        $0.code == .canvasMismatch && $0.scope == .clip(name) && $0.detail == detail
                    })
                {
                    warn(.canvasMismatch, .clip(name), detail)
                }
            }
        }

        // MARK: Numbers

        mutating func checkSize(_ size: CharacterManifest.Size, field: String, scope: ManifestIssueScope) {
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
                error(.invalidSize, scope, "\(field) \(format(size.width))×\(format(size.height)) must be > 0")
                return
            }
        }

        mutating func checkAnchor(_ anchor: CharacterManifest.Point, field: String, scope: ManifestIssueScope) {
            let range = 0.0...1.0
            guard range.contains(anchor.x), range.contains(anchor.y) else {
                error(.invalidAnchor, scope, "\(field) (\(format(anchor.x)), \(format(anchor.y))) must be within 0…1")
                return
            }
        }

        func format(_ value: Double) -> String {
            value.rounded() == value && value.isFinite ? String(Int(value)) : String(value)
        }

        // MARK: Recording

        mutating func error(_ code: ManifestIssueCode, _ scope: ManifestIssueScope, _ detail: String) {
            switch scope {
            case .pack: packError(code, detail)
            case .clip(let name): clipError(code, name, detail)
            }
        }

        mutating func packError(_ code: ManifestIssueCode, _ detail: String) {
            issues.append(ManifestIssue(code: code, severity: .error, scope: .pack, detail: detail))
        }

        mutating func clipError(_ code: ManifestIssueCode, _ clip: String, _ detail: String) {
            issues.append(ManifestIssue(code: code, severity: .error, scope: .clip(clip), detail: detail))
            invalidClips.insert(clip)
        }

        mutating func warn(_ code: ManifestIssueCode, _ scope: ManifestIssueScope, _ detail: String) {
            issues.append(ManifestIssue(code: code, severity: .warning, scope: scope, detail: detail))
        }
    }
}
