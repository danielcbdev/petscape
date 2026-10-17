import CoreGraphics

/// A frame ready to display: the decoded image for `PetLayer.contents` and its hit mask.
nonisolated public struct FrameImage: Sendable {
    public let image: CGImage
    public let hitMask: HitMask

    public init(image: CGImage, hitMask: HitMask) {
        self.image = image
        self.hitMask = hitMask
    }

    /// Builds the hit mask from `image`; `nil` if the mask cannot be built.
    public init?(image: CGImage) {
        guard let mask = HitMask(image: image) else { return nil }
        self.init(image: image, hitMask: mask)
    }
}
