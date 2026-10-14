import AppKit
import SwiftUI

/// Native vibrancy for Stash's floating windows (design.md §2): blurs what's behind the window.
enum Glass {
    /// Configures `view` as rounded glass. When it's a window's content view, the rounded mask
    /// also shapes the window itself.
    static func configure(_ view: NSVisualEffectView, cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) {
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        // Stash is never the active app; keep the material from dimming to its inactive look.
        view.state = .active
        view.maskImage = mask(radius: cornerRadius, style: style)
        view.wantsLayer = true
    }

    /// A stretchable rounded-rect mask.
    private static func mask(radius: CGFloat, style: RoundedCornerStyle) -> NSImage {
        // Continuous corners blend in over ~1.53× the radius, so the caps need that much room.
        let cap = (radius * (style == .continuous ? 1.6 : 1)).rounded(.up)
        let size = NSSize(width: cap * 2 + 1, height: cap * 2 + 1)
        let image = NSImage(size: size, flipped: false) { rect in
            let shape = RoundedRectangle(cornerRadius: radius, style: style).path(in: rect)
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(shape.cgPath)
            context.setFillColor(.black)
            context.fillPath()
            return true
        }
        image.capInsets = NSEdgeInsets(top: cap, left: cap, bottom: cap, right: cap)
        image.resizingMode = .stretch
        return image
    }
}
