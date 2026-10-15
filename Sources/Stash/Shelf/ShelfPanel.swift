import AppKit

/// The shelf's window: borderless, non-activating, floating on every Space (like `StashPanel`),
/// but it never takes keyboard focus; everything happens with the mouse.
final class ShelfPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.shelfWidth, height: Metrics.shelfCollapsedHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        isOpaque = false
        backgroundColor = .clear
        // Like the main panel: macOS draws no usable shadow here, PanelShadowWindow does.
        hasShadow = false
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The shelf's glass, which also accepts drops.
final class ShelfContentView: NSVisualEffectView {
    var onTargetedChange: ((Bool) -> Void)?
    var onDrop: ((NSPasteboard) -> Bool)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes(ShelfPasteboard.acceptedTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // An item being dragged out of the shelf doesn't drop back in.
        guard !(sender.draggingSource is DragSourceView),
              sender.draggingPasteboard.availableType(from: ShelfPasteboard.acceptedTypes) != nil
        else { return [] }
        onTargetedChange?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetedChange?(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onTargetedChange?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargetedChange?(false)
        return onDrop?(sender.draggingPasteboard) ?? false
    }
}
