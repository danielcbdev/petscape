import AppKit
import CoreGraphics
import PetScapeCore

/// Reads only window geometry and ordering. It deliberately never accesses window-name keys.
@MainActor
struct CGWindowSnapshotSource {
    init() {}

    func snapshot(
        converter: CoordinateConverter, ownPID: Int32 = Int32(ProcessInfo.processInfo.processIdentifier)
    ) -> [TrackedWindow] {
        guard
            let entries = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]]
        else { return [] }
        return windows(from: entries, converter: converter, ownPID: ownPID)
    }

    func windows(from entries: [[String: Any]], converter: CoordinateConverter, ownPID: Int32) -> [TrackedWindow] {
        return entries.enumerated().compactMap { index, entry in
            guard
                let number = entry[kCGWindowNumber as String] as? NSNumber,
                let pid = entry[kCGWindowOwnerPID as String] as? NSNumber,
                let layer = entry[kCGWindowLayer as String] as? NSNumber,
                let alpha = entry[kCGWindowAlpha as String] as? NSNumber,
                let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
                pid.int32Value != ownPID, layer.intValue == 0, alpha.doubleValue > 0,
                let quartzRect = CGRect(dictionaryRepresentation: bounds as CFDictionary), isUsable(quartzRect)
            else { return nil }
            let frame = converter.globalRect(
                fromQuartz: QuartzRect(
                    x: quartzRect.origin.x, y: quartzRect.origin.y,
                    width: quartzRect.width, height: quartzRect.height))
            guard isUsable(frame), frame.width >= 40, frame.height >= 24,
                converter.screens.contains(where: { $0.frame.intersects(frame) })
            else { return nil }
            return TrackedWindow(
                id: number.uint32Value, ownerPID: pid.int32Value, frame: frame, zIndex: index)
        }
    }

    private func isUsable(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite && rect.width.isFinite && rect.height.isFinite
            && rect.width > 0 && rect.height > 0 && rect.maxX.isFinite && rect.maxY.isFinite
    }
}
