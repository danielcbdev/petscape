import Darwin
import Foundation
import PetScapeCore

struct CharacterPackStaging: Sendable {
    let name: String
    let url: URL
}

/// Confined pack I/O. Referenced files are opened relative to a no-follow directory descriptor.
enum CharacterPackFileSystem {
    static func readSnapshot(from folderURL: URL) async throws(CharacterPackImportError)
        -> CharacterPackSnapshot
    {
        try await readSnapshotOffActor(from: folderURL)
    }

    static func createStaging(_ pack: ValidatedCharacterPack, in rootURL: URL)
        async
        throws(CharacterPackImportError) -> CharacterPackStaging
    {
        try await createStagingOffActor(pack, in: rootURL)
    }

    static func promote(_ staging: CharacterPackStaging, id: String, in rootURL: URL)
        async
        throws(CharacterPackImportError)
    {
        try await promoteOffActor(staging, id: id, in: rootURL)
    }

    static func destinationExists(id: String, in rootURL: URL) async throws(CharacterPackImportError) -> Bool {
        try await destinationExistsOffActor(id: id, in: rootURL)
    }

    static func removeStaging(_ staging: CharacterPackStaging) async {
        await removeStagingOffActor(staging)
    }

    @concurrent
    nonisolated private static func readSnapshotOffActor(from folderURL: URL)
        async
        throws(CharacterPackImportError) -> CharacterPackSnapshot
    {
        let rootURL = folderURL.standardizedFileURL
        try inspectTree(at: rootURL)
        let rootDescriptor = try openDirectory(rootURL.path, create: false)
        defer { Darwin.close(rootDescriptor) }

        let manifestData = try readFile(
            "character.json", relativeTo: rootDescriptor,
            maximumBytes: CharacterPackPolicy.maximumManifestBytes)
        let paths = try CharacterPackPolicy.resourcePaths(in: manifestData)
        guard paths.count <= CharacterPackPolicy.maximumReferencedImageCount else { throw .resourceLimit }

        var images: [String: Data] = [:]
        var totalBytes = 0
        for path in paths {
            guard CharacterPackPolicy.isSafeResourcePath(path) else { throw .unsafePack }
            let data = try readFile(
                path, relativeTo: rootDescriptor, maximumBytes: CharacterPackPolicy.maximumImageFileBytes)
            let nextTotal = totalBytes.addingReportingOverflow(data.count)
            guard !nextTotal.overflow, nextTotal.partialValue <= CharacterPackPolicy.maximumReferencedBytes else {
                throw .resourceLimit
            }
            totalBytes = nextTotal.partialValue
            images[path] = data
        }
        return CharacterPackSnapshot(manifestData: manifestData, images: images)
    }

    @concurrent
    nonisolated private static func createStagingOffActor(
        _ pack: ValidatedCharacterPack, in rootURL: URL
    ) async throws(CharacterPackImportError) -> CharacterPackStaging {
        let rootDescriptor = try openDirectory(rootURL.standardizedFileURL.path, create: true)
        defer { Darwin.close(rootDescriptor) }

        let name = ".staging-\(UUID().uuidString.lowercased())"
        let madeDirectory = name.withCString { Darwin.mkdirat(rootDescriptor, $0, mode_t(0o700)) }
        guard madeDirectory == 0 else { throw .storageUnavailable }
        let staging = CharacterPackStaging(name: name, url: rootURL.appending(path: name, directoryHint: .isDirectory))

        do {
            let stagingDescriptor = name.withCString {
                Darwin.openat(
                    rootDescriptor, $0,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            }
            guard stagingDescriptor >= 0 else { throw CharacterPackImportError.storageUnavailable }
            defer { Darwin.close(stagingDescriptor) }

            try writeFile(pack.manifestData, as: "character.json", relativeTo: stagingDescriptor)
            for path in pack.images.keys.sorted() {
                guard let data = pack.images[path], CharacterPackPolicy.isSafeResourcePath(path) else {
                    throw CharacterPackImportError.unsafePack
                }
                try writeFile(data, as: path, relativeTo: stagingDescriptor)
            }
            guard Darwin.fsync(stagingDescriptor) == 0 else { throw CharacterPackImportError.installationFailed }
            return staging
        } catch let error as CharacterPackImportError {
            try? FileManager.default.removeItem(at: staging.url)
            throw error
        } catch {
            try? FileManager.default.removeItem(at: staging.url)
            throw .installationFailed
        }
    }

    @concurrent
    nonisolated private static func promoteOffActor(
        _ staging: CharacterPackStaging, id: String, in rootURL: URL
    ) async throws(CharacterPackImportError) {
        guard ManifestValidator.isValidIdentifier(id), id.utf8.count <= CharacterPackPolicy.maximumIDLength else {
            throw .invalidPack
        }
        let rootDescriptor = try openDirectory(rootURL.standardizedFileURL.path, create: false)
        defer { Darwin.close(rootDescriptor) }

        var existing = stat()
        let destinationExists = id.withCString {
            Darwin.fstatat(rootDescriptor, $0, &existing, AT_SYMLINK_NOFOLLOW)
        }
        if destinationExists == 0 { throw .duplicateInstalledID }
        guard errno == ENOENT else { throw .storageUnavailable }

        let result = staging.name.withCString { source in
            id.withCString { destination in
                Darwin.renameatx_np(rootDescriptor, source, rootDescriptor, destination, UInt32(RENAME_EXCL))
            }
        }
        guard result == 0 else {
            if errno == EEXIST { throw .duplicateInstalledID }
            throw .installationFailed
        }
        // Promotion is already visible and complete. Directory fsync is best-effort because reporting a
        // post-rename failure would falsely tell the caller that no installation occurred.
        _ = Darwin.fsync(rootDescriptor)
    }

    @concurrent
    nonisolated private static func destinationExistsOffActor(id: String, in rootURL: URL)
        async
        throws(CharacterPackImportError) -> Bool
    {
        let rootDescriptor = try openDirectory(rootURL.standardizedFileURL.path, create: false)
        defer { Darwin.close(rootDescriptor) }
        var existing = stat()
        let result = id.withCString {
            Darwin.fstatat(rootDescriptor, $0, &existing, AT_SYMLINK_NOFOLLOW)
        }
        if result == 0 { return true }
        guard errno == ENOENT else { throw .storageUnavailable }
        return false
    }

    @concurrent
    nonisolated private static func removeStagingOffActor(_ staging: CharacterPackStaging) async {
        try? FileManager.default.removeItem(at: staging.url)
    }

    nonisolated private static func inspectTree(at rootURL: URL) throws(CharacterPackImportError) {
        var rootInfo = stat()
        let rootStatus = rootURL.path.withCString { Darwin.lstat($0, &rootInfo) }
        guard rootStatus == 0, (rootInfo.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR) else {
            throw .unsafePack
        }

        guard let rootValues = try? rootURL.resourceValues(forKeys: [.isAliasFileKey]),
            rootValues.isAliasFile != true
        else { throw .unsafePack }

        guard
            let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isAliasFileKey],
                options: [])
        else { throw .unsafePack }

        var entryCount = 0
        var normalizedNames: [String: String] = [:]
        let rootComponents = rootURL.pathComponents
        while let entryURL = enumerator.nextObject() as? URL {
            entryCount += 1
            guard entryCount <= CharacterPackPolicy.maximumTreeEntries else { throw .resourceLimit }

            let entryComponents = entryURL.standardizedFileURL.pathComponents
            guard entryComponents.count > rootComponents.count else { throw .unsafePack }
            let relativeComponents = Array(entryComponents.dropFirst(rootComponents.count))
            guard relativeComponents.count <= CharacterPackPolicy.maximumTreeDepth else { throw .resourceLimit }
            let relativePath = relativeComponents.joined(separator: "/")
            let normalized = relativePath.precomposedStringWithCanonicalMapping.lowercased()
            if let existing = normalizedNames[normalized], existing != relativePath { throw .unsafePack }
            normalizedNames[normalized] = relativePath

            let values: URLResourceValues
            do {
                values = try entryURL.resourceValues(
                    forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isAliasFileKey])
            } catch {
                throw .unsafePack
            }
            if values.isSymbolicLink == true || values.isAliasFile == true {
                enumerator.skipDescendants()
                throw .unsafePack
            }
            if values.isDirectory == true { continue }
            guard values.isRegularFile == true else { throw .unsafePack }
            guard relativePath == "character.json" || entryURL.lastPathComponent != "character.json" else {
                throw .unsafePack
            }

            let attributes: [FileAttributeKey: Any]
            do {
                attributes = try FileManager.default.attributesOfItem(atPath: entryURL.path)
            } catch {
                throw .unsafePack
            }
            let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
            guard permissions & 0o111 == 0 else { throw .unsafePack }
            var fileInfo = stat()
            let status = entryURL.path.withCString { Darwin.lstat($0, &fileInfo) }
            guard status == 0,
                (fileInfo.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
                fileInfo.st_nlink <= 1
            else { throw .unsafePack }
        }
    }

    nonisolated private static func openDirectory(_ path: String, create: Bool) throws(CharacterPackImportError)
        -> Int32
    {
        // The temporary directory may be reached through macOS aliases such as /var -> /private/var.
        // Canonicalize existing ancestors, then open the requested leaf and any missing suffix with
        // O_NOFOLLOW. This preserves alias rejection for the selected pack/root itself.
        let canonical = try canonicalDirectoryPath(path)
        let components = canonical.split(separator: "/").map(String.init)
        let absoluteComponents = ["/"] + components
        var descriptor = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw .storageUnavailable }

        for component in absoluteComponents.dropFirst() {
            let next = component.withCString {
                Darwin.openat(descriptor, $0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            }
            if next >= 0 {
                Darwin.close(descriptor)
                descriptor = next
                continue
            }
            guard create, errno == ENOENT else {
                Darwin.close(descriptor)
                throw .storageUnavailable
            }
            let made = component.withCString { Darwin.mkdirat(descriptor, $0, mode_t(0o700)) }
            guard made == 0 || errno == EEXIST else {
                Darwin.close(descriptor)
                throw .storageUnavailable
            }
            let created = component.withCString {
                Darwin.openat(descriptor, $0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            }
            guard created >= 0 else {
                Darwin.close(descriptor)
                throw .storageUnavailable
            }
            Darwin.close(descriptor)
            descriptor = created
        }
        return descriptor
    }

    nonisolated private static func canonicalDirectoryPath(_ path: String) throws(CharacterPackImportError) -> String {
        let requested = URL(fileURLWithPath: path).standardizedFileURL
        var ancestor = requested.deletingLastPathComponent()
        var suffix = [requested.lastPathComponent]

        while true {
            var info = stat()
            let status = ancestor.path.withCString { Darwin.lstat($0, &info) }
            if status == 0 {
                var resolved = [CChar](repeating: 0, count: Int(PATH_MAX))
                let result = ancestor.path.withCString { Darwin.realpath($0, &resolved) }
                guard result != nil else { throw .storageUnavailable }
                let resolvedBytes = resolved.prefix { $0 != 0 }.map(UInt8.init(bitPattern:))
                var canonical = String(decoding: resolvedBytes, as: UTF8.self)
                for component in suffix {
                    if canonical != "/" { canonical += "/" }
                    canonical += component
                }
                return canonical
            }
            guard errno == ENOENT, ancestor.path != "/" else { throw .storageUnavailable }
            suffix.insert(ancestor.lastPathComponent, at: 0)
            ancestor.deleteLastPathComponent()
        }
    }

    nonisolated private static func readFile(
        _ relativePath: String, relativeTo rootDescriptor: Int32, maximumBytes: Int
    ) throws(CharacterPackImportError) -> Data {
        guard CharacterPackPolicy.isSafeResourcePath(relativePath) || relativePath == "character.json" else {
            throw .unsafePack
        }
        let components = relativePath.split(separator: "/").map(String.init)
        guard let lastComponent = components.last else { throw .unsafePack }
        var directoryDescriptor = Darwin.dup(rootDescriptor)
        guard directoryDescriptor >= 0 else { throw .unsafePack }
        defer { Darwin.close(directoryDescriptor) }

        for component in components.dropLast() {
            let next = component.withCString {
                Darwin.openat(
                    directoryDescriptor, $0,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            }
            guard next >= 0 else { throw .unsafePack }
            Darwin.close(directoryDescriptor)
            directoryDescriptor = next
        }

        let fileDescriptor = lastComponent.withCString {
            Darwin.openat(
                directoryDescriptor, $0,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        }
        guard fileDescriptor >= 0 else { throw errno == ENOENT ? .invalidPack : .unsafePack }
        defer { Darwin.close(fileDescriptor) }

        var before = stat()
        guard Darwin.fstat(fileDescriptor, &before) == 0,
            (before.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
            before.st_nlink <= 1, before.st_mode & mode_t(0o111) == 0,
            before.st_size >= 0
        else { throw .unsafePack }
        guard before.st_size <= off_t(maximumBytes) else { throw .resourceLimit }

        var data = Data()
        data.reserveCapacity(Int(before.st_size))
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = buffer.withUnsafeMutableBytes { bytes -> Int in
                guard let baseAddress = bytes.baseAddress else { return -1 }
                return Darwin.read(fileDescriptor, baseAddress, bytes.count)
            }
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw .unsafePack
            }
            let nextCount = data.count.addingReportingOverflow(count)
            guard !nextCount.overflow, nextCount.partialValue <= maximumBytes else { throw .resourceLimit }
            data.append(contentsOf: buffer.prefix(count))
        }

        var after = stat()
        guard Darwin.fstat(fileDescriptor, &after) == 0,
            before.st_dev == after.st_dev,
            before.st_ino == after.st_ino,
            before.st_size == after.st_size,
            before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
            before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
            data.count == Int(after.st_size)
        else { throw .unsafePack }
        return data
    }

    nonisolated private static func writeFile(
        _ data: Data, as relativePath: String, relativeTo rootDescriptor: Int32
    ) throws(CharacterPackImportError) {
        guard CharacterPackPolicy.isSafeResourcePath(relativePath) || relativePath == "character.json" else {
            throw .unsafePack
        }
        let components = relativePath.split(separator: "/").map(String.init)
        guard let fileName = components.last else { throw .unsafePack }
        var directoryDescriptor = Darwin.dup(rootDescriptor)
        guard directoryDescriptor >= 0 else { throw .installationFailed }
        defer { Darwin.close(directoryDescriptor) }

        for component in components.dropLast() {
            let created = component.withCString { Darwin.mkdirat(directoryDescriptor, $0, mode_t(0o700)) }
            guard created == 0 || errno == EEXIST else { throw .installationFailed }
            let next = component.withCString {
                Darwin.openat(
                    directoryDescriptor, $0,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            }
            guard next >= 0 else { throw .installationFailed }
            Darwin.close(directoryDescriptor)
            directoryDescriptor = next
        }

        let fileDescriptor = fileName.withCString {
            Darwin.openat(
                directoryDescriptor, $0,
                O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                mode_t(0o600))
        }
        guard fileDescriptor >= 0 else { throw .installationFailed }
        defer { Darwin.close(fileDescriptor) }

        var writeFailed = false
        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                writeFailed = !data.isEmpty
                return
            }
            var written = 0
            while written < bytes.count {
                let count = Darwin.write(fileDescriptor, baseAddress.advanced(by: written), bytes.count - written)
                if count < 0 {
                    if errno == EINTR { continue }
                    writeFailed = true
                    return
                }
                guard count > 0 else {
                    writeFailed = true
                    return
                }
                written += count
            }
        }
        guard !writeFailed else { throw .installationFailed }
        guard Darwin.fsync(fileDescriptor) == 0 else { throw .installationFailed }
    }
}
