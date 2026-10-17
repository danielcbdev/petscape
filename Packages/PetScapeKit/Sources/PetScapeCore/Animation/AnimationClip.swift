/// An immutable, validated clip with every default applied (docs/architecture/animation-system.md).
///
/// Built by `CharacterDefinition.resolve(_:report:)`; never constructed from unvalidated data.
public struct AnimationClip: Equatable, Sendable {
    public typealias Playback = CharacterManifest.Playback
    public typealias Alignment = CharacterManifest.Alignment
    public typealias Point = CharacterManifest.Point
    public typealias Size = CharacterManifest.Size

    /// A sprite sheet of `columns` × `rows` equal cells (row-major).
    public struct Sheet: Hashable, Sendable {
        public var image: String
        public var columns: Int
        public var rows: Int

        public init(image: String, columns: Int, rows: Int) {
            self.image = image
            self.columns = columns
            self.rows = rows
        }
    }

    /// Where a frame's pixels come from; paths are relative to the pack folder.
    public enum FrameSource: Hashable, Sendable {
        case image(String)
        case sheetCell(Sheet, cell: Int)

        /// The image file to decode for this source.
        public var imagePath: String {
            switch self {
            case .image(let path): path
            case .sheetCell(let sheet, _): sheet.image
            }
        }
    }

    public struct Frame: Equatable, Sendable {
        public var source: FrameSource
        /// Seconds at rate 1 (the frame's own `duration`, else `1 / fps`).
        public var duration: Double
        /// Declared event names, emitted when the frame is entered.
        public var events: [String]

        public init(source: FrameSource, duration: Double, events: [String] = []) {
            self.source = source
            self.duration = duration
            self.events = events
        }
    }

    public var name: String
    public var playback: Playback
    public var frames: [Frame]
    /// Resolved clip to play after a `once` clip finishes (always a playable clip name).
    public var next: String?
    /// Ground speed matching the art, in points per second at user scale 1.0.
    public var nominalSpeed: Double?
    public var facing: Facing
    public var mirrorable: Bool
    /// Resolved dedicated clips per direction.
    public var variants: [Facing: String]
    /// Contact point in normalized canvas space (origin bottom-left).
    public var anchor: Point
    /// Canvas size in pixels.
    public var canvas: Size
    public var alignment: Alignment
    public var interruptible: Bool

    public init(
        name: String,
        playback: Playback = .loop,
        frames: [Frame],
        next: String? = nil,
        nominalSpeed: Double? = nil,
        facing: Facing = .right,
        mirrorable: Bool = true,
        variants: [Facing: String] = [:],
        anchor: Point = Point(x: 0.5, y: 0),
        canvas: Size = Size(width: 512, height: 512),
        alignment: Alignment = .bottom,
        interruptible: Bool = true
    ) {
        precondition(!frames.isEmpty, "AnimationClip '\(name)' needs at least one frame")
        self.name = name
        self.playback = playback
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

    /// Sum of the frame durations at rate 1 (one pass; a `pingPong` round trip is longer).
    public var duration: Double {
        frames.reduce(0) { $0 + $1.duration }
    }
}
