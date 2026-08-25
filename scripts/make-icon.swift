#!/usr/bin/env swift
// Draws the ONN app icon and writes dist/ONN.icns.
//
//   swift scripts/make-icon.swift [output.icns]
//
// Generated rather than checked in as a binary, so the mark stays editable and
// the build has a single source of truth for the brand.
import AppKit

let barRed = NSColor(srgbRed: 0.62, green: 0.04, blue: 0.06, alpha: 1)
let badgeRed = NSColor(srgbRed: 0.85, green: 0.09, blue: 0.11, alpha: 1)

func drawIcon(_ px: Int) -> Data {
    let size = CGFloat(px)
    guard let ctx = CGContext(
        data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
    else { fatalError("could not create bitmap context at \(px)px") }

    let prior = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    defer { NSGraphicsContext.current = prior }

    // macOS icon grid: artwork inset from the canvas, generous corner radius.
    let inset = size * 0.055
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let squircle = NSBezierPath(roundedRect: rect,
                                xRadius: rect.width * 0.2237,
                                yRadius: rect.width * 0.2237)

    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()

    // Vertical gradient body.
    NSGradient(starting: badgeRed, ending: barRed)?.draw(in: rect, angle: -90)

    // Ticker band across the lower third, echoing the on-screen bar.
    let bandHeight = rect.height * 0.20
    let band = CGRect(x: rect.minX, y: rect.minY + rect.height * 0.13,
                      width: rect.width, height: bandHeight)
    NSColor(white: 0, alpha: 0.28).setFill()
    band.fill()
    NSColor(white: 1, alpha: 0.5).setFill()
    CGRect(x: rect.minX, y: band.maxY - size * 0.008,
           width: rect.width, height: size * 0.008).fill()

    // "ONN" wordmark, sized to the artwork width.
    let mark = "ONN"
    var fontSize = rect.width * 0.42
    var attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
        .foregroundColor: NSColor.white,
        .kern: fontSize * 0.02,
    ]
    // Shrink until it fits with margin, rather than trusting one magic ratio.
    while NSAttributedString(string: mark, attributes: attrs).size().width > rect.width * 0.78 {
        fontSize -= 1
        attrs[.font] = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
        attrs[.kern] = fontSize * 0.02
    }
    let text = NSAttributedString(string: mark, attributes: attrs)
    let textSize = text.size()
    text.draw(at: CGPoint(x: rect.midX - textSize.width / 2,
                          y: rect.midY - textSize.height / 2 + rect.height * 0.08))

    NSGraphicsContext.current?.restoreGraphicsState()

    guard let cgImage = ctx.makeImage(),
          let png = NSBitmapImageRep(cgImage: cgImage)
              .representation(using: .png, properties: [:])
    else { fatalError("could not encode PNG at \(px)px") }
    return png
}

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist/ONN.icns"
let iconset = URL(fileURLWithPath: "dist/ONN.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// (point size, scale) pairs Apple's iconutil expects.
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
                        (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    try drawIcon(points * scale).write(to: iconset.appendingPathComponent(name))
}

let convert = Process()
convert.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
convert.arguments = ["-c", "icns", iconset.path, "-o", output]
try convert.run()
convert.waitUntilExit()
guard convert.terminationStatus == 0 else { exit(convert.terminationStatus) }
try? FileManager.default.removeItem(at: iconset)
print("wrote \(output)")
