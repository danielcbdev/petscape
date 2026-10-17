import CoreGraphics
import PetScapeCore

/// Answers which pet, if any, has opaque pixels under a global point, using each frame's `HitMask` with the
/// pet's mirroring and size from the last snapshot (T5.8, coordinate-system.md: global → mask cell).
public final class PetHitTester {
    private struct Entry {
        var id: PetID
        var spriteRect: CGRect
        var isMirrored: Bool
        var mask: HitMask
    }

    /// Back to front (the last entry is drawn on top).
    private var entries: [Entry] = []

    public init() {}

    /// Takes the visible pets of `snapshot`; `mask` supplies the hit mask of each pet's current frame (pets
    /// without one cannot be hit). Reuses its storage, so updating per frame does not allocate once warm.
    public func update(_ snapshot: RenderSnapshot, mask: (PetRenderState) -> HitMask?) {
        entries.removeAll(keepingCapacity: true)
        for pet in snapshot.pets where pet.isVisible {
            guard let hitMask = mask(pet) else { continue }
            entries.append(Entry(id: pet.id, spriteRect: pet.spriteRect, isMirrored: pet.frame.mirrored, mask: hitMask))
        }
    }

    public func removeAll() {
        entries.removeAll()
    }

    /// The topmost pet whose mask is set under `globalPoint`.
    public func petID(at globalPoint: CGPoint) -> PetID? {
        for entry in entries.reversed() {
            guard
                let cell = CoordinateConverter.maskCell(
                    at: globalPoint, spriteRect: entry.spriteRect, isMirrored: entry.isMirrored,
                    columns: entry.mask.width, rows: entry.mask.height)
            else { continue }
            if entry.mask.isSet(column: cell.column, row: cell.row) { return entry.id }
        }
        return nil
    }

    public func containsPet(at globalPoint: CGPoint) -> Bool {
        petID(at: globalPoint) != nil
    }
}
