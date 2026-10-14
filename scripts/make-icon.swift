#!/usr/bin/env swift
// Generates Support/AppIcon.icns (design.md §6): a near-black rounded square with a single
// amber tray-and-arrow glyph. The glyph is drawn here, not taken from SF Symbols, whose
// license doesn't allow them in app icons.
//
// Usage: swift scripts/make-icon.swift   (from the repository root; needs iconutil)
import AppKit

let amber = NSColor(srgbRed: 0xF5 / 255, green: 0xA5 / 255, blue: 0x24 / 255, alpha: 1)

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: the rounded square takes ~80% of the canvas.
    let canvas = CGFloat(size)
    let inset = canvas * 0.1
    let rect = NSRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
    let radius = rect.width * 0.225
    let square = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSGradient(
        starting: NSColor(srgbRed: 0.17, green: 0.17, blue: 0.19, alpha: 1),
        ending: NSColor(srgbRed: 0.07, green: 0.07, blue: 0.08, alpha: 1)
    )!.draw(in: square, angle: -90)

    // The glyph, in coordinates relative to the square (0…1, y up).
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }
    let tray = NSBezierPath()
    tray.move(to: point(0.22, 0.52))
    tray.line(to: point(0.22, 0.28))
    tray.line(to: point(0.78, 0.28))
    tray.line(to: point(0.78, 0.52))

    let lip = NSBezierPath()
    lip.move(to: point(0.22, 0.42))
    lip.line(to: point(0.37, 0.42))
    lip.line(to: point(0.42, 0.355))
    lip.line(to: point(0.58, 0.355))
    lip.line(to: point(0.63, 0.42))
    lip.line(to: point(0.78, 0.42))

    let arrow = NSBezierPath()
    arrow.move(to: point(0.5, 0.78))
    arrow.line(to: point(0.5, 0.49))
    arrow.move(to: point(0.39, 0.60))
    arrow.line(to: point(0.5, 0.49))
    arrow.line(to: point(0.61, 0.60))

    amber.setStroke()
    for path in [tray, lip, arrow] {
        path.lineWidth = max(1, rect.width * 0.065)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fileManager = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "AppIcon-\(UUID().uuidString).iconset")
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(size: points).write(to: iconset.appending(path: "icon_\(points)x\(points).png"))
    try render(size: points * 2).write(to: iconset.appending(path: "icon_\(points)x\(points)@2x.png"))
}

let output = URL(fileURLWithPath: fileManager.currentDirectoryPath).appending(path: "Support/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try? fileManager.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(output.path)")
