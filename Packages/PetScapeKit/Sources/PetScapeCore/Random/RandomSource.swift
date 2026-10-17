/// Randomness injected into the simulation so tests are deterministic (testing.md#determinism).
/// Production uses `SystemRandomNumberGenerator`; tests use `SeededRandomSource`.
public protocol RandomSource: RandomNumberGenerator, Sendable {}

extension SystemRandomNumberGenerator: RandomSource {}
