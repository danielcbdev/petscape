import Foundation

/// The decoded `character.json` of a character pack (schema v1, docs/specifications/animation-schema.md).
///
/// This is the raw, unvalidated file content. `ManifestValidator` checks it and
/// `CharacterDefinition.resolve(_:report:)` turns it into the resolved runtime model. Fields whose absence
/// has a dedicated validation code (`defaultAnimation`, clip `frames`) are optional here so that the
/// validator, not the decoder, reports them.
public struct CharacterManifest: Codable, Equatable, Sendable {
    /// The only schema version this build understands.
    public static let supportedSchemaVersion = 1

    public var schemaVersion: Int
    public var id: String
    public var displayName: String
    public var defaultAnimation: String?
    public var defaultFacing: Facing?
    public var canvas: Size
    public var displaySize: Size
    public var anchor: Point
    public var fallbacks: [String: String]?
    public var sheets: [String: Sheet]?
    public var personality: Personality?
    public var animations: [String: Clip]

    public init(
        schemaVersion: Int = CharacterManifest.supportedSchemaVersion,
        id: String,
        displayName: String,
        defaultAnimation: String?,
        defaultFacing: Facing? = nil,
        canvas: Size,
        displaySize: Size,
        anchor: Point,
        fallbacks: [String: String]? = nil,
        sheets: [String: Sheet]? = nil,
        personality: Personality? = nil,
        animations: [String: Clip]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.defaultAnimation = defaultAnimation
        self.defaultFacing = defaultFacing
        self.canvas = canvas
        self.displaySize = displaySize
        self.anchor = anchor
        self.fallbacks = fallbacks
        self.sheets = sheets
        self.personality = personality
        self.animations = animations
    }

    /// Width and height. Pixels for `canvas`, points for `displaySize`.
    public struct Size: Codable, Equatable, Sendable {
        public var width: Double
        public var height: Double

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }

    /// Normalized point (0…1, origin bottom-left).
    public struct Point: Codable, Equatable, Sendable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    /// A sprite sheet of equal-size cells, row-major.
    public struct Sheet: Codable, Equatable, Sendable {
        public var image: String
        public var columns: Int
        public var rows: Int

        public init(image: String, columns: Int, rows: Int) {
            self.image = image
            self.columns = columns
            self.rows = rows
        }
    }

    /// Behavior defaults (used from M9).
    public struct Personality: Codable, Equatable, Sendable {
        public var curiosity: Double?
        public var playfulness: Double?
        public var laziness: Double?
        public var sociability: Double?
    }

    public enum Playback: String, Codable, Equatable, Sendable {
        case loop
        case once
        case pingPong
    }

    /// Which canvas side touches the surface.
    public enum Alignment: String, Codable, Equatable, Sendable {
        case bottom
        case left
        case right
        case top
    }

    public struct Clip: Codable, Equatable, Sendable {
        public var playback: Playback?
        public var fps: Double?
        public var frames: [Frame]?
        public var next: String?
        public var nominalSpeed: Double?
        public var facing: Facing?
        public var mirrorable: Bool?
        public var variants: [Facing: String]?
        public var anchor: Point?
        public var canvas: Size?
        public var alignment: Alignment?
        public var interruptible: Bool?

        public init(
            playback: Playback? = nil,
            fps: Double? = nil,
            frames: [Frame]?,
            next: String? = nil,
            nominalSpeed: Double? = nil,
            facing: Facing? = nil,
            mirrorable: Bool? = nil,
            variants: [Facing: String]? = nil,
            anchor: Point? = nil,
            canvas: Size? = nil,
            alignment: Alignment? = nil,
            interruptible: Bool? = nil
        ) {
            self.playback = playback
            self.fps = fps
            self.frames = frames
            self.next = next
            self.nominalSpeed = nominalSpeed
            self.facing = facing
            self.mirrorable = mirrorable
            self.variants = variants
            self.anchor = anchor
            self.canvas = canvas
            self.alignment = alignment
            self.interruptible = interruptible
        }
    }

    /// One frame: exactly one of `image` or `sheet` + `cell` (checked by the validator).
    public struct Frame: Codable, Equatable, Sendable {
        public var image: String?
        public var sheet: String?
        public var cell: Int?
        public var duration: Double?
        public var events: [String]?

        public init(
            image: String? = nil,
            sheet: String? = nil,
            cell: Int? = nil,
            duration: Double? = nil,
            events: [String]? = nil
        ) {
            self.image = image
            self.sheet = sheet
            self.cell = cell
            self.duration = duration
            self.events = events
        }
    }
}

// MARK: - Decoding

/// Why `character.json` could not be turned into a `CharacterManifest`.
public enum ManifestDecodingError: Error, Equatable, Sendable {
    /// Not valid JSON, or not a JSON object at the top level.
    case malformedJSON(String)
    /// Valid JSON whose shape does not match the schema (missing required field, wrong type, bad enum value).
    case schemaMismatch(String)
    /// `schemaVersion` is missing or not supported; nothing else is decoded (no partial loading).
    case unsupportedSchemaVersion(Int?)
}

/// A decoded manifest plus the JSON keys the schema does not know (warning `unknownField`).
public struct DecodedManifest: Equatable, Sendable {
    public var manifest: CharacterManifest
    /// Key paths such as `animations.walk.loopStart`, sorted.
    public var unknownFields: [String]

    public init(manifest: CharacterManifest, unknownFields: [String] = []) {
        self.manifest = manifest
        self.unknownFields = unknownFields
    }
}

extension CharacterManifest {
    /// Decodes `character.json` bytes. The schema version is checked first so that a newer, unsupported
    /// file is rejected as such rather than as a shape mismatch.
    public static func decode(_ data: Data) throws(ManifestDecodingError) -> DecodedManifest {
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw .malformedJSON(error.localizedDescription)
        }
        guard let object = parsed as? [String: Any] else {
            throw .malformedJSON("The top level is not a JSON object")
        }

        let version = object["schemaVersion"] as? Int
        guard version == supportedSchemaVersion else {
            throw .unsupportedSchemaVersion(version)
        }

        let manifest: CharacterManifest
        do {
            manifest = try JSONDecoder().decode(CharacterManifest.self, from: data)
        } catch let error as DecodingError {
            throw .schemaMismatch(Self.describe(error))
        } catch {
            throw .schemaMismatch(error.localizedDescription)
        }
        return DecodedManifest(manifest: manifest, unknownFields: UnknownFieldScanner.scan(object))
    }

    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            let joined = context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }
                .joined(separator: ".")
            return joined.isEmpty ? "<root>" : joined
        }
        switch error {
        case .keyNotFound(let key, let context):
            return "Missing field '\(key.stringValue)' at \(path(context))"
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            return "\(context.debugDescription) at \(path(context))"
        @unknown default:
            return error.localizedDescription
        }
    }
}

/// Finds JSON keys that are not part of schema v1 (forward compatibility: they are ignored, not errors).
enum UnknownFieldScanner {
    private static let topLevelKeys: Set<String> = [
        "schemaVersion", "id", "displayName", "defaultAnimation", "defaultFacing", "canvas", "displaySize",
        "anchor", "fallbacks", "sheets", "personality", "animations",
    ]
    private static let clipKeys: Set<String> = [
        "playback", "fps", "frames", "next", "nominalSpeed", "facing", "mirrorable", "variants", "anchor",
        "canvas", "alignment", "interruptible",
    ]
    private static let frameKeys: Set<String> = ["image", "sheet", "cell", "duration", "events"]
    private static let sheetKeys: Set<String> = ["image", "columns", "rows"]
    private static let sizeKeys: Set<String> = ["width", "height"]
    private static let pointKeys: Set<String> = ["x", "y"]
    private static let personalityKeys: Set<String> = ["curiosity", "playfulness", "laziness", "sociability"]

    static func scan(_ root: [String: Any]) -> [String] {
        var unknown: [String] = []
        check(root, allowed: topLevelKeys, path: "", into: &unknown)
        for key in ["canvas", "displaySize"] {
            check(root[key], allowed: sizeKeys, path: key, into: &unknown)
        }
        check(root["anchor"], allowed: pointKeys, path: "anchor", into: &unknown)
        check(root["personality"], allowed: personalityKeys, path: "personality", into: &unknown)
        if let sheets = root["sheets"] as? [String: Any] {
            for (name, sheet) in sheets {
                check(sheet, allowed: sheetKeys, path: "sheets.\(name)", into: &unknown)
            }
        }
        if let animations = root["animations"] as? [String: Any] {
            for (name, value) in animations {
                let clipPath = "animations.\(name)"
                check(value, allowed: clipKeys, path: clipPath, into: &unknown)
                guard let clip = value as? [String: Any] else { continue }
                check(clip["canvas"], allowed: sizeKeys, path: "\(clipPath).canvas", into: &unknown)
                check(clip["anchor"], allowed: pointKeys, path: "\(clipPath).anchor", into: &unknown)
                if let frames = clip["frames"] as? [Any] {
                    for (index, frame) in frames.enumerated() {
                        check(frame, allowed: frameKeys, path: "\(clipPath).frames.\(index)", into: &unknown)
                    }
                }
            }
        }
        return unknown.sorted()
    }

    private static func check(_ value: Any?, allowed: Set<String>, path: String, into unknown: inout [String]) {
        guard let object = value as? [String: Any] else { return }
        for key in object.keys where !allowed.contains(key) {
            unknown.append(path.isEmpty ? key : "\(path).\(key)")
        }
    }
}
