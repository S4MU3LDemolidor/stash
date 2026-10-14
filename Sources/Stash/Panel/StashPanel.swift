import AppKit

/// The floating panel. Borderless and non-activating: it takes keyboard focus without
/// activating Stash, so the browser underneath stays the active app (design.md §1, §2).
final class StashPanel: NSPanel {
    /// Called on Esc when nothing inside the panel handled it.
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.panelWidth, height: Metrics.captureHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
        // Open/close animations are our own (PanelController).
        animationBehavior = .none

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    /// The browser underneath looks active, so ⌘Q / ⌘H here are almost certainly meant for it,
    /// not for Stash. Swallow them instead of quitting or hiding Stash.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command, let key = event.charactersIgnoringModifiers, ["q", "h"].contains(key) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
