import CoreGraphics
import Foundation

/// The current set of surfaces and the queries pets need (surface-detection.md). Updated with diffs keyed by
/// `SurfaceID`, so a moved surface keeps its identity and attached pets can follow it.
public struct SurfaceMap: Equatable, Sendable {
    /// Window motion above this speed is treated as a discontinuity and the pet lets go.
    /// The interval is bounded so a delayed snapshot cannot legitimize a teleport.
    public static let maximumWindowRideSpeed: CGFloat = 240
    public static let maximumWindowSampleGap: TimeInterval = 1.5
    /// One difference between two surface sets.
    public enum Change: Equatable, Sendable {
        case added(Surface)
        /// Same ID, different geometry or kind.
        case moved(Surface)
        case removed(SurfaceID)
    }

    /// In insertion order; swept contact resolves ties by kind and stable ID.
    public private(set) var surfaces: [Surface]

    public init(_ surfaces: [Surface] = []) {
        self.surfaces = []
        apply(Self.changes(from: [], to: surfaces))
    }

    public var isEmpty: Bool { surfaces.isEmpty }

    /// Pure screen-descriptor floor construction; Runtime chooses the hosted screen before calling it.
    public static func screenBottoms(for screens: [ScreenDescriptor]) -> [Surface] {
        var seen: Set<SurfaceID> = []
        return screens.compactMap { screen in
            let floor = Surface.screenBottom(of: screen)
            guard floor.isUsable, screen.frame.height.isFinite, screen.frame.height > 0,
                seen.insert(floor.id).inserted
            else { return nil }
            return floor
        }
    }

    /// Pure left/right wall construction from canonical global screen frames.
    public static func screenWalls(for screens: [ScreenDescriptor]) -> [Surface] {
        var seen: Set<SurfaceID> = []
        return screens.flatMap { screen in
            [Surface.screenLeft(of: screen), Surface.screenRight(of: screen)].filter { wall in
                wall.isUsable && screen.frame.width.isFinite && screen.frame.width > 0
                    && screen.frame.height.isFinite && screen.frame.height > 0
                    && seen.insert(wall.id).inserted
            }
        }
    }

    /// Returns window identities whose unchanged-size frames moved too far between snapshots.
    /// Distances are canonical global points and the decision is independent of collection order.
    public static func teleportedWindowIDs(
        from previous: [TrackedWindow], to current: [TrackedWindow], elapsed: TimeInterval
    ) -> Set<String> {
        guard elapsed.isFinite, elapsed > 0 else { return [] }
        var old: [UInt32: TrackedWindow] = [:]
        var new: [UInt32: TrackedWindow] = [:]
        for window in previous where old[window.id] == nil { old[window.id] = window }
        for window in current where new[window.id] == nil { new[window.id] = window }
        let limit = maximumWindowRideSpeed * CGFloat(min(elapsed, maximumWindowSampleGap))
        var moved: Set<String> = []
        for id in old.keys.sorted() {
            guard let before = old[id], let after = new[id], before.frame != after.frame else { continue }
            if elapsed > maximumWindowSampleGap {
                moved.insert("window:\(id)")
                continue
            }
            guard before.frame.size == after.frame.size else { continue }  // Timely resize is re-projected.
            let displacement = hypot(
                after.frame.minX - before.frame.minX, after.frame.minY - before.frame.minY)
            if displacement > limit {
                moved.insert("window:\(id)")
            }
        }
        return moved
    }

    public static func belongsToWindow(_ surface: Surface, identities: Set<String>) -> Bool {
        guard let identity = windowIdentity(for: surface.id) else { return false }
        return identities.contains(identity)
    }

    static func windowIdentity(for id: SurfaceID) -> String? {
        let parts = id.rawValue.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 4, parts[0] == "window",
            ["top", "left", "right"].contains(parts[2])
        else { return nil }
        return "\(parts[0]):\(parts[1])"
    }

    /// Swept one-way horizontal support, using x at impact rather than at the step endpoint.
    func firstLanding(
        from start: CGPoint, to end: CGPoint, geometry: ContactGeometry,
        visualRange: ClosedRange<CGFloat>, tolerance: CGFloat
    ) -> SurfaceContact? {
        guard start.x.isFinite, start.y.isFinite, end.x.isFinite, end.y.isFinite,
            start.y > end.y, tolerance.isFinite, tolerance > 0,
            visualRange.lowerBound.isFinite, visualRange.upperBound.isFinite
        else { return nil }
        let descent = start.y - end.y
        let horizontal = end.x - start.x
        guard descent.isFinite, horizontal.isFinite else { return nil }
        // Anchor the tolerance band to the highest eligible crossing, not the previous winner:
        // epsilon comparisons are not transitive. Two scans stay linear without temporary allocations.
        var highest = -CGFloat.infinity
        for surface in surfaces {
            if candidate(
                surface, start: start, descent: descent, horizontal: horizontal,
                geometry: geometry, visualRange: visualRange, tolerance: tolerance) != nil
            {
                highest = max(highest, surface.y)
            }
        }
        var best: SurfaceContact?
        var bestSurface: Surface?
        for surface in surfaces where surface.y >= highest - tolerance {
            guard
                let hit = candidate(
                    surface, start: start, descent: descent, horizontal: horizontal,
                    geometry: geometry, visualRange: visualRange, tolerance: tolerance)
            else { continue }
            if let previous = bestSurface {
                let preferred = surface.kind == .dockTop && previous.kind != .dockTop
                guard preferred || (surface.kind == previous.kind && surface.id.rawValue < previous.id.rawValue)
                else { continue }
            }
            best = hit
            bestSurface = surface
        }
        return best
    }

    private func candidate(
        _ surface: Surface, start: CGPoint, descent: CGFloat, horizontal: CGFloat,
        geometry: ContactGeometry, visualRange: ClosedRange<CGFloat>, tolerance: CGFloat
    ) -> SurfaceContact? {
        guard !surface.isVertical, surface.isUsable, start.y >= surface.y - tolerance,
            start.y - descent <= surface.y + tolerance
        else { return nil }
        let lower = max(surface.minX + geometry.halfWidth, visualRange.lowerBound)
        let upper = min(surface.maxX - geometry.halfWidth, visualRange.upperBound)
        guard lower <= upper else { return nil }
        let fraction = min(max((start.y - surface.y) / descent, 0), 1)
        let x = start.x + fraction * horizontal
        guard x.isFinite, x >= lower - tolerance, x <= upper + tolerance else { return nil }
        return SurfaceContact(
            surfaceID: surface.id, position: CGPoint(x: min(max(x, lower), upper), y: surface.y),
            fraction: fraction)
    }

    public func surface(_ id: SurfaceID) -> Surface? {
        surfaces.first { $0.id == id }
    }

    /// The changes that turn this map into `newSurfaces` (removals first, then moves and additions in the order
    /// of `newSurfaces`). A duplicate ID in `newSurfaces` keeps its first occurrence.
    public func changes(to newSurfaces: [Surface]) -> [Change] {
        Self.changes(from: surfaces, to: newSurfaces)
    }

    public mutating func apply(_ changes: [Change]) {
        for change in changes {
            switch change {
            case .added(let surface):
                guard self.surface(surface.id) == nil else { continue }
                surfaces.append(surface)
            case .moved(let surface):
                guard let index = surfaces.firstIndex(where: { $0.id == surface.id }) else { continue }
                surfaces[index] = surface
            case .removed(let id):
                surfaces.removeAll { $0.id == id }
            }
        }
    }

    /// The highest surface at or below `point` whose x range contains `point.x` (landing, spawn).
    public func highestWalkable(below point: CGPoint) -> Surface? {
        surfaces
            .filter { $0.y <= point.y && $0.minX <= point.x && point.x <= $0.maxX }
            .max { $0.y < $1.y }
    }

    /// Where a new or recovered pet appears: the Dock top when there is one, else the first screen bottom
    /// (pet-engine.md#lifecycle), else any surface.
    public var spawnSurface: Surface? {
        surfaces.first { $0.kind == .dockTop } ?? surfaces.first { $0.kind == .screenBottom } ?? surfaces.first
    }

    private static func changes(from old: [Surface], to new: [Surface]) -> [Change] {
        var seen: Set<SurfaceID> = []
        var result: [Change] = []
        let newIDs = Set(new.map(\.id))
        for surface in old where !newIDs.contains(surface.id) {
            result.append(.removed(surface.id))
        }
        for surface in new where seen.insert(surface.id).inserted {
            if let existing = old.first(where: { $0.id == surface.id }) {
                if existing != surface { result.append(.moved(surface)) }
            } else {
                result.append(.added(surface))
            }
        }
        return result
    }
}
