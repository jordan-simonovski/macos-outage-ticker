import Foundation
import TickerCore

func runMessageComposerTests() {
    let first = { (_: Int) in 0 }

    // Tier thresholds (default config: repeatOffender 2, notNews 5)
    let config = Config.default
    Check.equal(Tier.forCount(1, config: config), .fresh)
    Check.equal(Tier.forCount(2, config: config), .repeatOffender)
    Check.equal(Tier.forCount(4, config: config), .repeatOffender)
    Check.equal(Tier.forCount(5, config: config), .notEvenNews)
    Check.equal(Tier.forCount(50, config: config), .notEvenNews)

    // Every tone/tier combination exists and fills its placeholders
    for tone in Tone.allCases {
        for tier in [Tier.fresh, .repeatOffender, .notEvenNews] {
            let msg = MessageComposer.breakingNews(
                site: "GitHub", description: "Partial Outage",
                tier: tier, tone: tone, pick: first)
            Check.isTrue(msg.contains("GitHub"), "\(tone)/\(tier): \(msg)")
            Check.isFalse(msg.contains("{site}"), "\(tone)/\(tier): \(msg)")
            Check.isFalse(msg.contains("{desc}"), "\(tone)/\(tier): \(msg)")
        }
        let done = MessageComposer.resolved(site: "GitHub", tone: tone, pick: first)
        Check.isTrue(done.contains("GitHub"))
        Check.isFalse(done.contains("{site}"))
    }

    // The snarkiest tier actually lands the "not even news" joke
    let snark = MessageComposer.breakingNews(
        site: "GitHub", description: "Major Outage",
        tier: .notEvenNews, tone: .snarky, pick: first)
    Check.isTrue(snark.lowercased().contains("news"))

    // pick() selects between variants
    let a = MessageComposer.breakingNews(site: "X", description: "d", tier: .fresh, tone: .snarky, pick: { _ in 0 })
    let b = MessageComposer.breakingNews(site: "X", description: "d", tier: .fresh, tone: .snarky, pick: { _ in 1 })
    Check.notEqual(a, b)
}
