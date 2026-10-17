import CoreGraphics

/// Answers whether a global point is over a pet's opaque pixels (alpha mask in M5, `PetHitTester`).
public protocol PetHitTesting: AnyObject {
    func containsPet(at globalPoint: CGPoint) -> Bool
}
