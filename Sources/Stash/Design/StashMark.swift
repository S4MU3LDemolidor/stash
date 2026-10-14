import AppKit

/// The Stash mark: three cards dropping into a tray, drawn as vectors from the logo's geometry
/// so it stays sharp at menu bar sizes. Monochrome it's a template image (the menu bar, the
/// action bar); in color it matches the logo (the welcome hint).
enum StashMark {
    /// The logo's geometry, in its own units (y up). Measured from docs/brand/logo.png.
    private static let canvas = CGSize(width: 321, height: 375)

    /// Bottom to top. Each card is a rounded quadrilateral: left, top, right, bottom corner.
    private static let cards: [[CGPoint]] = [
        [CGPoint(x: 62, y: 165), CGPoint(x: 113, y: 199), CGPoint(x: 249, y: 137), CGPoint(x: 186, y: 77)],
        [CGPoint(x: 72, y: 239), CGPoint(x: 126, y: 282), CGPoint(x: 273, y: 232), CGPoint(x: 210, y: 171)],
        [CGPoint(x: 83, y: 316), CGPoint(x: 144, y: 375), CGPoint(x: 276, y: 328), CGPoint(x: 219, y: 266)],
    ]

    /// The tray, clockwise from the top of the left wall, with each corner's radius.
    private static let tray: [(CGPoint, CGFloat)] = [
        (CGPoint(x: 53, y: 135), 6), (CGPoint(x: 53, y: 82), 6), (CGPoint(x: 108, y: 82), 6),
        (CGPoint(x: 128, y: 47), 8), (CGPoint(x: 183, y: 47), 8), (CGPoint(x: 203, y: 82), 6),
        (CGPoint(x: 269, y: 82), 6), (CGPoint(x: 269, y: 135), 6), (CGPoint(x: 321, y: 135), 30),
        (CGPoint(x: 321, y: 0), 30), (CGPoint(x: 0, y: 0), 30), (CGPoint(x: 0, y: 135), 30),
    ]

    /// The logo's colors, top card to tray.
    struct Colors {
        var top = NSColor(srgbRed: 1.00, green: 0.83, blue: 0.40, alpha: 1)
        var middle = NSColor(srgbRed: 0.97, green: 0.67, blue: 0.09, alpha: 1)
        var bottom = NSColor(srgbRed: 0.97, green: 0.49, blue: 0.08, alpha: 1)
    }

    /// The mark `height` points tall. Without `colors` it's a template image (macOS tints it).
    static func image(height: CGFloat, colors: Colors? = nil) -> NSImage {
        let size = NSSize(width: (height * canvas.width / canvas.height).rounded(.up), height: height)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            draw(in: rect, context: context, colors: colors)
            return true
        }
        image.isTemplate = colors == nil
        image.accessibilityDescription = "Stash"
        return image
    }

    private static func draw(in rect: CGRect, context: CGContext, colors: Colors?) {
        let scale = min(rect.width / canvas.width, rect.height / canvas.height)
        context.translateBy(
            x: rect.midX - canvas.width * scale / 2,
            y: rect.midY - canvas.height * scale / 2
        )
        context.scaleBy(x: scale, y: scale)
        // Keep a visible gap between shapes even at 16 pt (about 0.9 pt, at least 18 units).
        let gap = max(18, 0.9 / scale)

        let fills = colors.map { [$0.bottom, $0.middle, $0.top] } ?? [.black, .black, .black]
        context.setFillColor((colors?.bottom ?? .black).cgColor)
        context.addPath(roundedPolygon(tray))
        context.fillPath()

        for (card, fill) in zip(cards, fills) {
            let path = roundedPolygon(grown(card).map { ($0, 22) })
            // Cut a gap around the card first, so it reads separately from what's below.
            context.saveGState()
            context.setBlendMode(.clear)
            context.setLineWidth(gap * 2)
            context.setLineJoin(.round)
            context.addPath(path)
            context.strokePath()
            context.restoreGState()

            context.setFillColor(fill.cgColor)
            context.addPath(path)
            context.fillPath()
        }
    }

    /// The measured corners sit on the rounded edge; push them out so the rounded card keeps
    /// the logo's size.
    private static func grown(_ corners: [CGPoint], by factor: CGFloat = 1.07) -> [CGPoint] {
        let center = CGPoint(
            x: corners.map(\.x).reduce(0, +) / CGFloat(corners.count),
            y: corners.map(\.y).reduce(0, +) / CGFloat(corners.count)
        )
        return corners.map { CGPoint(x: center.x + ($0.x - center.x) * factor, y: center.y + ($0.y - center.y) * factor) }
    }

    private static func roundedPolygon(_ corners: [(CGPoint, CGFloat)]) -> CGPath {
        let path = CGMutablePath()
        let count = corners.count
        let start = CGPoint(
            x: (corners[count - 1].0.x + corners[0].0.x) / 2,
            y: (corners[count - 1].0.y + corners[0].0.y) / 2
        )
        path.move(to: start)
        for index in 0..<count {
            let (corner, radius) = corners[index]
            path.addArc(tangent1End: corner, tangent2End: corners[(index + 1) % count].0, radius: radius)
        }
        path.closeSubpath()
        return path
    }
}
