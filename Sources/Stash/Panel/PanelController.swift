import AppKit
import QuartzCore
import SwiftUI

/// Shows, positions, animates and hides the panel.
@MainActor
final class PanelController: NSObject {
    let state = PanelState()

    /// The app that was frontmost when the panel opened: what Capture reads from (M3).
    private(set) var sourceApp: NSRunningApplication?

    private let panel = StashPanel()
    private let effectView = NSVisualEffectView()
    /// Bumped on every show/hide so a stale close animation can't hide a re-opened panel.
    private var transitionID = 0
    private(set) var isShown = false

    override init() {
        super.init()
        configureContent()
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide() }
    }

    // MARK: Public

    /// Shortcut behavior: closes the panel if it's already showing `mode`,
    /// switches to `mode` if it's showing the other one, opens it otherwise.
    func toggle(_ mode: PanelMode) {
        guard isShown else { return show(mode) }
        if state.mode == mode {
            hide()
        } else {
            switchMode(to: mode)
        }
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        transitionID += 1
        let id = transitionID

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.panelClose
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.transitionID == id else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
            }
        }
    }

    // MARK: Private

    private func show(_ mode: PanelMode) {
        isShown = true
        transitionID += 1

        // Read before showing: this is the app (usually a browser) that Capture reads from.
        let frontmost = NSWorkspace.shared.frontmostApplication
        sourceApp = frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : frontmost

        state.prepareForShow(mode: mode)
        panel.setFrame(frame(for: mode, on: screenWithMouse()), display: false)

        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()

        if !reduceMotion {
            addScaleInAnimation()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.panelOpen
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.panel.invalidateShadow() }
        }
    }

    /// Keys forwarded by the search field. Returns whether the key was handled.
    private func handle(_ command: PanelKeyCommand) -> Bool {
        switch command {
        case .cancel:
            hide()
            return true
        case .tab:
            switchMode(to: state.mode == .capture ? .library : .capture)
            return true
        case .submit:
            // Save (Capture) and Open (Library) arrive in M3/M4. Swallow it so the field keeps focus.
            return true
        case .moveUp, .moveDown:
            return false
        }
    }

    private func switchMode(to mode: PanelMode) {
        state.mode = mode
        // Keep the top edge fixed; the panel grows or shrinks downwards.
        var frame = panel.frame
        frame.origin.y = frame.maxY - mode.height
        frame.size.height = mode.height
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    private func configureContent() {
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        // Stash is never the active app, so keep the material from dimming to its inactive look.
        effectView.state = .active
        // As the window's content view, the effect view's mask also shapes the window and its shadow.
        effectView.maskImage = Self.cornerMask(radius: Metrics.panelCornerRadius)
        effectView.wantsLayer = true

        let rootView = PanelRootView(state: state) { [weak self] command in
            self?.handle(command) ?? false
        }
        let hostingView = NSHostingView(rootView: rootView)
        // The controller sizes the panel; don't let SwiftUI push window size constraints.
        hostingView.sizingOptions = []
        hostingView.frame = effectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        effectView.addSubview(hostingView)

        panel.contentView = effectView
    }

    /// Scales the panel's content from 0.98 to 1 around its center (Reduce Motion skips this).
    private func addScaleInAnimation() {
        guard let layer = effectView.layer else { return }
        let size = effectView.bounds.size
        let scale = Motion.panelOpenScale
        // Layer-backed views anchor at the bottom-left, so scale around the center explicitly.
        var from = CATransform3DMakeTranslation(size.width / 2, size.height / 2, 0)
        from = CATransform3DScale(from, scale, scale, 1)
        from = CATransform3DTranslate(from, -size.width / 2, -size.height / 2, 0)

        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = from
        animation.toValue = CATransform3DIdentity
        animation.duration = Motion.panelOpen
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: "scaleIn")
    }

    /// A stretchable rounded-rect mask with continuous (squircle) corners.
    private static func cornerMask(radius: CGFloat) -> NSImage {
        // Continuous corners blend in over ~1.53× the radius, so the caps need that much room.
        let cap = (radius * 1.6).rounded(.up)
        let size = NSSize(width: cap * 2 + 1, height: cap * 2 + 1)
        let image = NSImage(size: size, flipped: false) { rect in
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
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

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func screenWithMouse() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    /// Horizontally centered on the screen, top edge ~22% down the visible frame.
    private func frame(for mode: PanelMode, on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let width = Metrics.panelWidth
        let height = mode.height
        let top = visible.maxY - visible.height * Metrics.panelTopOffset
        return NSRect(
            x: (visible.midX - width / 2).rounded(),
            y: (top - height).rounded(),
            width: width,
            height: height
        )
    }
}

// MARK: - NSWindowDelegate

extension PanelController: NSWindowDelegate {
    /// Clicking anywhere outside the panel makes it lose key status: close it.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
