/// Follows a manifest's `fallbacks` map (clip → clip) to a playable clip.
///
/// Shared by `ManifestValidator` (cycle detection, default clip) and `CharacterDefinition` (resolution table),
/// so both apply exactly the same rules.
enum FallbackResolver {
    /// Every cycle in `fallbacks`, each listed once, starting at its alphabetically smallest name.
    static func cycles(in fallbacks: [String: String]) -> [[String]] {
        var found: Set<[String]> = []
        for start in fallbacks.keys {
            var path: [String] = []
            var current = start
            while let target = fallbacks[current] {
                path.append(current)
                if let index = path.firstIndex(of: target) {
                    found.insert(normalized(Array(path[index...])))
                    break
                }
                current = target
            }
        }
        return found.sorted { $0.joined(separator: ">") < $1.joined(separator: ">") }
    }

    /// Returns `name` if it is playable, otherwise follows `fallbacks` until a playable clip is found.
    /// Returns `nil` when the chain ends without one or loops (callers then use the default clip).
    static func resolve(_ name: String, fallbacks: [String: String], isPlayable: (String) -> Bool) -> String? {
        var visited: Set<String> = []
        var current = name
        while visited.insert(current).inserted {
            if isPlayable(current) { return current }
            guard let target = fallbacks[current] else { return nil }
            current = target
        }
        return nil
    }

    private static func normalized(_ cycle: [String]) -> [String] {
        guard let smallest = cycle.indices.min(by: { cycle[$0] < cycle[$1] }) else { return cycle }
        return Array(cycle[smallest...] + cycle[..<smallest])
    }
}
