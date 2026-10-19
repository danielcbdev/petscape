import CoreGraphics

/// Pose-independent logical support width and height, relative to the pet's virtual foot anchor.
/// Derived from manifest display size in points, never image alpha, tail extent or backing pixels.
struct ContactGeometry: Equatable, Sendable {
    private static let widthFraction = 0.5
    private static let heightFraction = 0.625

    let halfWidth: CGFloat
    let height: CGFloat

    init?(displaySize: CGSize, scale: Double) {
        guard displaySize.width.isFinite, displaySize.width > 0,
            displaySize.height.isFinite, displaySize.height > 0,
            scale.isFinite, scale > 0
        else { return nil }

        let scaledWidth = displaySize.width * CGFloat(scale)
        let scaledHeight = displaySize.height * CGFloat(scale)
        let halfWidth = scaledWidth * Self.widthFraction / 2
        let height = scaledHeight * Self.heightFraction
        guard scaledWidth.isFinite, scaledHeight.isFinite,
            halfWidth.isFinite, halfWidth > 0, height.isFinite, height > 0
        else { return nil }

        self.halfWidth = halfWidth
        self.height = height
    }
}
