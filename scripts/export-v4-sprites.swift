// Development-only export of newly generated sprite sheets; never reads/writes original walk assets.
// Usage: swift scripts/export-v4-sprites.swift <source-directory> <new-output-directory>
// AI artwork is generated with image_gen. This tool performs deterministic pack export/registration.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ExportError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

struct Bounds {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int
    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
}

struct Body {
    let pixels: [Int]
    let bounds: Bounds
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else { throw ExportError("Expected source and new output directories") }
let sourceDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
let outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)
guard !FileManager.default.fileExists(atPath: outputDirectory.path) else {
    throw ExportError("Refusing to overwrite an existing export: \(outputDirectory.path)")
}
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { throw ExportError("sRGB unavailable") }
let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

func decode(_ url: URL) throws -> (pixels: [UInt8], width: Int, height: Int) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw ExportError("Cannot decode \(url.path)") }
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let success = pixels.withUnsafeMutableBytes { bytes -> Bool in
        guard
            let context = CGContext(
                data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo)
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard success else { throw ExportError("Cannot read pixels") }
    return (pixels, width, height)
}

func findBodies(_ pixels: [UInt8], width: Int, height: Int) -> [Body] {
    var visited = [Bool](repeating: false, count: width * height)
    var bodies: [Body] = []
    for start in visited.indices where !visited[start] && pixels[start * 4 + 3] >= 128 {
        var queue = [start]
        var indices: [Int] = []
        var bounds = Bounds(minX: width, minY: height, maxX: 0, maxY: 0)
        visited[start] = true
        while let index = queue.popLast() {
            indices.append(index)
            let x = index % width
            let y = index / width
            bounds.minX = min(bounds.minX, x); bounds.maxX = max(bounds.maxX, x)
            bounds.minY = min(bounds.minY, y); bounds.maxY = max(bounds.maxY, y)
            for ny in max(0, y - 1)...min(height - 1, y + 1) {
                for nx in max(0, x - 1)...min(width - 1, x + 1) {
                    let neighbor = ny * width + nx
                    if !visited[neighbor] && pixels[neighbor * 4 + 3] >= 128 {
                        visited[neighbor] = true
                        queue.append(neighbor)
                    }
                }
            }
        }
        if indices.count > 10_000 { bodies.append(Body(pixels: indices, bounds: bounds)) }
    }
    return bodies.sorted {
        let row0 = ($0.bounds.minY + $0.bounds.maxY) / 2 / (height / 2)
        let row1 = ($1.bounds.minY + $1.bounds.maxY) / 2 / (height / 2)
        return row0 == row1 ? $0.bounds.minX < $1.bounds.minX : row0 < row1
    }
}

func makeImage(_ pixels: inout [UInt8], width: Int, height: Int) throws -> CGImage {
    let image = pixels.withUnsafeMutableBytes { bytes -> CGImage? in
        CGContext(
            data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo)?.makeImage()
    }
    guard let image else { throw ExportError("Cannot create image") }
    return image
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw ExportError("Cannot create \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw ExportError("PNG export failed") }
}

// Near-paw contacts in the immutable walk_01 reference are x=166.5 and x=346.5.
// Register the root from anatomical contacts, never from the changing tail/body bounding box.
func contacts(_ pixels: [UInt8], width: Int, height: Int, bottom: Int, band: Int) throws -> (Double, Double, Double?) {
    var runs: [(Int, Int)] = []
    var start: Int?
    for x in 0...width {
        let solid = x < width && (max(0, bottom - band)...bottom).contains { pixels[($0 * width + x) * 4 + 3] >= 128 }
        if solid && start == nil { start = x }
        if !solid, let first = start {
            if let previous = runs.last, first - previous.1 <= max(8, band) {
                runs[runs.count - 1].1 = x - 1
            } else {
                runs.append((first, x - 1))
            }
            start = nil
        }
    }
    guard let rear = runs.first, let front = runs.last, runs.count >= 2 else {
        throw ExportError("Cannot identify both planted paw contacts")
    }
    let middle = runs.count == 3 ? Double(runs[1].0 + runs[1].1) / 2 : nil
    return (Double(rear.0 + rear.1) / 2, Double(front.0 + front.1) / 2, middle)
}

func registerPaws(_ input: [UInt8]) throws -> [UInt8] {
    let (rear, front, middle) = try contacts(input, width: 512, height: 512, bottom: 475, band: 6)
    let destinationX: [Double]
    let sourceX: [Double]
    if let middle {
        destinationX = [0, 136.5, 196.5, 215.5, 277.5, 286.5, 406.5, 511]
        sourceX = [0, rear - 30, rear + 30, middle - 31, middle + 31, front - 60, front + 60, 511]
    } else {
        destinationX = [0, 121.5, 211.5, 276.5, 416.5, 511]
        sourceX = [0, rear - 45, rear + 45, front - 70, front + 70, 511]
    }
    guard zip(sourceX, sourceX.dropFirst()).allSatisfy({ $0 < $1 }) else {
        throw ExportError("Paw correction would fold the image")
    }
    // Translate each paw intact at ground level; blend that correction into the ankle area.
    // Head/torso pixels above row 375 retain their registered source position and original scale.
    var output = input
    for y in 376..<512 {
        let t = min(1.0, Double(y - 375) / 85)
        let weight = t * t * (3 - 2 * t)
        for x in 0..<512 {
            let dx = Double(x)
            let lastSegment = destinationX.count - 2
            let segment = min(
                lastSegment,
                destinationX.dropFirst().firstIndex(where: { dx <= $0 }).map { $0 - 1 } ?? lastSegment)
            let local = (dx - destinationX[segment]) / (destinationX[segment + 1] - destinationX[segment])
            let corrected = sourceX[segment] + local * (sourceX[segment + 1] - sourceX[segment])
            let sx = min(511.0, max(0, dx + weight * (corrected - dx)))
            let lo = Int(sx); let hi = min(511, lo + 1); let fraction = sx - Double(lo)
            for c in 0..<4 {
                let a = Double(input[(y * 512 + lo) * 4 + c]); let b = Double(input[(y * 512 + hi) * 4 + c])
                output[(y * 512 + x) * 4 + c] = UInt8((a + (b - a) * fraction).rounded())
            }
        }
    }
    return output
}

var report: [[String: Any]] = []
for (name, expected) in [("idle", 6), ("jump-start", 4), ("jump", 4), ("fall", 6), ("landing", 4)] {
    let decoded = try decode(sourceDirectory.appending(path: "\(name).png"))
    let bodies = findBodies(decoded.pixels, width: decoded.width, height: decoded.height)
    guard bodies.count == expected else {
        throw ExportError("\(name): expected \(expected) bodies, found \(bodies.count)")
    }
    guard let largestWidth = bodies.map(\.bounds.width).max(), let largestHeight = bodies.map(\.bounds.height).max()
    else { throw ExportError("No bodies") }
    // One scale per clip, never per-frame auto-fit. Grounded poses register by the sole baseline;
    // airborne poses register by the stable ear/head top, removing sheet layout translation.
    let initialScale = min(470.0 / Double(largestWidth), 409.0 / Double(largestHeight))
    let airborne = name == "jump" || name == "fall"
    let targetRootX = airborne ? 412.0 : 256.5
    let roots: [Double] = try bodies.map { body in
        let b = body.bounds
        if airborne {
            let tips = body.pixels.filter { $0 / decoded.width < b.minY + 5 }.map { $0 % decoded.width }.sorted()
            guard !tips.isEmpty else { throw ExportError("Cannot identify ear landmark") }
            return Double(tips[tips.count / 2] - b.minX)
        }
        var projection = [UInt8](repeating: 0, count: b.width * 4)
        for index in body.pixels where index / decoded.width >= b.maxY - Int(ceil(6 / initialScale)) {
            projection[(index % decoded.width - b.minX) * 4 + 3] = 255
        }
        let pair = try contacts(projection, width: b.width, height: 1, bottom: 0, band: 0)
        return (pair.0 + pair.1) / 2
    }
    // Fit the whole clip once around the anatomical root. A pose never gets its own scale.
    let scale = zip(bodies, roots).reduce(initialScale) { value, item in
        let (body, root) = item
        return min(
            value, (targetRootX - 14) / max(1, root),
            (498 - targetRootX) / max(1, Double(body.bounds.width) - root))
    }
    let folder = outputDirectory.appending(path: "\(name)/frames", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for (number, body) in bodies.enumerated() {
        let b = body.bounds
        let pad = 4
        let width = b.width + pad * 2
        let height = b.height + pad * 2
        var keep = [Bool](repeating: false, count: width * height)
        // Keep the selected body and its original soft silhouette; exclude detached generator islands.
        for index in body.pixels {
            let x = index % decoded.width - b.minX + pad
            let y = index / decoded.width - b.minY + pad
            for ny in max(0, y - pad)...min(height - 1, y + pad) {
                for nx in max(0, x - pad)...min(width - 1, x + pad) { keep[ny * width + nx] = true }
            }
        }
        var isolated = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width where keep[y * width + x] {
                let sx = b.minX + x - pad; let sy = b.minY + y - pad
                guard sx >= 0, sx < decoded.width, sy >= 0, sy < decoded.height else { continue }
                let from = (sy * decoded.width + sx) * 4; let to = (y * width + x) * 4
                let alpha = Int(decoded.pixels[from + 3])
                guard alpha > 0 else { continue }
                let exportedAlpha = alpha >= 248 ? 255 : alpha
                for channel in 0..<3 {
                    isolated[to + channel] = UInt8(
                        min(255, Int(decoded.pixels[from + channel]) * exportedAlpha / alpha))
                }
                isolated[to + 3] = UInt8(exportedAlpha)
            }
        }
        let isolatedImage = try makeImage(&isolated, width: width, height: height)
        var exported = [UInt8](repeating: 0, count: 512 * 512 * 4)
        let targetWidth = Double(width) * scale
        let targetHeight = Double(height) * scale
        let rootX = roots[number] + Double(pad)
        let x = targetRootX - rootX * scale
        let solidTop = airborne ? 65.0 : 475 - Double(b.height) * scale
        let top = solidTop - Double(pad) * scale
        let success = exported.withUnsafeMutableBytes { bytes -> Bool in
            guard
                let context = CGContext(
                    data: bytes.baseAddress, width: 512, height: 512,
                    bitsPerComponent: 8, bytesPerRow: 512 * 4, space: colorSpace, bitmapInfo: bitmapInfo)
            else { return false }
            context.interpolationQuality = .high
            context.draw(
                isolatedImage,
                in: CGRect(
                    x: x, y: 512 - top - targetHeight,
                    width: targetWidth, height: targetHeight))
            return true
        }
        guard success else { throw ExportError("Frame registration failed") }
        if !airborne { exported = try registerPaws(exported) }
        for index in stride(from: 0, to: exported.count, by: 4) {
            let alpha = Int(exported[index + 3])
            if alpha >= 248 && alpha < 255 {
                for c in 0..<3 { exported[index + c] = UInt8(min(255, Int(exported[index + c]) * 255 / alpha)) }
                exported[index + 3] = 255
            }
        }
        let filename = String(format: "%@_%02d.png", name, number + 1)
        try writePNG(try makeImage(&exported, width: 512, height: 512), to: folder.appending(path: filename))
        report.append([
            "clip": name, "frame": number + 1, "sourceBounds": [b.minX, b.minY, b.maxX, b.maxY],
            "scale": scale, "registration": airborne ? "ear-412-top-65" : "anatomical-paws-166.5-346.5-row-474",
        ])
    }
}
let json = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputDirectory.appending(path: "export-report.json"))
print("Exported \(report.count) new 512×512 sRGB RGBA frames to \(outputDirectory.path)")
