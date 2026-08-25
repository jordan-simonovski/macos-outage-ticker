import Foundation
import TickerCore

func runOutageHistoryTests() {
    let now = Date(timeIntervalSince1970: 1_756_000_000)
    func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

    // Counts are scoped to site and window
    let history = OutageHistory(events: [
        OutageEvent(site: "GitHub", startedAt: daysAgo(1)),
        OutageEvent(site: "GitHub", startedAt: daysAgo(10)),
        OutageEvent(site: "GitHub", startedAt: daysAgo(45)),   // outside 30d window
        OutageEvent(site: "Claude", startedAt: daysAgo(2)),    // other site
    ])
    Check.equal(history.count(site: "GitHub", withinDays: 30, asOf: now), 2)
    Check.equal(history.count(site: "Claude", withinDays: 30, asOf: now), 1)
    Check.equal(history.count(site: "Atlassian", withinDays: 30, asOf: now), 0)

    // Recording appends
    let fresh = OutageHistory()
    fresh.record(site: "GitHub", at: now)
    Check.equal(fresh.count(site: "GitHub", withinDays: 30, asOf: now), 1)

    // Persistence round trip
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("history.json")
    let persisted = OutageHistory(fileURL: url)
    persisted.record(site: "GitHub", at: now)
    persisted.record(site: "Claude", at: daysAgo(3))
    Check.equal(OutageHistory.load(from: url).events, persisted.events)

    // Missing file loads empty
    let missing = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".json")
    Check.equal(OutageHistory.load(from: missing).events, [])
}
