/// Finite runtime traits derived from the optional, unchanged manifest personality DTO.
public struct Personality: Equatable, Sendable {
    public let curiosity: Double
    public let playfulness: Double
    public let laziness: Double
    public let sociability: Double

    public init(curiosity: Double = 0.5, playfulness: Double = 0.5, laziness: Double = 0.5, sociability: Double = 0.5) {
        func trait(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0.5 }
        self.curiosity = trait(curiosity)
        self.playfulness = trait(playfulness)
        self.laziness = trait(laziness)
        self.sociability = trait(sociability)
    }

    public init(_ manifest: CharacterManifest.Personality?) {
        self.init(
            curiosity: manifest?.curiosity ?? 0.5, playfulness: manifest?.playfulness ?? 0.5,
            laziness: manifest?.laziness ?? 0.5, sociability: manifest?.sociability ?? 0.5)
    }
}
