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
