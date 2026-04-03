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
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "spk",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/spk",
            exclude: ["Resources"]
        )
    ]
)
