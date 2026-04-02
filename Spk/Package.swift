// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "spk",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "spk", targets: ["spk"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "spk",
            dependencies: [],
            path: "Sources/spk",
            exclude: ["Resources"]
        )
    ]
)
