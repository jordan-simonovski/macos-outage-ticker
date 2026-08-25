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
