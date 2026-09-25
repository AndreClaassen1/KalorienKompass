// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "kk",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "kk",
            path: "Sources/kk"
        ),
        .testTarget(
            name: "kkTests",
            dependencies: ["kk"],
            path: "Tests/kkTests"
        )
    ]
)
