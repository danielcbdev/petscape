import AppKit
import PetScapeCore
import QuartzCore

/// Draws `RenderSnapshot`s into an overlay: one `PetLayer` per `PetID` under a host layer whose coordinates are
/// overlay-local (data-flow.md: rendering only displays snapshots; it keeps layers and nothing else).
public final class PetRenderer {
    private let hostLayer: CALayer
    private var layers: [PetID: PetLayer] = [:]

    public init(hostLayer: CALayer) {
        self.hostLayer = hostLayer
    }

    /// The layer showing a pet, if it was rendered (tests, debugging).
    public func layer(for id: PetID) -> PetLayer? { layers[id] }

    /// Applies `snapshot` to the overlay of `screen`: global contact points become overlay-local through
    /// `converter`, `image` supplies each pet's current frame.
    public func render(
        _ snapshot: RenderSnapshot,
        converter: CoordinateConverter,
        screen: ScreenDescriptor,
        image: (PetRenderState) -> CGImage?
    ) {
        Signposts.measure(Signposts.Interval.render) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if layers.count != snapshot.pets.count { removeLayers(notIn: snapshot) }
            for pet in snapshot.pets {
                let petLayer = layers[pet.id] ?? addLayer(for: pet.id)
                petLayer.apply(
                    pet, overlayPosition: converter.overlayPoint(fromGlobal: pet.position, on: screen),
                    image: image(pet))
            }
            CATransaction.commit()
        }
    }

    public func removeAll() {
        for petLayer in layers.values { petLayer.layer.removeFromSuperlayer() }
        layers.removeAll()
    }

    private func addLayer(for id: PetID) -> PetLayer {
        let petLayer = PetLayer()
        hostLayer.addSublayer(petLayer.layer)
        layers[id] = petLayer
        return petLayer
    }

    private func removeLayers(notIn snapshot: RenderSnapshot) {
        let ids = Set(snapshot.pets.map(\.id))
        for (id, petLayer) in layers where !ids.contains(id) {
            petLayer.layer.removeFromSuperlayer()
            layers[id] = nil
        }
    }
}
