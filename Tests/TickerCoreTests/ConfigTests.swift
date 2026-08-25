import Foundation
import TickerCore

private func tempFile() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("config.json")
}

func runConfigTests() {
    // Missing file returns default
    Check.equal(Config.load(from: tempFile()), Config.default)

    // Corrupt file returns default
    let corrupt = tempFile()
    try? FileManager.default.createDirectory(
        at: corrupt.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? Data("not json".utf8).write(to: corrupt)
    Check.equal(Config.load(from: corrupt), Config.default)

    // Save/load round trip
    let url = tempFile()
    var config = Config.default
    config.tone = .snarky
    config.edge = .top
    config.pollIntervalSeconds = 30
    do { try config.save(to: url) } catch { Check.isTrue(false, "save threw \(error)") }
    Check.equal(Config.load(from: url), config)

    // Default has the four launch sites
    Check.equal(Config.default.sites.map(\.name), ["GitHub", "ClickHouse", "Atlassian", "Claude"])
}
