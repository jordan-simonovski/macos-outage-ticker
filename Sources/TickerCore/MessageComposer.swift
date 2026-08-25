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
