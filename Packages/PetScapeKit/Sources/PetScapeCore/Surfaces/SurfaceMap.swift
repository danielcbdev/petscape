import CoreGraphics
import Foundation

/// The current set of surfaces and the queries pets need (surface-detection.md). Updated with diffs keyed by
/// `SurfaceID`, so a moved surface keeps its identity and attached pets can follow it.
public struct SurfaceMap: Equatable, Sendable {
    /// One difference between two surface sets.
    public enum Change: Equatable, Sendable {
        case added(Surface)
        /// Same ID, different geometry or kind.
        case moved(Surface)
        case removed(SurfaceID)
    }

    /// In insertion order (queries that tie pick the earliest).
    public private(set) var surfaces: [Surface]

    public init(_ surfaces: [Surface] = []) {
        self.surfaces = []
        apply(Self.changes(from: [], to: surfaces))
    }

    public var isEmpty: Bool { surfaces.isEmpty }

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
