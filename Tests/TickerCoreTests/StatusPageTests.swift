import Foundation
import TickerCore

func runStatusPageTests() {
    let healthy = #"{"page":{"id":"kctbh9vrtdwd","name":"GitHub","url":"https://www.githubstatus.com","updated_at":"2026-08-25T00:00:00Z"},"status":{"indicator":"none","description":"All Systems Operational"}}"#
    if let status = try? StatusPage.parse(Data(healthy.utf8)) {
        Check.equal(status, ServiceStatus(indicator: .none, description: "All Systems Operational"))
    } else {
        Check.isTrue(false, "healthy payload failed to parse")
    }

    let outage = #"{"status":{"indicator":"major","description":"Partial System Outage"}}"#
    Check.equal(try? StatusPage.parse(Data(outage.utf8)).indicator, .major)

    let weird = #"{"status":{"indicator":"weird_new_value","description":"?"}}"#
    Check.equal(try? StatusPage.parse(Data(weird.utf8)).indicator, .unknown)

    Check.throwsError { _ = try StatusPage.parse(Data("<html>".utf8)) }
}
