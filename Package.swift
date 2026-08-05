// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "status-lens",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "StatusLensCore"
        ),
        .executableTarget(
            name: "status-lens",
            dependencies: ["StatusLensCore"],
            resources: []
        ),
        .testTarget(
            name: "StatusLensCoreTests",
            dependencies: ["StatusLensCore"]
        ),
    ]
)
