import Foundation

public enum Indicator: String, Codable, Equatable {
    case none, minor, major, critical, maintenance, unknown

    // Statuspage can add indicators any time; an unrecognised one must not throw.
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
