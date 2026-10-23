/// Stable candidate order is part of seeded replay; physical execution remains in PetWorld.
public enum Activity: String, CaseIterable, Hashable, Sendable {
    case walk, idle, jump, sit, sleep, stretch, observe, explore, windowExcursion

    var duration: ClosedRange<Double> {
        switch self {
        case .walk: 8...16
        case .idle: 2...5
        case .jump, .windowExcursion: 0...0
        case .sit: 8...15
        case .sleep: 30...60
        case .stretch: 1.5...1.5
        case .observe: 3...5
        case .explore: 6...10
        }
    }

    var cooldown: Double {
        switch self {
        case .jump: 8
        case .windowExcursion: 30
        case .sleep, .stretch: 20
        default: 0
        }
    }
}
