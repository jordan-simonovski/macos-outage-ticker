// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NewsTicker",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "TickerCore"),
        .executableTarget(name: "NewsTicker", dependencies: ["TickerCore"]),
        // No Xcode on this machine means no XCTest module, so the suite is a
        // plain executable of asserts. Run it with `swift run TickerCoreTests`.
        .executableTarget(name: "TickerCoreTests", dependencies: ["TickerCore"],
                          path: "Tests/TickerCoreTests"),
    ]
)
