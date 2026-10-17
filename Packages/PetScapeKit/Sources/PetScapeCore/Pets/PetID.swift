/// Identity of a pet in a `PetWorld` (assigned by the world, unique for its lifetime).
public struct PetID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    public var description: String { String(rawValue) }
}
