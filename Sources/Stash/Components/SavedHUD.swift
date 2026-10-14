import AppKit
import SwiftUI

enum HUDMessage {
    case saved
    case nothingToSave
    case failed(String)

    var text: String {
        switch self {
        case .saved: "Saved to Stash"
        case .nothingToSave: "Nothing to save"
        case .failed(let reason): "Couldn't save: \(reason)"
        }
    }
}

/// The pill shown at the bottom of the screen after saving (design.md §4, "Saved HUD"), like
/// Raycast's "Copied to Clipboard". Fades in, holds, fades out; never takes focus or clicks.
@MainActor
final class HUDController {
    static let shared = HUDController()

    private let window: NSPanel
    private let hostingView = NSHostingView(rootView: SavedHUDView(message: .saved))
    private var transitionID = 0

    private init() {
        window = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        hostingView.sizingOptions = []

        let glass = NSVisualEffectView()
        Glass.configure(glass, cornerRadius: Metrics.hudHeight / 2, style: .circular)
        hostingView.autoresizingMask = [.width, .height]
        glass.addSubview(hostingView)
        window.contentView = glass
    }

    func show(_ message: HUDMessage) {
        transitionID += 1
        let id = transitionID

        hostingView.rootView = SavedHUDView(message: message)
        let size = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: size)
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        window.setFrame(
            NSRect(
                x: (visible.midX - size.width / 2).rounded(),
                y: (visible.minY + Metrics.hudBottomOffset).rounded(),
                width: size.width,
                height: size.height
            ),
            display: true
        )

        if !window.isVisible { window.alphaValue = 0 }
        window.orderFrontRegardless()
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: message.text, .priority: NSAccessibilityPriorityLevel.high.rawValue]
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.hudFadeIn
            window.animator().alphaValue = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Motion.hudFadeIn + Motion.hudHold) { [weak self] in
            guard let self, self.transitionID == id else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Motion.hudFadeOut
                self.window.animator().alphaValue = 0
            } completionHandler: {
                MainActor.assumeIsolated {
                    guard self.transitionID == id else { return }
                    self.window.orderOut(nil)
                }
            }
        }
    }
}

struct SavedHUDView: View {
    let message: HUDMessage

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var icon: (name: String, style: ColorToken) {
        switch message {
        case .saved: ("checkmark.circle.fill", Palette.accent)
        case .nothingToSave: ("minus.circle.fill", Palette.textTertiary)
        case .failed: ("exclamationmark.circle.fill", Palette.danger)
        }
    }

    var body: some View {
        HStack(spacing: Metrics.unit * 2) {
            Image(systemName: icon.name)
                .foregroundStyle(icon.style)
            Text(message.text)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
        }
        .font(Typography.hud)
        .padding(.horizontal, Metrics.hudPadding)
        .frame(height: Metrics.hudHeight)
        .background(reduceTransparency ? Palette.tint.opaque : Palette.tint)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Palette.border, lineWidth: Metrics.borderWidth))
        .accessibilityHidden(true)
    }
}
