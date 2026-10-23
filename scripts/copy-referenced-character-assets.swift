import Foundation

let fileManager = FileManager.default
guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: copy-referenced-character-assets.swift <source-root> <destination-root>")
}
let sourceRoot = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let destinationRoot = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)

func imagePaths(in value: Any) -> Set<String> {
    if let dictionary = value as? [String: Any] {
        var paths = Set<String>()
        for (key, child) in dictionary {
            if key == "image", let path = child as? String { paths.insert(path) }
            paths.formUnion(imagePaths(in: child))
        }
        return paths
    }
    if let array = value as? [Any] { return array.reduce(into: Set<String>()) { $0.formUnion(imagePaths(in: $1)) } }
    return []
}

let packs = try fileManager.contentsOfDirectory(at: sourceRoot, includingPropertiesForKeys: [.isDirectoryKey])
for sourcePack in packs {
    guard (try sourcePack.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true else { continue }
    let manifestURL = sourcePack.appending(path: "character.json")
    guard fileManager.fileExists(atPath: manifestURL.path) else { continue }
    let manifestData = try Data(contentsOf: manifestURL)
    let manifest = try JSONSerialization.jsonObject(with: manifestData)
    let paths = imagePaths(in: manifest)
    let destinationPack = destinationRoot.appending(path: sourcePack.lastPathComponent, directoryHint: .isDirectory)
    try fileManager.createDirectory(at: destinationPack, withIntermediateDirectories: true)
    try manifestData.write(to: destinationPack.appending(path: "character.json"), options: .atomic)

    for path in paths.sorted() {
        let components = path.split(separator: "/")
        guard !path.hasPrefix("/"), !components.isEmpty, !components.contains("."), !components.contains("..") else {
            fatalError("Unsafe asset path in \(manifestURL.path): \(path)")
        }
        let source = sourcePack.appending(path: path)
        guard fileManager.fileExists(atPath: source.path) else {
            fatalError("Referenced character asset is missing: \(source.path)")
        }
        let destination = destinationPack.appending(path: path)
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: source, to: destination)
    }
}
