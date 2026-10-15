import AppKit
import SwiftUI

/// An invisible AppKit view that starts a real drag session. SwiftUI's `onDrag` can't tell where
/// a drag ended or with which operation, and the shelf needs both to know when an item has left.
struct ShelfDragSource: NSViewRepresentable {
    let writers: () -> [NSPasteboardWriting]
    let image: () -> NSImage?
    let onClick: () -> Void
    /// The operation the drop target chose (empty when cancelled or refused).
    let onEnded: (NSDragOperation) -> Void

    func makeNSView(context: Context) -> DragSourceView {
        let view = DragSourceView()
        update(view)
        return view
    }

    func updateNSView(_ view: DragSourceView, context: Context) {
        update(view)
    }

    private func update(_ view: DragSourceView) {
        view.writers = writers
        view.image = image
        view.onClick = onClick
        view.onEnded = onEnded
    }
}

final class DragSourceView: NSView, NSDraggingSource {
    var writers: () -> [NSPasteboardWriting] = { [] }
    var image: () -> NSImage? = { nil }
    var onClick: () -> Void = {}
    var onEnded: (NSDragOperation) -> Void = { _ in }
    private var mouseDownEvent: NSEvent?

    /// Clicks and drags work even though Stash is never the active app.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = mouseDownEvent else { return }
        let dx = event.locationInWindow.x - down.locationInWindow.x
        let dy = event.locationInWindow.y - down.locationInWindow.y
        guard dx * dx + dy * dy > 9 else { return }
        mouseDownEvent = nil
        let preview = image() ?? NSWorkspace.shared.icon(for: .data)
        let side = min(bounds.width, bounds.height, 96)
        let frame = NSRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
        let items = writers().map { writer -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: writer)
            item.setDraggingFrame(frame, contents: preview)
            return item
        }
        guard !items.isEmpty else { return }
        let session = beginDraggingSession(with: items, event: down, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .stack
    }

    override func mouseUp(with event: NSEvent) {
        if mouseDownEvent != nil { onClick() }
        mouseDownEvent = nil
    }

    // MARK: NSDraggingSource

    /// The drop target decides (Finder: same disk moves, other disk copies, ⌥ copies). No delete:
    /// the Trash refuses shelf items, so an original can't be trashed by accident.
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .link, .generic] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onEnded(operation)
    }
}

/// The strip at the top of the shelf: dragging it moves the window.
struct ShelfMoveHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> MoveHandleView { MoveHandleView() }
    func updateNSView(_ view: MoveHandleView, context: Context) {}
}

final class MoveHandleView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
