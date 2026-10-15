import AppKit
import SwiftUI

enum HUDMessage {
    case saved
    case copied
    case nothingToSave
    case failed(String)
    case shelfFailed
    /// First launch: how to capture, with the shortcut's keys.
    case welcome(keys: [String])

    var text: String {
        switch self {
        case .saved: "Saved to Stash"
        case .copied: "Copied to Clipboard"
        case .nothingToSave: "Nothing to save"
        case .failed(let reason): "Couldn't save: \(reason)"
        case .shelfFailed: "Couldn't add to the shelf"
        case .welcome(let keys): "Stash is ready. Press \(keys.joined()) to capture."
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
        // The pill's size comes from its content (with no sizing options, fittingSize is zero).
        hostingView.sizingOptions = [.intrinsicContentSize]

        let glass = NSVisualEffectView()
        Glass.configure(glass, cornerRadius: Metrics.hudHeight / 2, style: .circular)
        glass.addSubview(hostingView)
        window.contentView = glass
    }

    func show(_ message: HUDMessage, hold: TimeInterval = Motion.hudHold) {
        transitionID += 1
        let id = transitionID

        hostingView.rootView = SavedHUDView(message: message)
        let size = hostingView.fittingSize
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        window.setFrame(
            NSRect(
                x: (visible.midX - size.width / 2).rounded(),
                y: (visible.minY + Metrics.hudBottomOffset).rounded(),
                width: size.width,
                height: size.height
            ),
            display: false
        )
        // Size the window first, then fit the content to it (autoresizing from a zero-sized
        // window would stretch the content twice).
        hostingView.frame = window.contentView?.bounds ?? NSRect(origin: .zero, size: size)
        window.display()

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
        DispatchQueue.main.asyncAfter(deadline: .now() + Motion.hudFadeIn + hold) { [weak self] in
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
        case .saved, .copied: ("checkmark.circle.fill", Palette.accent)
        case .welcome: ("", Palette.accent)
        case .nothingToSave: ("minus.circle.fill", Palette.textTertiary)
        case .failed, .shelfFailed: ("exclamationmark.circle.fill", Palette.danger)
        }
    }

    var body: some View {
        HStack(spacing: Metrics.unit * 2) {
            if case .welcome = message {
                // The mark in the logo's colors.
                Image(nsImage: StashMark.image(height: Metrics.glyphSize, colors: StashMark.Colors()))
            } else {
                Image(systemName: icon.name)
                    .foregroundStyle(icon.style)
            }
            if case .welcome(let keys) = message {
                Text("Stash is ready. Press").foregroundStyle(Palette.textPrimary)
                Keycaps(keys: keys)
                Text("to capture").foregroundStyle(Palette.textPrimary)
            } else {
                Text(message.text)
                    .foregroundStyle(Palette.textPrimary)
            }
        }
        .lineLimit(1)
        // Always one line at its natural width; the window is sized to fit.
        .fixedSize()
        .font(Typography.hud)
        .padding(.horizontal, Metrics.hudPadding)
        .frame(height: Metrics.hudHeight)
        .background(reduceTransparency ? Palette.tint.opaque : Palette.tint)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Palette.border, lineWidth: Metrics.borderWidth))
        .accessibilityHidden(true)
    }
}
