# macOS Outage News Ticker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A hidden menu-bar macOS app that polls Statuspage-based status pages and, on an outage, fires a scrolling breaking-news ticker across the top or bottom of the screen with configurable snark/hugops tone that escalates with outage frequency.

**Architecture:** Two-target Swift package: `TickerCore` (pure logic — config, Statuspage parsing, outage state machine, history, message composition, poll engine — fully unit-tested, no AppKit) and `NewsTicker` (thin AppKit executable — borderless overlay window with a Core Animation marquee, `NSStatusItem` menu, poll timer). All side effects (network fetch, clock, random pick) are injected so the core is deterministic under test.

**Tech Stack:** Swift 5.9+, Swift Package Manager, AppKit + Core Animation, XCTest. **Zero external dependencies.**

**Spec:** Inline — see "Requirements" below. There is no separate spec document; this section is the spec.

## Requirements

- Native macOS app, hidden by default: no Dock icon, no window. Only an `NSStatusItem` in the menu bar and, during an outage, the ticker.
- Polls configured status pages. All four launch targets (githubstatus.com, status.clickhouse.com, status.atlassian.com, status.claude.com) are Atlassian Statuspage instances; each serves `GET <base>/api/v2/status.json` returning `{"status": {"indicator": "none|minor|major|critical|maintenance", "description": "..."}}`. **Verified 2026-08-25 against all four sites.**
- An outage is `indicator` ∈ {minor, major, critical}. `none`, `maintenance`, and unknown values are not outages.
- On outage start: show a full-screen-width scrolling ticker at the configured edge (top/bottom). On resolve: show a "resolved" message for one poll interval, then hide. No outages → ticker fully hidden.
- Message tone is configurable: `hugops`, `balanced`, `snarky`.
- Messages escalate by outage frequency: count of outages for that site within a configurable window (default 30 days) selects a tier — fresh / repeat-offender / not-even-news (e.g. "GitHub is down again? This isn't even news.").
- Config is a user-editable JSON file at `~/Library/Application Support/NewsTicker/config.json`; outage history persists next to it. Menu items: Test Ticker, Open Config, Reload Config, Quit.
- Purpose is novelty/comedy. Simplicity beats robustness everywhere except: never crash on bad network data, never lose the outage history file to a partial write.

## Execution status (2026-08-25)

**All 11 tasks are implemented and committed on `build/news-ticker`.**

**The XCTest blocker was resolved by taking this plan's own documented fallback**, not by
installing Xcode. `Tests/TickerCoreTests` is now an `.executableTarget` running a
dependency-free assert harness (`Tests/TickerCoreTests/Harness.swift`).

    swift build                 # builds
    swift run TickerCoreTests   # 78 checks, all passing
    swift run                   # the app

To move back to XCTest once Xcode is installed: change the `TickerCoreTests`
`.executableTarget` in `Package.swift` back to a `.testTarget`, delete
`Harness.swift` and `Tests/TickerCoreTests/main.swift`, and rewrite each
`runXTests()` function as an `XCTestCase`. Every API under test is `public`,
so no `@testable` is needed either way.

**Manual verification was done without a screen.** `screencapture` returns
"could not create image from display" because the terminal lacks Screen Recording
permission, so Tasks 8 and 9 are verified by `NEWSTICKER_SELFTEST=1 swift run`,
which prints window geometry, menu item enabled-state and config paths, then exits.
A human should still eyeball the scrolling bar once.

**Two defects found and fixed during execution, beyond what the plan specified:**

1. `TickerController.debugDescription` (a verification hook added in Task 8) resolved to
   `Optional.debugDescription` when called through the implicitly-unwrapped `ticker!`,
   printing `Optional(NewsTicker.TickerController)`. Renamed to `geometry`.
2. Task 9's `pollOnce` called `ticker.show(text)` on every poll. During an ongoing outage
   the text is unchanged, so the marquee restarted from off-screen every poll interval —
   the message would never finish scrolling on a long outage. `pollOnce` now only acts
   when the text changes, and `reload()` clears that cache.

**Pre-flight fix already applied:** Task 9 originally set `AppDelegate` as the target for
every menu item including Quit, whose action is `NSApplication.terminate(_:)`. AppDelegate
does not implement that selector, so AppKit's auto-enabling would have greyed Quit out and
left the app unquittable from its own menu. Quit now keeps a nil target so the responder
chain reaches NSApp. Verified: the self-test forces `menu.update()` and reports
`Quit enabled=true target=responderChain`.

## Global Constraints

- macOS 13+ (`platforms: [.macOS(.v13)]`), Swift tools version 5.9.
- No external dependencies — SPM targets only, no `.xcodeproj`.
- Build/test/run only via `swift build`, `swift test`, `swift run`.
- No AI/Claude attribution footers in commit messages (user's global rule).
- All `TickerCore` code must compile without importing AppKit.
- Fixed copy rules: ticker text separator between simultaneous outages is `"  •  "`; ticker text is wrapped as `"  +++ <message> +++  "`.

## File Structure

```
Package.swift
Sources/TickerCore/Config.swift          # Codable config + JSON load/save
Sources/TickerCore/StatusPage.swift      # Indicator enum + status.json parser
Sources/TickerCore/OutageMonitor.swift   # per-site up/down transition detection
Sources/TickerCore/OutageHistory.swift   # persisted outage events + windowed counts
Sources/TickerCore/MessageComposer.swift # tone × tier template tables + fill-in
Sources/TickerCore/PollEngine.swift      # one poll pass: fetch → transitions → ticker text
Sources/NewsTicker/TickerController.swift# overlay NSWindow + CA marquee (UI, untested)
Sources/NewsTicker/main.swift            # NSApplication bootstrap, AppDelegate, menu, timer
Tests/TickerCoreTests/ConfigTests.swift
Tests/TickerCoreTests/StatusPageTests.swift
Tests/TickerCoreTests/OutageMonitorTests.swift
Tests/TickerCoreTests/OutageHistoryTests.swift
Tests/TickerCoreTests/MessageComposerTests.swift
Tests/TickerCoreTests/PollEngineTests.swift
scripts/mock-status-server.py           # local fake Statuspage cycling up/down fast
scripts/mock-config.json                # config pointing the app at the mock server
README.md
```

---

### Task 1: Project scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/TickerCore/Config.swift` (placeholder), `Sources/NewsTicker/main.swift` (placeholder), `Tests/TickerCoreTests/ConfigTests.swift` (placeholder)

**Interfaces:**
- Consumes: nothing.
- Produces: a building, testing SPM package with targets `TickerCore` (library), `NewsTicker` (executable, depends on TickerCore), `TickerCoreTests`.

- [x] **Step 1: Initialize git**

```bash
cd /Users/jordanclickhouse/dev/macos-news-ticker
git init
printf '.build/\n.DS_Store\n' > .gitignore
```

- [x] **Step 2: Write Package.swift**

```swift
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
```

- [x] **Step 3: Write placeholder sources so targets compile**

`Sources/TickerCore/Config.swift`:
```swift
// Replaced with the real Config in Task 2.
public enum TickerCore {}
```

`Sources/NewsTicker/main.swift`:
```swift
import TickerCore
print("NewsTicker placeholder")
```

`Tests/TickerCoreTests/ConfigTests.swift`:
```swift
import XCTest
@testable import TickerCore

final class ConfigTests: XCTestCase {
    func testScaffold() { XCTAssertTrue(true) }
}
```

- [x] **Step 4: Verify build and tests**

Run: `swift build && swift test`
Expected: build succeeds, 1 test passes.

- [x] **Step 5: Sanity-check the status endpoints (no code change)**

Run:
```bash
curl -sS https://www.githubstatus.com/api/v2/status.json | head -c 200
```
Expected: JSON containing `"status":{"indicator":...,"description":...}`. (All four sites were verified on 2026-08-25; this is a canary in case of API drift.)

- [x] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: scaffold SPM package with TickerCore and NewsTicker targets"
```

---

### Task 2: Config

**Files:**
- Modify: `Sources/TickerCore/Config.swift` (replace placeholder)
- Test: `Tests/TickerCoreTests/ConfigTests.swift` (replace placeholder)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `public enum Tone: String, Codable, CaseIterable { case hugops, balanced, snarky }`
  - `public enum Edge: String, Codable { case top, bottom }`
  - `public struct SiteConfig: Codable, Equatable { public var name: String; public var url: String }`
  - `public struct Config: Codable, Equatable` with fields `sites: [SiteConfig]`, `pollIntervalSeconds: Double`, `tone: Tone`, `edge: Edge`, `historyWindowDays: Int`, `repeatOffenderThreshold: Int`, `notNewsThreshold: Int`, `scrollPointsPerSecond: Double`; plus `static let `default``, `static func load(from url: URL) -> Config`, `func save(to url: URL) throws`.

- [x] **Step 1: Write the failing tests**

Replace `Tests/TickerCoreTests/ConfigTests.swift`:
```swift
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
```

- [x] **Step 2: Run tests to verify they fail**

Run: `swift test`
Expected: FAIL — `Config` not defined.

- [x] **Step 3: Write the implementation**

Replace `Sources/TickerCore/Config.swift`:
```swift
import Foundation

public enum Tone: String, Codable, CaseIterable {
    case hugops, balanced, snarky
}

public enum Edge: String, Codable {
    case top, bottom
}

public struct SiteConfig: Codable, Equatable {
    public var name: String
    public var url: String

    public init(name: String, url: String) {
        self.name = name
        self.url = url
    }
}

public struct Config: Codable, Equatable {
    public var sites: [SiteConfig]
    public var pollIntervalSeconds: Double
    public var tone: Tone
    public var edge: Edge
    public var historyWindowDays: Int
    public var repeatOffenderThreshold: Int
    public var notNewsThreshold: Int
    public var scrollPointsPerSecond: Double

    public static let `default` = Config(
        sites: [
            SiteConfig(name: "GitHub", url: "https://www.githubstatus.com"),
            SiteConfig(name: "ClickHouse", url: "https://status.clickhouse.com"),
            SiteConfig(name: "Atlassian", url: "https://status.atlassian.com"),
            SiteConfig(name: "Claude", url: "https://status.claude.com"),
        ],
        pollIntervalSeconds: 60,
        tone: .balanced,
        edge: .bottom,
        historyWindowDays: 30,
        repeatOffenderThreshold: 2,
        notNewsThreshold: 5,
        scrollPointsPerSecond: 120
    )

    public init(sites: [SiteConfig], pollIntervalSeconds: Double, tone: Tone, edge: Edge,
                historyWindowDays: Int, repeatOffenderThreshold: Int, notNewsThreshold: Int,
                scrollPointsPerSecond: Double) {
        self.sites = sites
        self.pollIntervalSeconds = pollIntervalSeconds
        self.tone = tone
        self.edge = edge
        self.historyWindowDays = historyWindowDays
        self.repeatOffenderThreshold = repeatOffenderThreshold
        self.notNewsThreshold = notNewsThreshold
        self.scrollPointsPerSecond = scrollPointsPerSecond
    }

    // ponytail: bad config falls back to defaults silently; log-and-warn if users get confused
    public static func load(from url: URL) -> Config {
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(Config.self, from: data)
        else { return .default }
        return config
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
```

- [x] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: PASS (all Config tests).

- [x] **Step 5: Commit**

```bash
git add Sources/TickerCore/Config.swift Tests/TickerCoreTests/ConfigTests.swift
git commit -m "feat: JSON config with sites, tone, edge, thresholds"
```

---

### Task 3: Statuspage parsing

**Files:**
- Create: `Sources/TickerCore/StatusPage.swift`
- Test: `Tests/TickerCoreTests/StatusPageTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `public enum Indicator: String, Codable, Equatable { case none, minor, major, critical, maintenance, unknown }` (unknown raw values decode to `.unknown`, never throw)
  - `public struct ServiceStatus: Equatable { public let indicator: Indicator; public let description: String }`
  - `public enum StatusPage { public static func parse(_ data: Data) throws -> ServiceStatus }`

- [x] **Step 1: Write the failing tests**

Create `Tests/TickerCoreTests/StatusPageTests.swift`:
```swift
import XCTest
@testable import TickerCore

final class StatusPageTests: XCTestCase {
    func testParsesHealthyPayload() throws {
        let json = #"{"page":{"id":"kctbh9vrtdwd","name":"GitHub","url":"https://www.githubstatus.com","updated_at":"2026-08-25T00:00:00Z"},"status":{"indicator":"none","description":"All Systems Operational"}}"#
        let status = try StatusPage.parse(Data(json.utf8))
        XCTAssertEqual(status, ServiceStatus(indicator: .none, description: "All Systems Operational"))
    }

    func testParsesOutagePayload() throws {
        let json = #"{"status":{"indicator":"major","description":"Partial System Outage"}}"#
        let status = try StatusPage.parse(Data(json.utf8))
        XCTAssertEqual(status.indicator, .major)
    }

    func testUnknownIndicatorDecodesAsUnknown() throws {
        let json = #"{"status":{"indicator":"weird_new_value","description":"?"}}"#
        let status = try StatusPage.parse(Data(json.utf8))
        XCTAssertEqual(status.indicator, .unknown)
    }

    func testGarbageDataThrows() {
        XCTAssertThrowsError(try StatusPage.parse(Data("<html>".utf8)))
    }
}
```

- [x] **Step 2: Run tests to verify they fail**

Run: `swift test --filter StatusPageTests`
Expected: FAIL — `StatusPage` not defined.

- [x] **Step 3: Write the implementation**

Create `Sources/TickerCore/StatusPage.swift`:
```swift
import Foundation

public enum Indicator: String, Codable, Equatable {
    case none, minor, major, critical, maintenance, unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Indicator(rawValue: raw) ?? .unknown
    }
}

public struct ServiceStatus: Equatable {
    public let indicator: Indicator
    public let description: String

    public init(indicator: Indicator, description: String) {
        self.indicator = indicator
        self.description = description
    }
}

public enum StatusPage {
    private struct Payload: Decodable {
        struct Status: Decodable {
            let indicator: Indicator
            let description: String
        }
        let status: Status
    }

    public static func parse(_ data: Data) throws -> ServiceStatus {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return ServiceStatus(indicator: payload.status.indicator,
                             description: payload.status.description)
    }
}
```

- [x] **Step 4: Run tests to verify they pass**

Run: `swift test --filter StatusPageTests`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add Sources/TickerCore/StatusPage.swift Tests/TickerCoreTests/StatusPageTests.swift
git commit -m "feat: parse Statuspage v2 status.json"
```

---

### Task 4: Outage transition detection

**Files:**
- Create: `Sources/TickerCore/OutageMonitor.swift`
- Test: `Tests/TickerCoreTests/OutageMonitorTests.swift`

**Interfaces:**
- Consumes: `Indicator` from Task 3.
- Produces:
  - `public final class OutageMonitor` with `public enum Transition: Equatable { case began, ended, none }` and `public func observe(site: String, indicator: Indicator) -> OutageMonitor.Transition`
  - `public static func isOutage(_ indicator: Indicator) -> Bool` (true for minor/major/critical only)

- [x] **Step 1: Write the failing tests**

Create `Tests/TickerCoreTests/OutageMonitorTests.swift`:
```swift
import XCTest
@testable import TickerCore

final class OutageMonitorTests: XCTestCase {
    func testUpToDownIsBegan() {
        let m = OutageMonitor()
        XCTAssertEqual(m.observe(site: "GitHub", indicator: .none), .none)
        XCTAssertEqual(m.observe(site: "GitHub", indicator: .major), .began)
    }

    func testFirstObservationDownIsBegan() {
        // App launched mid-outage: still fire the ticker.
        let m = OutageMonitor()
        XCTAssertEqual(m.observe(site: "GitHub", indicator: .critical), .began)
    }

    func testDownStaysDownIsNone() {
        let m = OutageMonitor()
        _ = m.observe(site: "GitHub", indicator: .major)
        XCTAssertEqual(m.observe(site: "GitHub", indicator: .minor), .none)
    }

    func testDownToUpIsEnded() {
        let m = OutageMonitor()
        _ = m.observe(site: "GitHub", indicator: .major)
        XCTAssertEqual(m.observe(site: "GitHub", indicator: .none), .ended)
    }

    func testSitesAreIndependent() {
        let m = OutageMonitor()
        _ = m.observe(site: "GitHub", indicator: .major)
        XCTAssertEqual(m.observe(site: "Claude", indicator: .minor), .began)
    }

    func testMaintenanceAndUnknownAreNotOutages() {
        XCTAssertFalse(OutageMonitor.isOutage(.maintenance))
        XCTAssertFalse(OutageMonitor.isOutage(.unknown))
        XCTAssertFalse(OutageMonitor.isOutage(.none))
        XCTAssertTrue(OutageMonitor.isOutage(.minor))
        XCTAssertTrue(OutageMonitor.isOutage(.major))
        XCTAssertTrue(OutageMonitor.isOutage(.critical))
    }
}
```

- [x] **Step 2: Run tests to verify they fail**

Run: `swift test --filter OutageMonitorTests`
Expected: FAIL — `OutageMonitor` not defined.

- [x] **Step 3: Write the implementation**

Create `Sources/TickerCore/OutageMonitor.swift`:
```swift
import Foundation

public final class OutageMonitor {
    public enum Transition: Equatable {
        case began, ended, none
    }

    private var lastIndicator: [String: Indicator] = [:]

    public init() {}

    public static func isOutage(_ indicator: Indicator) -> Bool {
        indicator == .minor || indicator == .major || indicator == .critical
    }

    public func observe(site: String, indicator: Indicator) -> Transition {
        let wasDown = lastIndicator[site].map(Self.isOutage) ?? false
        let isDown = Self.isOutage(indicator)
        lastIndicator[site] = indicator
        if !wasDown && isDown { return .began }
        if wasDown && !isDown { return .ended }
        return .none
    }
}
```

- [x] **Step 4: Run tests to verify they pass**

Run: `swift test --filter OutageMonitorTests`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add Sources/TickerCore/OutageMonitor.swift Tests/TickerCoreTests/OutageMonitorTests.swift
git commit -m "feat: per-site outage transition detection"
```

---

### Task 5: Outage history

**Files:**
- Create: `Sources/TickerCore/OutageHistory.swift`
- Test: `Tests/TickerCoreTests/OutageHistoryTests.swift`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces:
  - `public struct OutageEvent: Codable, Equatable { public let site: String; public let startedAt: Date }`
  - `public final class OutageHistory` with `init(events: [OutageEvent] = [], fileURL: URL? = nil)`, `static func load(from url: URL) -> OutageHistory`, `func record(site: String, at date: Date)` (appends and saves if `fileURL` set), `func count(site: String, withinDays days: Int, asOf now: Date) -> Int`, `private(set) var events: [OutageEvent]`.

- [x] **Step 1: Write the failing tests**

Create `Tests/TickerCoreTests/OutageHistoryTests.swift`:
```swift
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
```

- [x] **Step 2: Run tests to verify they fail**

Run: `swift test --filter OutageHistoryTests`
Expected: FAIL — `OutageHistory` not defined.

- [x] **Step 3: Write the implementation**

Create `Sources/TickerCore/OutageHistory.swift`:
```swift
import Foundation

public struct OutageEvent: Codable, Equatable {
    public let site: String
    public let startedAt: Date

    public init(site: String, startedAt: Date) {
        self.site = site
        self.startedAt = startedAt
    }
}

public final class OutageHistory {
    public private(set) var events: [OutageEvent]
    private let fileURL: URL?

    public init(events: [OutageEvent] = [], fileURL: URL? = nil) {
        self.events = events
        self.fileURL = fileURL
    }

    public static func load(from url: URL) -> OutageHistory {
        guard let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([OutageEvent].self, from: data)
        else { return OutageHistory(fileURL: url) }
        return OutageHistory(events: events, fileURL: url)
    }

    public func record(site: String, at date: Date) {
        events.append(OutageEvent(site: site, startedAt: date))
        // Prune anything older than a year so the file never grows unbounded.
        let cutoff = date.addingTimeInterval(-365 * 86_400)
        events.removeAll { $0.startedAt < cutoff }
        save()
    }

    public func count(site: String, withinDays days: Int, asOf now: Date) -> Int {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        return events.filter { $0.site == site && $0.startedAt >= cutoff }.count
    }

    private func save() {
        guard let fileURL else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(events).write(to: fileURL, options: .atomic)
    }
}
```

- [x] **Step 4: Run tests to verify they pass**

Run: `swift test --filter OutageHistoryTests`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add Sources/TickerCore/OutageHistory.swift Tests/TickerCoreTests/OutageHistoryTests.swift
git commit -m "feat: persisted outage history with windowed counts"
```

---

### Task 6: Message composer

**Files:**
- Create: `Sources/TickerCore/MessageComposer.swift`
- Test: `Tests/TickerCoreTests/MessageComposerTests.swift`

**Interfaces:**
- Consumes: `Tone` and `Config` from Task 2.
- Produces:
  - `public enum Tier: Equatable { case fresh, repeatOffender, notEvenNews; public static func forCount(_ count: Int, config: Config) -> Tier }` — `count` includes the outage that just started (record first, then count).
  - `public enum MessageComposer` with:
    - `public static func breakingNews(site: String, description: String, tier: Tier, tone: Tone, pick: (Int) -> Int = { Int.random(in: 0..<$0) }) -> String`
    - `public static func resolved(site: String, tone: Tone, pick: (Int) -> Int = { Int.random(in: 0..<$0) }) -> String`
  - `pick(n)` receives the option count and returns an index — inject a constant closure in tests for determinism.

- [x] **Step 1: Write the failing tests**

Create `Tests/TickerCoreTests/MessageComposerTests.swift`:
```swift
import XCTest
@testable import TickerCore

final class MessageComposerTests: XCTestCase {
    let first = { (_: Int) in 0 }

    func testTierThresholds() {
        let config = Config.default  // repeatOffenderThreshold: 2, notNewsThreshold: 5
        XCTAssertEqual(Tier.forCount(1, config: config), .fresh)
        XCTAssertEqual(Tier.forCount(2, config: config), .repeatOffender)
        XCTAssertEqual(Tier.forCount(4, config: config), .repeatOffender)
        XCTAssertEqual(Tier.forCount(5, config: config), .notEvenNews)
        XCTAssertEqual(Tier.forCount(50, config: config), .notEvenNews)
    }

    func testPlaceholdersAreFilled() {
        for tone in Tone.allCases {
            for tier in [Tier.fresh, .repeatOffender, .notEvenNews] {
                let msg = MessageComposer.breakingNews(
                    site: "GitHub", description: "Partial Outage",
                    tier: tier, tone: tone, pick: first)
                XCTAssertTrue(msg.contains("GitHub"), "\(tone)/\(tier): \(msg)")
                XCTAssertFalse(msg.contains("{site}"), "\(tone)/\(tier): \(msg)")
                XCTAssertFalse(msg.contains("{desc}"), "\(tone)/\(tier): \(msg)")
            }
            let done = MessageComposer.resolved(site: "GitHub", tone: tone, pick: first)
            XCTAssertTrue(done.contains("GitHub"))
            XCTAssertFalse(done.contains("{site}"))
        }
    }

    func testSnarkyNotEvenNewsIsSnarky() {
        let msg = MessageComposer.breakingNews(
            site: "GitHub", description: "Major Outage",
            tier: .notEvenNews, tone: .snarky, pick: first)
        XCTAssertTrue(msg.lowercased().contains("news"))
    }

    func testPickIndexSelectsVariant() {
        let a = MessageComposer.breakingNews(site: "X", description: "d", tier: .fresh, tone: .snarky, pick: { _ in 0 })
        let b = MessageComposer.breakingNews(site: "X", description: "d", tier: .fresh, tone: .snarky, pick: { _ in 1 })
        XCTAssertNotEqual(a, b)
    }
}
```

- [x] **Step 2: Run tests to verify they fail**

Run: `swift test --filter MessageComposerTests`
Expected: FAIL — `Tier` / `MessageComposer` not defined.

- [x] **Step 3: Write the implementation**

Create `Sources/TickerCore/MessageComposer.swift`:
```swift
import Foundation

public enum Tier: Equatable {
    case fresh, repeatOffender, notEvenNews

    public static func forCount(_ count: Int, config: Config) -> Tier {
        if count >= config.notNewsThreshold { return .notEvenNews }
        if count >= config.repeatOffenderThreshold { return .repeatOffender }
        return .fresh
    }
}

public enum MessageComposer {
    // {site} = service name, {desc} = status page description.
    private static let breaking: [Tone: [Tier: [String]]] = [
        .snarky: [
            .fresh: [
                "BREAKING: {site} is down. Somewhere, an on-call phone is ruining a perfectly good lunch. — {desc}",
                "BREAKING: {site} has stopped {site}-ing. Status page says: {desc}",
            ],
            .repeatOffender: [
                "BREAKING: {site} is down AGAIN. At this point we should just leave this banner up. — {desc}",
                "BREAKING: {site} is down again. You'd think they'd be getting good at this by now. — {desc}",
            ],
            .notEvenNews: [
                "{site} is down. This isn't even news anymore. — {desc}",
                "In today's episode of \"{site} is down\": {desc}. We'll keep the banner warm.",
            ],
        ],
        .balanced: [
            .fresh: [
                "BREAKING: {site} is reporting an incident — {desc}. May your retries be gentle.",
                "BREAKING: {site} is having a moment — {desc}. Hugops to the on-call.",
            ],
            .repeatOffender: [
                "BREAKING: {site} is down again — {desc}. Hugops to the on-call, popcorn for everyone else.",
                "{site} outage (you may remember them from last time) — {desc}. Good luck out there.",
            ],
            .notEvenNews: [
                "{site} is down (yes, again) — {desc}. Honestly, respect for the consistency. Hugops.",
                "{site} is down. You already knew. — {desc}. Be nice to the responders anyway.",
            ],
        ],
        .hugops: [
            .fresh: [
                "Incident at {site}: {desc}. Hugops to everyone on the bridge call — you've got this. 💚",
                "{site} is having a rough one: {desc}. Sending hugops to the responders.",
            ],
            .repeatOffender: [
                "{site} is having another rough day: {desc}. Be kind to your friendly neighbourhood SRE. 💚",
                "Another incident at {site}: {desc}. Hugops — nobody wants to be paged twice in a month.",
            ],
            .notEvenNews: [
                "{site} is down again: {desc}. Rough month for that team — send snacks, not tickets. 💚",
                "Incident at {site} (it's been a lot lately): {desc}. Extra hugops today.",
            ],
        ],
    ]

    private static let resolvedTemplates: [Tone: [String]] = [
        .snarky: [
            "RESOLVED: {site} lives again. Panic-refreshing may now cease.",
            "{site} is back. Nobody touch anything.",
        ],
        .balanced: [
            "RESOLVED: {site} is back up. Good work, whoever you are.",
            "{site} recovered. As you were.",
        ],
        .hugops: [
            "RESOLVED: {site} is healthy again. Nice work, responders. 💚",
            "{site} is back. Hope the on-call gets some rest now. 💚",
        ],
    ]

    public static func breakingNews(site: String, description: String, tier: Tier, tone: Tone,
                                    pick: (Int) -> Int = { Int.random(in: 0..<$0) }) -> String {
        let options = breaking[tone]![tier]!
        return fill(options[pick(options.count)], site: site, desc: description)
    }

    public static func resolved(site: String, tone: Tone,
                                pick: (Int) -> Int = { Int.random(in: 0..<$0) }) -> String {
        let options = resolvedTemplates[tone]!
        return fill(options[pick(options.count)], site: site, desc: "")
    }

    private static func fill(_ template: String, site: String, desc: String) -> String {
        template
            .replacingOccurrences(of: "{site}", with: site)
            .replacingOccurrences(of: "{desc}", with: desc)
    }
}
```

- [x] **Step 4: Run tests to verify they pass**

Run: `swift test --filter MessageComposerTests`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add Sources/TickerCore/MessageComposer.swift Tests/TickerCoreTests/MessageComposerTests.swift
git commit -m "feat: tone- and frequency-aware breaking news messages"
```

---

### Task 7: Poll engine

**Files:**
- Create: `Sources/TickerCore/PollEngine.swift`
- Test: `Tests/TickerCoreTests/PollEngineTests.swift`

**Interfaces:**
- Consumes: `Config` (Task 2), `StatusPage.parse`/`Indicator` (Task 3), `OutageMonitor` (Task 4), `OutageHistory` (Task 5), `MessageComposer`/`Tier` (Task 6).
- Produces:
  - `public final class PollEngine` with `init(config: Config, history: OutageHistory, pick: @escaping (Int) -> Int = { Int.random(in: 0..<$0) })` and `public func poll(now: Date = Date(), fetch: (URL) async throws -> Data) async -> String?`.
  - Return value: joined ticker text for all active outages (sites sorted alphabetically, joined with `"  •  "`), or `nil` meaning hide the ticker. Fetch/parse failures skip that site and leave its previous state untouched. A resolved message stays for exactly one further poll, then disappears.

- [x] **Step 1: Write the failing tests**

Create `Tests/TickerCoreTests/PollEngineTests.swift`:
```swift
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
```

- [x] **Step 2: Run tests to verify they fail**

Run: `swift test --filter PollEngineTests`
Expected: FAIL — `PollEngine` not defined.

- [x] **Step 3: Write the implementation**

Create `Sources/TickerCore/PollEngine.swift`:
```swift
import Foundation

public final class PollEngine {
    private let config: Config
    private let history: OutageHistory
    private let monitor = OutageMonitor()
    private let pick: (Int) -> Int
    private var active: [String: String] = [:]        // site name → ticker message
    private var pendingRemoval: Set<String> = []      // resolved messages to drop next poll

    public init(config: Config, history: OutageHistory,
                pick: @escaping (Int) -> Int = { Int.random(in: 0..<$0) }) {
        self.config = config
        self.history = history
        self.pick = pick
    }

    public func poll(now: Date = Date(), fetch: (URL) async throws -> Data) async -> String? {
        for site in pendingRemoval { active.removeValue(forKey: site) }
        pendingRemoval.removeAll()

        for site in config.sites {
            guard let url = URL(string: site.url + "/api/v2/status.json"),
                  let data = try? await fetch(url),
                  let status = try? StatusPage.parse(data)
            else { continue }  // network/parse failure: keep previous state

            switch monitor.observe(site: site.name, indicator: status.indicator) {
            case .began:
                history.record(site: site.name, at: now)
                let count = history.count(site: site.name, withinDays: config.historyWindowDays, asOf: now)
                active[site.name] = MessageComposer.breakingNews(
                    site: site.name, description: status.description,
                    tier: Tier.forCount(count, config: config), tone: config.tone, pick: pick)
            case .ended:
                active[site.name] = MessageComposer.resolved(site: site.name, tone: config.tone, pick: pick)
                pendingRemoval.insert(site.name)
            case .none:
                break
            }
        }

        guard !active.isEmpty else { return nil }
        return active.keys.sorted().compactMap { active[$0] }.joined(separator: "  •  ")
    }
}
```

- [x] **Step 4: Run tests to verify they pass**

Run: `swift test --filter PollEngineTests`
Expected: PASS.

- [x] **Step 5: Run the full suite**

Run: `swift test`
Expected: all tests PASS.

- [x] **Step 6: Commit**

```bash
git add Sources/TickerCore/PollEngine.swift Tests/TickerCoreTests/PollEngineTests.swift
git commit -m "feat: poll engine turning status polls into ticker text"
```

---

### Task 8: Ticker overlay window

**Files:**
- Create: `Sources/NewsTicker/TickerController.swift`
- Modify: `Sources/NewsTicker/main.swift` (temporary demo harness — replaced in Task 9)

**Interfaces:**
- Consumes: `Edge` from Task 2.
- Produces: `final class TickerController` with `init(edge: Edge, pointsPerSecond: Double)`, `func show(_ message: String)`, `func hide()`. AppKit only — no unit tests; verified manually.

- [x] **Step 1: Write the implementation**

Create `Sources/NewsTicker/TickerController.swift`:
```swift
import AppKit
import TickerCore

final class TickerController {
    private let window: NSWindow
    private let textLayer = CATextLayer()
    private let pointsPerSecond: Double
    private static let barHeight: CGFloat = 36
    private static let fontSize: CGFloat = 20

    init(edge: Edge, pointsPerSecond: Double) {
        self.pointsPerSecond = pointsPerSecond
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = NSScreen.main?.visibleFrame ?? screen
        // Top edge sits just below the menu bar (visibleFrame excludes it).
        let y = edge == .top ? visible.maxY - Self.barHeight : screen.minY
        window = NSWindow(
            contentRect: NSRect(x: screen.minX, y: y, width: screen.width, height: Self.barHeight),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true  // click-through: never steal focus
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let content = NSView(frame: NSRect(origin: .zero, size: window.frame.size))
        content.wantsLayer = true
        content.layer?.backgroundColor =
            NSColor(red: 0.72, green: 0.05, blue: 0.05, alpha: 0.92).cgColor
        content.layer?.masksToBounds = true

        textLayer.font = NSFont.boldSystemFont(ofSize: Self.fontSize)
        textLayer.fontSize = Self.fontSize
        textLayer.foregroundColor = NSColor.white.cgColor
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        content.layer?.addSublayer(textLayer)
        window.contentView = content
    }

    func show(_ message: String) {
        let text = "  +++ \(message) +++  "
        let attributed = NSAttributedString(
            string: text, attributes: [.font: NSFont.boldSystemFont(ofSize: Self.fontSize)])
        let textWidth = ceil(attributed.size().width)
        let textHeight = ceil(attributed.size().height)

        textLayer.string = text
        textLayer.frame = CGRect(
            x: 0, y: (Self.barHeight - textHeight) / 2, width: textWidth, height: textHeight)
        textLayer.removeAllAnimations()

        let screenWidth = window.frame.width
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = screenWidth + textWidth / 2
        animation.toValue = -textWidth / 2
        animation.duration = (Double(screenWidth) + Double(textWidth)) / pointsPerSecond
        animation.repeatCount = .infinity
        textLayer.add(animation, forKey: "marquee")

        window.orderFrontRegardless()
    }

    func hide() {
        textLayer.removeAllAnimations()
        window.orderOut(nil)
    }
}
```

- [x] **Step 2: Write a temporary demo harness in main.swift**

Replace `Sources/NewsTicker/main.swift`:
```swift
import AppKit
import TickerCore

// Temporary Task 8 demo harness — replaced by the real app in Task 9.
final class DemoDelegate: NSObject, NSApplicationDelegate {
    var ticker: TickerController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ticker = TickerController(edge: .bottom, pointsPerSecond: 120)
        ticker?.show("BREAKING: GitHub is down. This isn't even news. — Major Outage")
    }
}

let app = NSApplication.shared
let delegate = DemoDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [x] **Step 3: Verify manually**

Run: `swift run`
Expected: a red bar spans the bottom of the screen with the message scrolling right-to-left on repeat, clicks pass through it, no Dock icon appears. Kill with Ctrl-C.
Also check: change `edge: .bottom` to `.top`, `swift run` again, confirm the bar appears just below the menu bar. Revert to `.bottom` after checking. If the ticker is invisible on top, raise the window level one notch: `NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)`.

- [x] **Step 4: Commit**

```bash
git add Sources/NewsTicker/TickerController.swift Sources/NewsTicker/main.swift
git commit -m "feat: scrolling ticker overlay window"
```

---

### Task 9: App wiring — menu bar item, timer, demo mode

**Files:**
- Modify: `Sources/NewsTicker/main.swift` (replace demo harness)

**Interfaces:**
- Consumes: `Config` (Task 2), `OutageHistory` (Task 5), `PollEngine` (Task 7), `TickerController` (Task 8).
- Produces: the finished app. Config at `~/Library/Application Support/NewsTicker/config.json`, history at `.../history.json`. Menu: Test Ticker (20 s sample), Open Config, Reload Config, Quit. Env var `NEWSTICKER_DEMO=1` shows a sample ticker on launch for verification.

- [x] **Step 1: Write the implementation**

Replace `Sources/NewsTicker/main.swift`:
```swift
import AppKit
import TickerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var ticker: TickerController!
    private var engine: PollEngine!
    private var config = Config.default
    private var timer: Timer?

    private let appSupport = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("NewsTicker")
    private var configURL: URL { appSupport.appendingPathComponent("config.json") }
    private var historyURL: URL { appSupport.appendingPathComponent("history.json") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !FileManager.default.fileExists(atPath: configURL.path) {
            try? Config.default.save(to: configURL)  // seed an editable config on first run
        }
        setUpStatusItem()
        reload()

        if ProcessInfo.processInfo.environment["NEWSTICKER_DEMO"] == "1" {
            testTicker()
        }
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📰"
        let menu = NSMenu()
        for (title, action, key) in [
            ("Test Ticker", #selector(testTicker), "t"),
            ("Open Config", #selector(openConfig), "o"),
            ("Reload Config", #selector(reloadConfig), "r"),
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        // Quit keeps a nil target so the responder chain reaches NSApp; pointing it at
        // AppDelegate would leave it greyed out, since AppDelegate has no terminate(_:).
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func reload() {
        timer?.invalidate()
        ticker?.hide()
        config = Config.load(from: configURL)
        ticker = TickerController(edge: config.edge, pointsPerSecond: config.scrollPointsPerSecond)
        engine = PollEngine(config: config, history: OutageHistory.load(from: historyURL))
        timer = Timer.scheduledTimer(withTimeInterval: config.pollIntervalSeconds, repeats: true) { [weak self] _ in
            self?.pollOnce()
        }
        pollOnce()
    }

    private func pollOnce() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let text = await self.engine.poll { url in
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let (data, _) = try await URLSession.shared.data(for: request)
                return data
            }
            if let text { self.ticker.show(text) } else { self.ticker.hide() }
        }
    }

    @objc private func testTicker() {
        ticker.show(MessageComposer.breakingNews(
            site: "GitHub", description: "Major Outage",
            tier: .notEvenNews, tone: config.tone))
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            self?.pollOnce()  // restores real state (hides if nothing is down)
        }
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(configURL)
    }

    @objc private func reloadConfig() {
        reload()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [x] **Step 2: Verify build and full test suite**

Run: `swift build && swift test`
Expected: build succeeds, all tests PASS.

- [x] **Step 3: Verify manually**

Run: `NEWSTICKER_DEMO=1 swift run`
Expected:
1. 📰 appears in the menu bar; no Dock icon.
2. The demo ticker scrolls a not-even-news GitHub message, then disappears within ~20 s + one poll (assuming no real outage).
3. Menu → Test Ticker shows it again; Open Config opens the JSON; edit `"tone": "hugops"` and `"edge": "top"`, Reload Config, Test Ticker — message is now supportive and the bar is at the top.
4. Menu → Quit exits cleanly.
5. Confirm `~/Library/Application Support/NewsTicker/config.json` exists.

- [x] **Step 4: Commit**

```bash
git add Sources/NewsTicker/main.swift
git commit -m "feat: menu bar app wiring with poll timer and demo mode"
```

---

### Task 10: README

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: everything; documents the finished app.
- Produces: user-facing docs.

- [x] **Step 1: Write README.md**

```markdown
# NewsTicker

A macOS menu bar app that watches status pages and fires a scrolling
breaking-news ticker across your screen when something is down. Snark level
configurable. Hugops always.

## Run

    swift run

Requires macOS 13+. No dependencies. The app lives in the menu bar (📰) —
no Dock icon, no window until something breaks.

Try it immediately:

    NEWSTICKER_DEMO=1 swift run

or use 📰 → Test Ticker.

## Configure

Config lives at `~/Library/Application Support/NewsTicker/config.json`
(created on first run). Edit it (📰 → Open Config), then 📰 → Reload Config.

| Key | Default | Meaning |
|---|---|---|
| `sites` | GitHub, ClickHouse, Atlassian, Claude | Statuspage-based pages to poll (`<url>/api/v2/status.json` must exist) |
| `pollIntervalSeconds` | 60 | How often to poll |
| `tone` | `balanced` | `hugops`, `balanced`, or `snarky` |
| `edge` | `bottom` | `top` or `bottom` of the screen |
| `historyWindowDays` | 30 | Window for counting repeat outages |
| `repeatOffenderThreshold` | 2 | Outages in window before "again?" messages |
| `notNewsThreshold` | 5 | Outages in window before "this isn't even news" |
| `scrollPointsPerSecond` | 120 | Ticker scroll speed |

Any Atlassian Statuspage-powered page works — add
`{"name": "Foo", "url": "https://status.foo.com"}` to `sites`.

## Test

    swift test
```

- [x] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README with run and config instructions"
```

---

### Task 11: Mock status server for local testing

**Files:**
- Create: `scripts/mock-status-server.py`
- Create: `scripts/mock-config.json`
- Modify: `Sources/NewsTicker/main.swift` (config path env override — written in Task 9)
- Modify: `.gitignore`

**Interfaces:**
- Consumes: the `AppDelegate` from Task 9 (`configURL`/`historyURL` computed properties).
- Produces:
  - A stdlib-only Python 3 HTTP server answering `GET /<site>/api/v2/status.json` with the same payload shape as real Statuspage. Each site cycles up/down on a fixed period (default 45 s up / 30 s down), derived purely from wall-clock time — stateless, so restarts don't reset phases, and each site name gets a hash-based phase offset so sites don't fail in lockstep.
  - `NEWSTICKER_CONFIG=<path>` env var: overrides the config file location; `history.json` then lives next to that config file, so mock runs never pollute the real outage history. No env var → behavior unchanged.
  - Note: no ATS/Info.plist work needed — App Transport Security exempts loopback (`http://127.0.0.1`) connections.

- [x] **Step 1: Write the mock server**

Create `scripts/mock-status-server.py`:
```python
#!/usr/bin/env python3
"""Mock Statuspage server for local ticker testing.

Answers GET /<site>/api/v2/status.json with the Statuspage v2 payload shape.
Each site cycles: up for --up seconds, down for --down seconds, computed from
wall-clock time (stateless). The site name hashes to a phase offset so
different sites go down at different times.

Usage:
    python3 scripts/mock-status-server.py [--port 8787] [--up 45] [--down 30]
    python3 scripts/mock-status-server.py --self-test
"""
import argparse
import json
import time
import zlib
from http.server import BaseHTTPRequestHandler, HTTPServer


def indicator(site: str, now: int, up: int, down: int) -> str:
    period = up + down
    offset = zlib.crc32(site.encode()) % period
    return "major" if (now + offset) % period >= up else "none"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if not self.path.endswith("/api/v2/status.json"):
            self.send_error(404)
            return
        site = self.path.strip("/").split("/")[0]
        ind = indicator(site, int(time.time()), self.server.up, self.server.down)
        desc = "Mock Major Outage" if ind == "major" else "All Systems Operational"
        body = json.dumps({"status": {"indicator": ind, "description": desc}}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        site = self.path.strip("/").split("/")[0]
        ind = indicator(site, int(time.time()), self.server.up, self.server.down)
        print(f"{time.strftime('%H:%M:%S')} {site}: {ind}")


def self_test(up: int = 45, down: int = 30) -> None:
    # Over one full period every site spends exactly `up` seconds up and
    # `down` seconds down, regardless of its phase offset, and the cycle repeats.
    for site in ("mockhub", "mockhouse"):
        states = [indicator(site, t, up, down) for t in range(up + down)]
        assert states.count("none") == up, states
        assert states.count("major") == down, states
        assert indicator(site, 0, up, down) == indicator(site, up + down, up, down)
    print("self-test OK")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--up", type=int, default=45)
    parser.add_argument("--down", type=int, default=30)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    else:
        server = HTTPServer(("127.0.0.1", args.port), Handler)
        server.up, server.down = args.up, args.down
        print(f"mock statuspage on http://127.0.0.1:{args.port} "
              f"(up {args.up}s / down {args.down}s per site)")
        server.serve_forever()
```

- [x] **Step 2: Run the self-test**

Run: `python3 scripts/mock-status-server.py --self-test`
Expected: prints `self-test OK`, exit code 0.

- [x] **Step 3: Write the mock config**

Create `scripts/mock-config.json`:
```json
{
  "sites": [
    { "name": "MockHub", "url": "http://127.0.0.1:8787/mockhub" },
    { "name": "MockHouse", "url": "http://127.0.0.1:8787/mockhouse" }
  ],
  "pollIntervalSeconds": 5,
  "tone": "snarky",
  "edge": "bottom",
  "historyWindowDays": 30,
  "repeatOffenderThreshold": 2,
  "notNewsThreshold": 5,
  "scrollPointsPerSecond": 120
}
```

- [x] **Step 4: Add the NEWSTICKER_CONFIG override to main.swift**

In `Sources/NewsTicker/main.swift`, replace:
```swift
    private var configURL: URL { appSupport.appendingPathComponent("config.json") }
    private var historyURL: URL { appSupport.appendingPathComponent("history.json") }
```
with:
```swift
    // NEWSTICKER_CONFIG points at an alternate config for local testing;
    // history then lives beside it so mock outages never pollute real history.
    private var configURL: URL {
        if let override = ProcessInfo.processInfo.environment["NEWSTICKER_CONFIG"] {
            return URL(fileURLWithPath: override)
        }
        return appSupport.appendingPathComponent("config.json")
    }
    private var historyURL: URL {
        configURL.deletingLastPathComponent().appendingPathComponent("history.json")
    }
```

- [x] **Step 5: Ignore mock-run history and verify build**

```bash
printf 'scripts/history.json\n' >> .gitignore
swift build && swift test
```
Expected: build succeeds, all tests still PASS (no TickerCore changes).

- [x] **Step 6: Verify end to end**

Terminal 1: `python3 scripts/mock-status-server.py --up 20 --down 20`
Terminal 2:
```bash
curl -s http://127.0.0.1:8787/mockhub/api/v2/status.json
NEWSTICKER_CONFIG=scripts/mock-config.json swift run
```
Expected:
1. `curl` returns `{"status": {"indicator": ..., "description": ...}}`.
2. Within ~25 s the ticker fires with a snarky MockHub/MockHouse outage, hides again when the mock recovers, and keeps cycling.
3. After a few cycles the messages escalate to repeat-offender then not-even-news tiers (history accumulates in `scripts/history.json`).
4. `~/Library/Application Support/NewsTicker/history.json` is untouched.
5. Delete `scripts/history.json` when done to reset mock escalation.

- [x] **Step 7: Commit**

```bash
git add scripts/mock-status-server.py scripts/mock-config.json Sources/NewsTicker/main.swift .gitignore
git commit -m "feat: mock statuspage server and config override for local testing"
```

---

## Deliberately skipped (add only when wanted)

- **Settings UI** — the config is a JSON file plus a Reload menu item. A preferences window is pure ceremony for a novelty app.
- **`.app` bundle / code signing / launch-at-login** — `swift run` is enough to use it. If it graduates to daily-driver, wrap it in an app bundle and add a `SMAppService` login item then.
- **Multi-display support** — ticker renders on `NSScreen.main` only. Iterate over `NSScreen.screens` in `TickerController` if someone asks.
- **Per-site severity thresholds / component-level incidents** — the page-level indicator is the joke's granularity. `summary.json` has per-component detail if ever needed.
- **Notification Center fallback** — the ticker IS the notification.
