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
