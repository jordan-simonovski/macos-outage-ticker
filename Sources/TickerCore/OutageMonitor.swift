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
        // Never-seen site defaults to healthy, so launching mid-outage still fires.
        let wasDown = lastIndicator[site].map(Self.isOutage) ?? false
        let isDown = Self.isOutage(indicator)
        lastIndicator[site] = indicator
        if !wasDown && isDown { return .began }
        if wasDown && !isDown { return .ended }
        return .none
    }
}
