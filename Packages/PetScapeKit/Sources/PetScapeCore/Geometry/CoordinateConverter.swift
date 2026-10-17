import CoreGraphics
import Foundation

/// The only place where coordinate spaces are converted (coordinate-system.md, ADR-0008).
///
/// Built from a `[ScreenDescriptor]` snapshot and rebuilt whenever the screens change. All conversions
/// depend on the **primary** screen's height `H`, never on the tallest or the key window's screen.
public struct CoordinateConverter: Equatable, Sendable {
    public let screens: [ScreenDescriptor]
    /// The screen at the global origin.
    public let primary: ScreenDescriptor

    /// Returns `nil` when there are no screens (nothing can be converted or displayed).
    /// The primary screen is the one flagged `isPrimary`, or the first one if none is flagged.
    public init?(screens: [ScreenDescriptor]) {
        guard let primary = screens.first(where: \.isPrimary) ?? screens.first else { return nil }
        self.screens = screens
        self.primary = primary
    }

    /// `H`: height of the primary screen frame.
    public var primaryHeight: CGFloat { primary.frame.height }

    /// Largest backing scale among connected screens; frame textures are sized for it.
    public var maximumBackingScale: Double { screens.map(\.backingScale).max() ?? 1 }

    public func screen(withID id: ScreenID) -> ScreenDescriptor? {
        screens.first { $0.id == id }
    }

    /// The screen whose frame contains `point` (min edges inclusive, max edges exclusive).
    public func screen(containing point: CGPoint) -> ScreenDescriptor? {
        screens.first { $0.frame.contains(point) }
    }

    // MARK: Quartz ↔ global

    public func globalPoint(fromQuartz point: QuartzPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    public func globalRect(fromQuartz rect: QuartzRect) -> CGRect {
        CGRect(
            x: rect.origin.x, y: primaryHeight - rect.origin.y - rect.size.height,
            width: rect.size.width, height: rect.size.height)
    }

    public func quartzPoint(fromGlobal point: CGPoint) -> QuartzPoint {
        QuartzPoint(x: point.x, y: primaryHeight - point.y)
    }

    public func quartzRect(fromGlobal rect: CGRect) -> QuartzRect {
        QuartzRect(x: rect.minX, y: primaryHeight - rect.minY - rect.height, width: rect.width, height: rect.height)
    }

    // MARK: Global ↔ overlay-local

    /// Overlay-local coordinates of `screen`'s overlay (panel origin = screen origin, y up).
    public func overlayPoint(fromGlobal point: CGPoint, on screen: ScreenDescriptor) -> CGPoint {
        CGPoint(x: point.x - screen.frame.minX, y: point.y - screen.frame.minY)
    }

    public func globalPoint(fromOverlay overlayPoint: CGPoint, on screen: ScreenDescriptor) -> CGPoint {
        CGPoint(x: overlayPoint.x + screen.frame.minX, y: overlayPoint.y + screen.frame.minY)
    }

    public func overlayRect(fromGlobal rect: CGRect, on screen: ScreenDescriptor) -> CGRect {
        CGRect(origin: overlayPoint(fromGlobal: rect.origin, on: screen), size: rect.size)
    }

    // MARK: Points → pixels

    /// Pixel size of a texture shown at `pointSize` on any connected screen.
    public func pixelSize(forPointSize pointSize: CGSize) -> CGSize {
        let scale = CGFloat(maximumBackingScale)
        return CGSize(width: (pointSize.width * scale).rounded(), height: (pointSize.height * scale).rounded())
    }

    // MARK: Global → hit-mask cell

    /// The cell of a `columns × rows` alpha mask (row 0 = top, as in `CGImage` rows) under `point`, for a
    /// sprite drawn into `spriteRect` (global); `isMirrored` flips the image horizontally inside that rect.
    /// Returns `nil` outside the rect (max edges exclusive) or for an empty mask.
    public static func maskCell(
        at point: CGPoint, spriteRect: CGRect, isMirrored: Bool, columns: Int, rows: Int
    ) -> MaskCell? {
        guard columns > 0, rows > 0, spriteRect.width > 0, spriteRect.height > 0 else { return nil }
        var u = (point.x - spriteRect.minX) / spriteRect.width
        let v = (point.y - spriteRect.minY) / spriteRect.height
        guard u >= 0, u < 1, v >= 0, v < 1 else { return nil }
        if isMirrored { u = 1 - u }
        let column = min(Int(u * CGFloat(columns)), columns - 1)
        let row = min(Int((1 - v) * CGFloat(rows)), rows - 1)
        return MaskCell(column: column, row: row)
    }
}

/// Column/row of an alpha hit mask (texture space: row 0 is the top row of the image).
public struct MaskCell: Equatable, Sendable {
    public var column: Int
    public var row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }
}
