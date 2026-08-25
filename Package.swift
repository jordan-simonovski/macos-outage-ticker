// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NewsTicker",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "TickerCore"),
        .executableTarget(name: "NewsTicker", dependencies: ["TickerCore"]),
        .testTarget(name: "TickerCoreTests", dependencies: ["TickerCore"]),
    ]
)
