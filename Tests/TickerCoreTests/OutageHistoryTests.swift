import XCTest
@testable import TickerCore

final class OutageHistoryTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_756_000_000)

    func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

    func testCountWithinWindow() {
        let history = OutageHistory(events: [
            OutageEvent(site: "GitHub", startedAt: daysAgo(1)),
            OutageEvent(site: "GitHub", startedAt: daysAgo(10)),
            OutageEvent(site: "GitHub", startedAt: daysAgo(45)),   // outside 30d window
            OutageEvent(site: "Claude", startedAt: daysAgo(2)),    // other site
        ])
        XCTAssertEqual(history.count(site: "GitHub", withinDays: 30, asOf: now), 2)
        XCTAssertEqual(history.count(site: "Claude", withinDays: 30, asOf: now), 1)
        XCTAssertEqual(history.count(site: "Atlassian", withinDays: 30, asOf: now), 0)
    }

    func testRecordAppends() {
        let history = OutageHistory()
        history.record(site: "GitHub", at: now)
        XCTAssertEqual(history.count(site: "GitHub", withinDays: 30, asOf: now), 1)
    }

    func testPersistenceRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let history = OutageHistory(fileURL: url)
        history.record(site: "GitHub", at: now)
        history.record(site: "Claude", at: daysAgo(3))

        let reloaded = OutageHistory.load(from: url)
        XCTAssertEqual(reloaded.events, history.events)
    }

    func testLoadMissingFileIsEmpty() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        XCTAssertEqual(OutageHistory.load(from: url).events, [])
    }
}
