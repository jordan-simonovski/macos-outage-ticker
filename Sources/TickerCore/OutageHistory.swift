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
        // Atomic: a partial write must never eat the history file.
        try? JSONEncoder().encode(events).write(to: fileURL, options: .atomic)
    }
}
