import Foundation

public enum CharacterPackLocations {
    public static func userCharactersRoot(applicationSupportDirectory: URL) -> URL {
        applicationSupportDirectory
            .appending(path: "PetScape", directoryHint: .isDirectory)
            .appending(path: "Characters", directoryHint: .isDirectory)
    }
}
