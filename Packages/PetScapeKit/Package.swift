// swift-tools-version: 6.2
// Module layout and dependency rules: docs/architecture/modules.md (ADR-0002).
// Isolation: Core stays nonisolated; the other targets default to MainActor (ADR-0012).

import PackageDescription

let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "PetScapeKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PetScapeCore", targets: ["PetScapeCore"]),
        .library(name: "PetScapePlatform", targets: ["PetScapePlatform"]),
        .library(name: "PetScapeRendering", targets: ["PetScapeRendering"]),
        .library(name: "PetScapeRuntime", targets: ["PetScapeRuntime"]),
    ],
    targets: [
        .target(name: "PetScapeCore"),
        .target(
            name: "PetScapePlatform",
            dependencies: ["PetScapeCore"],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "PetScapeRendering",
            dependencies: ["PetScapeCore"],
            swiftSettings: mainActorByDefault
        ),
        .target(
            name: "PetScapeRuntime",
            dependencies: ["PetScapeCore", "PetScapePlatform", "PetScapeRendering"],
            swiftSettings: mainActorByDefault
        ),
        .testTarget(name: "PetScapeCoreTests", dependencies: ["PetScapeCore"]),
        .testTarget(
            name: "PetScapePlatformTests",
            dependencies: ["PetScapePlatform"],
            swiftSettings: mainActorByDefault
        ),
        .testTarget(
            name: "PetScapeRenderingTests",
            dependencies: ["PetScapeRendering"],
            swiftSettings: mainActorByDefault
        ),
        .testTarget(
            name: "PetScapeRuntimeTests",
            dependencies: ["PetScapeRuntime"],
            swiftSettings: mainActorByDefault
        ),
    ],
    swiftLanguageModes: [.v6]
)
