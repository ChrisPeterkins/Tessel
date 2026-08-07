// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Tessel",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Tessel",
            path: "Sources/Tessel"
        ),
        .testTarget(
            name: "TesselTests",
            dependencies: ["Tessel"],
            path: "Tests/TesselTests"
        ),
    ]
)
