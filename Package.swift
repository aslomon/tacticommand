// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CreatorMicroControl",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CreatorMicroCore", targets: ["CreatorMicroCore"]),
        .executable(name: "CreatorMicroControl", targets: ["CreatorMicroControl"]),
    ],
    targets: [
        .target(
            name: "CreatorMicroCore",
            path: "Sources/CreatorMicroCore"
        ),
        .executableTarget(
            name: "CreatorMicroControl",
            dependencies: ["CreatorMicroCore"],
            path: "Sources/CreatorMicroControl"
        ),
        .testTarget(
            name: "CreatorMicroCoreTests",
            dependencies: ["CreatorMicroCore"],
            path: "Tests/CreatorMicroCoreTests",
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "CreatorMicroControlTests",
            dependencies: ["CreatorMicroControl"],
            path: "Tests/CreatorMicroControlTests"
        ),
    ]
)
