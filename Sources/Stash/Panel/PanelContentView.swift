import AppKit

/// The panel's glass background, which also accepts anything dropped on the panel
/// (files, images, links, text) for Capture.
final class PanelContentView: NSVisualEffectView {
    var onDropTargetChanged: ((Bool) -> Void)?
    /// Returns whether the dropped content could be captured.
    var onDrop: ((NSPasteboard) -> Bool)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes(ClipboardReader.acceptedTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.availableType(from: ClipboardReader.acceptedTypes) != nil else { return [] }
        onDropTargetChanged?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDropTargetChanged?(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onDropTargetChanged?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDropTargetChanged?(false)
        return onDrop?(sender.draggingPasteboard) ?? false
    }
}
