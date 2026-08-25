import XCTest
@testable import TickerCore

final class PollEngineTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_756_000_000)

    func payload(_ indicator: String, _ desc: String) -> Data {
        Data(#"{"status":{"indicator":"\#(indicator)","description":"\#(desc)"}}"#.utf8)
    }

    func makeEngine(history: OutageHistory = OutageHistory()) -> PollEngine {
        var config = Config.default
        config.sites = [
            SiteConfig(name: "GitHub", url: "https://www.githubstatus.com"),
            SiteConfig(name: "Claude", url: "https://status.claude.com"),
        ]
        config.tone = .snarky
        return PollEngine(config: config, history: history, pick: { _ in 0 })
    }

    func testAllHealthyReturnsNil() async {
        let engine = makeEngine()
        let text = await engine.poll(now: now) { _ in self.payload("none", "OK") }
        XCTAssertNil(text)
    }

    func testOutageProducesTickerTextAndRecordsHistory() async {
        let history = OutageHistory()
        let engine = makeEngine(history: history)
        let text = await engine.poll(now: now) { url in
            url.absoluteString.contains("githubstatus")
                ? self.payload("major", "Major Outage")
                : self.payload("none", "OK")
        }
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("GitHub"))
        XCTAssertEqual(history.count(site: "GitHub", withinDays: 30, asOf: now), 1)
    }

    func testOngoingOutageKeepsSameMessageAndRecordsOnce() async {
        let history = OutageHistory()
        let engine = makeEngine(history: history)
        let down: (URL) async throws -> Data = { _ in self.payload("major", "Outage") }
        let first = await engine.poll(now: now, fetch: down)
        let second = await engine.poll(now: now.addingTimeInterval(60), fetch: down)
        XCTAssertEqual(first, second)
        XCTAssertEqual(history.count(site: "GitHub", withinDays: 30, asOf: now.addingTimeInterval(60)), 1)
    }

    func testResolvedMessageShowsForOnePollThenHides() async {
        let engine = makeEngine()
        _ = await engine.poll(now: now) { url in
            url.absoluteString.contains("githubstatus")
                ? self.payload("major", "Outage")
                : self.payload("none", "OK")
        }
        let up: (URL) async throws -> Data = { _ in self.payload("none", "OK") }
        let resolvedText = await engine.poll(now: now.addingTimeInterval(60), fetch: up)
        XCTAssertNotNil(resolvedText)
        XCTAssertTrue(resolvedText!.contains("GitHub"))
        let after = await engine.poll(now: now.addingTimeInterval(120), fetch: up)
        XCTAssertNil(after)
    }

    func testTwoOutagesJoinedSorted() async {
        let engine = makeEngine()
        let text = await engine.poll(now: now) { _ in self.payload("minor", "Degraded") }
        XCTAssertTrue(text!.contains("  •  "))
        let claudeIndex = text!.range(of: "Claude")!.lowerBound
        let githubIndex = text!.range(of: "GitHub")!.lowerBound
        XCTAssertLessThan(claudeIndex, githubIndex)
    }

    func testFetchFailureLeavesStateUntouched() async {
        struct Boom: Error {}
        let engine = makeEngine()
        _ = await engine.poll(now: now) { _ in self.payload("major", "Outage") }
        let text = await engine.poll(now: now.addingTimeInterval(60)) { _ in throw Boom() }
        XCTAssertNotNil(text)  // outage message survives a failed poll
    }
}
