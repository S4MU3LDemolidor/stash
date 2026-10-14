#!/usr/bin/env swift
// Generates Support/AppIcon.icns from Support/AppIcon-artwork.png (the app icon's rounded
// square, background removed). The artwork is placed on Apple's macOS icon grid: an 824-px
// rounded square on a 1024-px canvas, with a soft shadow, at every size macOS asks for.
//
// Usage: swift scripts/make-icon.swift   (from the repository root; needs iconutil)
import AppKit

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
guard let artwork = NSImage(contentsOf: root.appending(path: "Support/AppIcon-artwork.png")) else {
    fatalError("Support/AppIcon-artwork.png not found; run from the repository root.")
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.imageInterpolation = .high
    NSGraphicsContext.current = context

    let canvas = CGFloat(size)
    let side = canvas * 824 / 1024
    let rect = NSRect(x: (canvas - side) / 2, y: (canvas - side) / 2 + canvas * 0.008, width: side, height: side)

    // Soft drop shadow, like the system's own icons.
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -canvas * 0.012)
    shadow.shadowBlurRadius = canvas * 0.03
    shadow.set()
    artwork.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "AppIcon-\(UUID().uuidString).iconset")
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(size: points).write(to: iconset.appending(path: "icon_\(points)x\(points).png"))
    try render(size: points * 2).write(to: iconset.appending(path: "icon_\(points)x\(points)@2x.png"))
}

let output = root.appending(path: "Support/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try? fileManager.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(output.path)")
