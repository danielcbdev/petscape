/// Provisional M8 jump envelope and phase times, all in points or simulated seconds (jump-system.md).
struct JumpTuning: Equatable, Sendable {
    let preferredApexHeight: Double = 80
    let maxApexRise: Double = 120
    let maxHorizontalDisplacement: Double = 80
    let maxHorizontalSpeed: Double = 160
    let preparationDuration: Double = 0.15
    let landingDuration: Double = 0.10
    let cooldown: Double = 2
    let maxFlightDuration: Double = 2
    let targetTolerance: Double = 1
    let clearance: Double = 4
}
