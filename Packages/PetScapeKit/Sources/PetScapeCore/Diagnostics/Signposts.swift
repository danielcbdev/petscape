import os

/// `OSSignposter` helpers (category `performance`). Names match docs/development/debugging.md#signposts;
/// inspect them in Instruments › os_signpost / Points of Interest.
public enum Signposts {
    public static let signposter = OSSignposter(logger: Log.performance)

    /// Interval names.
    public enum Interval {
        public static let frame: StaticString = "frame"
        public static let simulationStep: StaticString = "simulationStep"
        public static let render: StaticString = "render"
        public static let passthroughUpdate: StaticString = "passthroughUpdate"
        public static let characterLoad: StaticString = "characterLoad"
        public static let imageDecode: StaticString = "imageDecode"
    }

    /// Point-event names.
    public enum Event {
        public static let runStateChanged: StaticString = "runStateChanged"
        public static let surfaceChanged: StaticString = "surfaceChanged"
    }

    /// Wraps `body` in a signpost interval and returns its result. Cheap when no tool is recording.
    @inlinable
    public static func measure<Result>(_ name: StaticString, _ body: () throws -> Result) rethrows -> Result {
        try signposter.withIntervalSignpost(name, id: signposter.makeSignpostID(), around: body)
    }

    /// Emits a point event.
    @inlinable
    public static func event(_ name: StaticString) {
        signposter.emitEvent(name, id: signposter.makeSignpostID())
    }
}
