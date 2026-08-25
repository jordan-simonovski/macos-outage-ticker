import AppKit
import TickerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var ticker: TickerController!
    private var engine: PollEngine!
    private var config = Config.default
    private var timer: Timer?

    private let appSupport = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("NewsTicker")
    private var configURL: URL { appSupport.appendingPathComponent("config.json") }
    private var historyURL: URL { appSupport.appendingPathComponent("history.json") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !FileManager.default.fileExists(atPath: configURL.path) {
            try? Config.default.save(to: configURL)  // seed an editable config on first run
        }
        setUpStatusItem()
        reload()

        let env = ProcessInfo.processInfo.environment
        if env["NEWSTICKER_DEMO"] == "1" { testTicker() }
        if env["NEWSTICKER_SELFTEST"] == "1" { runSelfTest() }
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📰"
        let menu = NSMenu()
        for (title, action, key) in [
            ("Test Ticker", #selector(testTicker), "t"),
            ("Open Config", #selector(openConfig), "o"),
            ("Reload Config", #selector(reloadConfig), "r"),
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        // Quit keeps a nil target so the responder chain reaches NSApp; pointing it at
        // AppDelegate would leave it greyed out, since AppDelegate has no terminate(_:).
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func reload() {
        timer?.invalidate()
        ticker?.hide()
        config = Config.load(from: configURL)
        ticker = TickerController(edge: config.edge, pointsPerSecond: config.scrollPointsPerSecond)
        engine = PollEngine(config: config, history: OutageHistory.load(from: historyURL))
        timer = Timer.scheduledTimer(withTimeInterval: config.pollIntervalSeconds, repeats: true) { [weak self] _ in
            self?.pollOnce()
        }
        pollOnce()
    }

    private func pollOnce() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let text = await self.engine.poll { url in
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let (data, _) = try await URLSession.shared.data(for: request)
                return data
            }
            if let text { self.ticker.show(text) } else { self.ticker.hide() }
        }
    }

    @objc private func testTicker() {
        ticker.show(MessageComposer.breakingNews(
            site: "GitHub", description: "Major Outage",
            tier: .notEvenNews, tone: config.tone))
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            self?.pollOnce()  // restores real state (hides if nothing is down)
        }
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(configURL)
    }

    @objc private func reloadConfig() {
        reload()
    }

    // NEWSTICKER_SELFTEST=1 prints what a human would otherwise eyeball, then exits.
    // This machine cannot screenshot (no Screen Recording permission), so this is
    // the only runnable check the AppKit layer has.
    private func runSelfTest() {
        let menu = statusItem.menu!
        menu.update()  // force auto-enabling validation, the thing that greys Quit out
        print("statusItem title=\(statusItem.button?.title ?? "nil")")
        print("activationPolicy=\(NSApp.activationPolicy() == .accessory ? "accessory" : "OTHER")")
        for item in menu.items where !item.isSeparatorItem {
            print("menu \"\(item.title)\" enabled=\(item.isEnabled) target=\(item.target == nil ? "responderChain" : "delegate")")
        }
        print("config=\(configURL.path) exists=\(FileManager.default.fileExists(atPath: configURL.path))")
        print("history=\(historyURL.path)")
        print("tone=\(config.tone.rawValue) edge=\(config.edge.rawValue) interval=\(config.pollIntervalSeconds)")
        print("ticker \(ticker.geometry)")
        exit(0)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
