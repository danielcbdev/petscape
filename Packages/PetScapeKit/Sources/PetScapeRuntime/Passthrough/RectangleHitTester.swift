import CoreGraphics

/// Hit tester for a plain rectangle: the M3 DEBUG test target standing in for the pet, and "no pet"
/// (`rect == nil`) until pets exist (M5).
public final class RectangleHitTester: PetHitTesting {
    /// Canonical global rect; max edges exclusive.
    public var rect: CGRect?

    public init(rect: CGRect? = nil) {
        self.rect = rect
    }

    public func containsPet(at globalPoint: CGPoint) -> Bool {
        rect?.contains(globalPoint) ?? false
    }
}
