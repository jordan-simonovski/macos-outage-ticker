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
