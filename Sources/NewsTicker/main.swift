import AppKit
import TickerCore

// Temporary Task 8 demo harness — replaced by the real app in Task 9.
final class DemoDelegate: NSObject, NSApplicationDelegate {
    var ticker: TickerController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let edge: Edge = ProcessInfo.processInfo.environment["TICKER_EDGE"] == "top" ? .top : .bottom
        ticker = TickerController(edge: edge, pointsPerSecond: 120)
        ticker?.show("BREAKING: GitHub is down. This isn't even news. — Major Outage")
        print("shown  \(ticker!.debugDescription)")
        print("screen \(NSScreen.main!.frame) visible=\(NSScreen.main!.visibleFrame)")
        if ProcessInfo.processInfo.environment["TICKER_EXIT"] == "1" {
            ticker?.hide()
            print("hidden \(ticker!.debugDescription)")
            exit(0)
        }
    }
}

let app = NSApplication.shared
let delegate = DemoDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
