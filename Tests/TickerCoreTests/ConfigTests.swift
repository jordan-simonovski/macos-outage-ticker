import XCTest
@testable import TickerCore

final class ConfigTests: XCTestCase {
    func tempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("config.json")
    }

    func testLoadMissingFileReturnsDefault() {
        XCTAssertEqual(Config.load(from: tempFile()), Config.default)
    }

    func testLoadCorruptFileReturnsDefault() throws {
        let url = tempFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        XCTAssertEqual(Config.load(from: url), Config.default)
    }

    func testSaveLoadRoundTrip() throws {
        let url = tempFile()
        var config = Config.default
        config.tone = .snarky
        config.edge = .top
        config.pollIntervalSeconds = 30
        try config.save(to: url)
        XCTAssertEqual(Config.load(from: url), config)
    }

    func testDefaultHasFourSites() {
        XCTAssertEqual(Config.default.sites.map(\.name), ["GitHub", "ClickHouse", "Atlassian", "Claude"])
    }
}
