import Foundation

/// Identity of a display for the current login session: the `CGDirectDisplayID` (`NSScreenNumber`).
/// Stable while the app runs, not across reboots — never persist it as the only key
/// (macos-integration.md#multiple-monitors-retina-scaling).
public struct ScreenID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public var description: String { String(rawValue) }
}
