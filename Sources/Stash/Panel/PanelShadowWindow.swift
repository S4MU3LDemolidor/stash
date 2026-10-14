import AppKit
import QuartzCore

/// Draws the panel's drop shadow (design.md §2: `0 20 60 rgba(0,0,0,0.45)`).
///
/// macOS draws no system shadow for the borderless vibrancy panel, so the shadow lives in its
/// own click-through window ordered just below the panel. Keeping it out of the panel window
/// means clicks right next to the panel still reach the app underneath.
final class PanelShadowWindow: NSPanel {
    /// How far the shadow extends past the panel on each side.
    static let margins = NSEdgeInsets(
        top: Metrics.shadowBlur - Metrics.shadowOffsetY,
        left: Metrics.shadowBlur,
        bottom: Metrics.shadowBlur + Metrics.shadowOffsetY,
        right: Metrics.shadowBlur
    )

    private let shadowLayer = CALayer()
    private let cutout = CAShapeLayer()

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        animationBehavior = .none

        let view = NSView()
        view.wantsLayer = true
        shadowLayer.shadowColor = NSColor.black.cgColor
        shadowLayer.shadowOpacity = Float(Metrics.shadowOpacity)
        // CSS blur radius ≈ 2 × Core Animation shadow radius. Negative y casts downwards.
        shadowLayer.shadowRadius = Metrics.shadowBlur / 2
        shadowLayer.shadowOffset = CGSize(width: 0, height: -Metrics.shadowOffsetY)
        // Keep the area under the panel clear so the shadow can't tint the panel's glass.
        cutout.fillRule = .evenOdd
        shadowLayer.mask = cutout
        view.layer?.addSublayer(shadowLayer)
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Positions the shadow around a panel occupying `panelFrame` (screen coordinates).
    func layout(around panelFrame: NSRect) {
        let m = Self.margins
        let frame = NSRect(
            x: panelFrame.minX - m.left,
            y: panelFrame.minY - m.bottom,
            width: panelFrame.width + m.left + m.right,
            height: panelFrame.height + m.top + m.bottom
        )
        setFrame(frame, display: false)

        let bounds = CGRect(origin: .zero, size: frame.size)
        let panelRect = CGRect(x: m.left, y: m.bottom, width: panelFrame.width, height: panelFrame.height)
        let shape = CGPath(
            roundedRect: panelRect,
            cornerWidth: Metrics.panelCornerRadius,
            cornerHeight: Metrics.panelCornerRadius,
            transform: nil
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shadowLayer.frame = bounds
        shadowLayer.shadowPath = shape
        cutout.frame = bounds
        let maskPath = CGMutablePath()
        maskPath.addRect(bounds)
        maskPath.addPath(shape)
        cutout.path = maskPath
        CATransaction.commit()
    }
}
