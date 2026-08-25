import AppKit
import TickerCore

/// The on-screen ticker: an ONN-branded lower-third pinned to one screen edge.
///
/// Layout, left to right:
///
///     [ ONN ] | scrolling headline text ... | 17:42
///
/// Badge and clock are fixed; only the headline scrolls, inside a clipped
/// container so it never slides underneath either of them.
final class TickerController {
    private let window: NSWindow
    private let textLayer = CATextLayer()
    private let marqueeClip = CALayer()
    private let clockLabel = CATextLayer()
    private let pointsPerSecond: Double
    private var clockTimer: Timer?

    private static let barHeight: CGFloat = 40
    private static let fontSize: CGFloat = 19
    private static let badgeFontSize: CGFloat = 21
    private static let badgePadding: CGFloat = 16

    // ONN broadcast palette: a deep news red, a brighter badge red, white rules.
    private static let barColor = NSColor(red: 0.62, green: 0.04, blue: 0.06, alpha: 1.0)
    private static let badgeColor = NSColor(red: 0.85, green: 0.09, blue: 0.11, alpha: 1.0)

    private static let headlineFont = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    // Monospaced digits: the clock must not jitter as the numbers change.
    private static let clockFont = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)

    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    private static let badgeFont = NSFont.systemFont(ofSize: badgeFontSize, weight: .heavy)

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

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let width = window.frame.width

        let content = NSView(frame: NSRect(origin: .zero, size: window.frame.size))
        content.wantsLayer = true
        guard let root = content.layer else { fatalError("wantsLayer must give us a layer") }
        root.backgroundColor = Self.barColor.cgColor
        root.masksToBounds = true

        // --- ONN badge, pinned left ---------------------------------------
        let badgeText = "ONN"
        let badgeWidth = ceil(NSAttributedString(
            string: badgeText, attributes: [.font: Self.badgeFont]).size().width)
            + Self.badgePadding * 2

        let badge = CALayer()
        badge.frame = CGRect(x: 0, y: 0, width: badgeWidth, height: Self.barHeight)
        badge.backgroundColor = Self.badgeColor.cgColor
        root.addSublayer(badge)

        let badgeLabel = CATextLayer()
        badgeLabel.string = badgeText
        badgeLabel.font = Self.badgeFont
        badgeLabel.fontSize = Self.badgeFontSize
        badgeLabel.foregroundColor = NSColor.white.cgColor
        badgeLabel.alignmentMode = .center
        badgeLabel.contentsScale = scale
        let badgeTextHeight = ceil(NSAttributedString(
            string: badgeText, attributes: [.font: Self.badgeFont]).size().height)
        badgeLabel.frame = CGRect(x: 0, y: (Self.barHeight - badgeTextHeight) / 2,
                                  width: badgeWidth, height: badgeTextHeight)
        badge.addSublayer(badgeLabel)

        // Vertical rule separating badge from headline.
        let divider = CALayer()
        divider.frame = CGRect(x: badgeWidth, y: 0, width: 2, height: Self.barHeight)
        divider.backgroundColor = NSColor(white: 1, alpha: 0.85).cgColor
        root.addSublayer(divider)

        // Hairline along the screen-facing edge, the way a broadcast bug is trimmed.
        let hairline = CALayer()
        hairline.frame = CGRect(x: 0, y: Self.barHeight - 2, width: width, height: 2)
        hairline.backgroundColor = NSColor(white: 1, alpha: 0.35).cgColor
        root.addSublayer(hairline)

        // --- Clock, pinned right ------------------------------------------
        let clockWidth = ceil(NSAttributedString(
            string: "00:00", attributes: [.font: Self.clockFont]).size().width)
            + Self.badgePadding * 2

        let clockBlock = CALayer()
        clockBlock.frame = CGRect(x: width - clockWidth, y: 0,
                                  width: clockWidth, height: Self.barHeight)
        clockBlock.backgroundColor = Self.badgeColor.cgColor
        root.addSublayer(clockBlock)

        let clockTextHeight = ceil(NSAttributedString(
            string: "00:00", attributes: [.font: Self.clockFont]).size().height)
        clockLabel.font = Self.clockFont
        clockLabel.fontSize = Self.fontSize
        clockLabel.foregroundColor = NSColor.white.cgColor
        clockLabel.alignmentMode = .center
        clockLabel.contentsScale = scale
        clockLabel.frame = CGRect(x: 0, y: (Self.barHeight - clockTextHeight) / 2,
                                  width: clockWidth, height: clockTextHeight)
        clockBlock.addSublayer(clockLabel)

        let clockDivider = CALayer()
        clockDivider.frame = CGRect(x: width - clockWidth - 2, y: 0,
                                    width: 2, height: Self.barHeight)
        clockDivider.backgroundColor = NSColor(white: 1, alpha: 0.85).cgColor
        root.addSublayer(clockDivider)

        // --- Scrolling headline, clipped between badge and clock ----------
        let clipX = badgeWidth + 2
        marqueeClip.frame = CGRect(x: clipX, y: 0,
                                   width: width - clipX - clockWidth - 2,
                                   height: Self.barHeight)
        marqueeClip.masksToBounds = true  // headline never slides under the badge
        root.addSublayer(marqueeClip)

        textLayer.font = Self.headlineFont
        textLayer.fontSize = Self.fontSize
        textLayer.foregroundColor = NSColor.white.cgColor
        textLayer.contentsScale = scale
        marqueeClip.addSublayer(textLayer)

        window.contentView = content
        updateClock()
    }

    private func updateClock() {
        // CATextLayer animates string changes by default; the clock should just snap.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        clockLabel.string = Self.clockFormatter.string(from: Date())
        CATransaction.commit()
    }

    // Named so it cannot resolve to Optional.debugDescription through ticker!.
    var geometry: String {
        "frame=\(window.frame) visible=\(window.isVisible) level=\(window.level.rawValue) "
        + "clickThrough=\(window.ignoresMouseEvents) textWidth=\(textLayer.frame.width) "
        + "anim=\(textLayer.animation(forKey: "marquee") != nil)"
    }

    func show(_ message: String) {
        let text = "  \(message)  "
        let attributed = NSAttributedString(
            string: text, attributes: [.font: Self.headlineFont])
        let textWidth = ceil(attributed.size().width)
        let textHeight = ceil(attributed.size().height)

        textLayer.string = text
        textLayer.frame = CGRect(
            x: 0, y: (Self.barHeight - textHeight) / 2, width: textWidth, height: textHeight)
        textLayer.removeAllAnimations()

        // Scroll across the clipped region, not the whole screen.
        let trackWidth = marqueeClip.frame.width
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = trackWidth + textWidth / 2
        animation.toValue = -textWidth / 2
        animation.duration = (Double(trackWidth) + Double(textWidth)) / pointsPerSecond
        animation.repeatCount = .infinity
        textLayer.add(animation, forKey: "marquee")

        window.orderFrontRegardless()

        // Only run the clock while the bar is on screen.
        updateClock()
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateClock()
        }
    }

    func hide() {
        clockTimer?.invalidate()
        clockTimer = nil
        textLayer.removeAllAnimations()
        window.orderOut(nil)
    }
}
