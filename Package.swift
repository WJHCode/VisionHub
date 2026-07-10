// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VisionHub",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "VisionHubCore",
            targets: ["VisionHubCore"]
        )
    ],
    targets: [
        .target(
            name: "VisionHubCore",
            path: "Sources/VisionHubCore"
        ),
        .testTarget(
            name: "VisionHubCoreTests",
            dependencies: ["VisionHubCore"],
            path: "Tests/VisionHubCoreTests"
        )
    ]
)
