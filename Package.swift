// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Spk",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Spk", targets: ["Spk"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Spk",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/spk",
            exclude: ["Resources"]
        )
    ]
)
