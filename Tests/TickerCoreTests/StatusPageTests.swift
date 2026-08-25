import XCTest
@testable import TickerCore

final class StatusPageTests: XCTestCase {
    func testParsesHealthyPayload() throws {
        let json = #"{"page":{"id":"kctbh9vrtdwd","name":"GitHub","url":"https://www.githubstatus.com","updated_at":"2026-08-25T00:00:00Z"},"status":{"indicator":"none","description":"All Systems Operational"}}"#
        let status = try StatusPage.parse(Data(json.utf8))
        XCTAssertEqual(status, ServiceStatus(indicator: .none, description: "All Systems Operational"))
    }

    func testParsesOutagePayload() throws {
        let json = #"{"status":{"indicator":"major","description":"Partial System Outage"}}"#
        let status = try StatusPage.parse(Data(json.utf8))
        XCTAssertEqual(status.indicator, .major)
    }

    func testUnknownIndicatorDecodesAsUnknown() throws {
        let json = #"{"status":{"indicator":"weird_new_value","description":"?"}}"#
        let status = try StatusPage.parse(Data(json.utf8))
        XCTAssertEqual(status.indicator, .unknown)
    }

    func testGarbageDataThrows() {
        XCTAssertThrowsError(try StatusPage.parse(Data("<html>".utf8)))
    }
}
