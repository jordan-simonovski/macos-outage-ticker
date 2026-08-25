import Foundation
import TickerCore

private let now = Date(timeIntervalSince1970: 1_756_000_000)

private func payload(_ indicator: String, _ desc: String) -> Data {
    Data(#"{"status":{"indicator":"\#(indicator)","description":"\#(desc)"}}"#.utf8)
}

private func makeEngine(history: OutageHistory = OutageHistory()) -> PollEngine {
    var config = Config.default
    config.sites = [
        SiteConfig(name: "GitHub", url: "https://www.githubstatus.com"),
        SiteConfig(name: "Claude", url: "https://status.claude.com"),
    ]
    config.tone = .snarky
    return PollEngine(config: config, history: history, pick: { _ in 0 })
}

func runPollEngineTests() async {
    // All healthy hides the ticker
    Check.isNil(await makeEngine().poll(now: now) { _ in payload("none", "OK") })

    // An outage produces text and records history
    let history = OutageHistory()
    let text = await makeEngine(history: history).poll(now: now) { url in
        url.absoluteString.contains("githubstatus")
            ? payload("major", "Major Outage")
            : payload("none", "OK")
    }
    Check.notNil(text)
    Check.isTrue(text?.contains("GitHub") ?? false, "expected GitHub in \(text ?? "nil")")
    Check.equal(history.count(site: "GitHub", withinDays: 30, asOf: now), 1)

    // An ongoing outage keeps one message and records once
    let ongoingHistory = OutageHistory()
    let ongoing = makeEngine(history: ongoingHistory)
    let down: (URL) async throws -> Data = { _ in payload("major", "Outage") }
    let firstPoll = await ongoing.poll(now: now, fetch: down)
    let secondPoll = await ongoing.poll(now: now.addingTimeInterval(60), fetch: down)
    Check.equal(firstPoll, secondPoll)
    Check.equal(ongoingHistory.count(site: "GitHub", withinDays: 30, asOf: now.addingTimeInterval(60)), 1)

    // A resolved message shows for exactly one more poll, then hides
    let resolving = makeEngine()
    _ = await resolving.poll(now: now) { url in
        url.absoluteString.contains("githubstatus")
            ? payload("major", "Outage")
            : payload("none", "OK")
    }
    let up: (URL) async throws -> Data = { _ in payload("none", "OK") }
    let resolvedText = await resolving.poll(now: now.addingTimeInterval(60), fetch: up)
    Check.notNil(resolvedText)
    Check.isTrue(resolvedText?.contains("GitHub") ?? false)
    Check.isNil(await resolving.poll(now: now.addingTimeInterval(120), fetch: up))

    // Two simultaneous outages are joined, sorted by site name
    let both = await makeEngine().poll(now: now) { _ in payload("minor", "Degraded") }
    Check.isTrue(both?.contains("  •  ") ?? false, "expected separator in \(both ?? "nil")")
    if let both, let claude = both.range(of: "Claude"), let github = both.range(of: "GitHub") {
        Check.isTrue(claude.lowerBound < github.lowerBound, "expected Claude before GitHub")
    } else {
        Check.isTrue(false, "expected both sites in \(both ?? "nil")")
    }

    // A failed fetch leaves the previous state untouched
    struct Boom: Error {}
    let flaky = makeEngine()
    _ = await flaky.poll(now: now) { _ in payload("major", "Outage") }
    Check.notNil(await flaky.poll(now: now.addingTimeInterval(60)) { _ in throw Boom() })
}
