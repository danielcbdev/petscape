import CoreGraphics
import Foundation

/// Privacy-minimal window geometry passed from Platform to Core. Never contains titles or content.
public struct TrackedWindow: Equatable, Sendable {
    public var id: UInt32
    public var ownerPID: Int32
    public var frame: CGRect
    /// CGWindowList order: zero is frontmost.
    public var zIndex: Int
    public var isMinimized: Bool

    public init(id: UInt32, ownerPID: Int32, frame: CGRect, zIndex: Int, isMinimized: Bool = false) {
        self.id = id
        self.ownerPID = ownerPID
        self.frame = frame
        self.zIndex = zIndex
        self.isMinimized = isMinimized
    }
}
