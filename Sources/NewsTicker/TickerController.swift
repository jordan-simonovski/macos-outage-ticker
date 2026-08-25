import AppKit
import TickerCore

final class TickerController {
    private let window: NSWindow
    private let textLayer = CATextLayer()
    private let pointsPerSecond: Double
    private static let barHeight: CGFloat = 36
    private static let fontSize: CGFloat = 20

    init(edge: Edge, pointsPerSecond: Double) {
        self.pointsPerSecond = pointsPerSecond
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = NSScreen.main?.visibleFrame ?? screen
        // Top edge sits just below the menu bar (visibleFrame excludes it).
        let y = edge == .top ? visible.maxY - Self.barHeight : screen.minY
        window = NSWindow(
            contentRect: NSRect(x: screen.minX, y: y, width: screen.width, height: Self.barHeight),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true  // click-through: never steal focus
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let content = NSView(frame: NSRect(origin: .zero, size: window.frame.size))
        content.wantsLayer = true
        content.layer?.backgroundColor =
            NSColor(red: 0.72, green: 0.05, blue: 0.05, alpha: 0.92).cgColor
        content.layer?.masksToBounds = true

        textLayer.font = NSFont.boldSystemFont(ofSize: Self.fontSize)
        textLayer.fontSize = Self.fontSize
        textLayer.foregroundColor = NSColor.white.cgColor
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        content.layer?.addSublayer(textLayer)
        window.contentView = content
    }

    func show(_ message: String) {
        let text = "  +++ \(message) +++  "
        let attributed = NSAttributedString(
            string: text, attributes: [.font: NSFont.boldSystemFont(ofSize: Self.fontSize)])
        let textWidth = ceil(attributed.size().width)
        let textHeight = ceil(attributed.size().height)

        textLayer.string = text
        textLayer.frame = CGRect(
            x: 0, y: (Self.barHeight - textHeight) / 2, width: textWidth, height: textHeight)
        textLayer.removeAllAnimations()

        let screenWidth = window.frame.width
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = screenWidth + textWidth / 2
        animation.toValue = -textWidth / 2
        animation.duration = (Double(screenWidth) + Double(textWidth)) / pointsPerSecond
        animation.repeatCount = .infinity
        textLayer.add(animation, forKey: "marquee")

        window.orderFrontRegardless()
    }

    // Task 8 verification hook: geometry and visibility without a screenshot.
    // Named so it cannot resolve to Optional.debugDescription through ticker!.
    var geometry: String {
        "frame=\(window.frame) visible=\(window.isVisible) level=\(window.level.rawValue) "
        + "clickThrough=\(window.ignoresMouseEvents) textWidth=\(textLayer.frame.width) "
        + "anim=\(textLayer.animation(forKey: "marquee") != nil)"
    }

    func hide() {
        textLayer.removeAllAnimations()
        window.orderOut(nil)
    }
}
