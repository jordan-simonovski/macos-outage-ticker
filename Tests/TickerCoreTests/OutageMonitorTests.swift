import Foundation
import TickerCore

func runOutageMonitorTests() {
    // Up then down is a beginning
    let a = OutageMonitor()
    Check.equal(a.observe(site: "GitHub", indicator: .none), .none)
    Check.equal(a.observe(site: "GitHub", indicator: .major), .began)

    // App launched mid-outage: still fire the ticker
    Check.equal(OutageMonitor().observe(site: "GitHub", indicator: .critical), .began)

    // Down stays down is not a new event
    let b = OutageMonitor()
    _ = b.observe(site: "GitHub", indicator: .major)
    Check.equal(b.observe(site: "GitHub", indicator: .minor), .none)

    // Down then up is an ending
    let c = OutageMonitor()
    _ = c.observe(site: "GitHub", indicator: .major)
    Check.equal(c.observe(site: "GitHub", indicator: .none), .ended)

    // Sites are tracked independently
    let d = OutageMonitor()
    _ = d.observe(site: "GitHub", indicator: .major)
    Check.equal(d.observe(site: "Claude", indicator: .minor), .began)

    // Only minor/major/critical count as outages
    Check.isFalse(OutageMonitor.isOutage(.maintenance))
    Check.isFalse(OutageMonitor.isOutage(.unknown))
    Check.isFalse(OutageMonitor.isOutage(.none))
    Check.isTrue(OutageMonitor.isOutage(.minor))
    Check.isTrue(OutageMonitor.isOutage(.major))
    Check.isTrue(OutageMonitor.isOutage(.critical))
}
