import AppKit

/// Watches mouse drags in other apps and reports a shake while something is being dragged.
///
/// Global monitors for mouse events don't need the Accessibility permission (only key events do).
/// A drag-and-drop session writes the system drag pasteboard when it starts; selecting text or
/// moving a window doesn't, so the pasteboard's change count tells a real drag from a plain one.
@MainActor
final class DragMonitor {
    /// A shake happened at this point (screen coordinates).
    var onShake: ((NSPoint) -> Void)?
    /// The mouse button came up after a drag with content.
    var onDragEnded: (() -> Void)?

    private var monitors: [Any] = []
    private var detector = ShakeDetector()
    private var dragChangeCount = NSPasteboard(name: .drag).changeCount
    private var dragging = false

    var isRunning: Bool { !monitors.isEmpty }

    func start() {
        guard monitors.isEmpty else { return }
        dragChangeCount = NSPasteboard(name: .drag).changeCount
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.dragged(event) }
        }) {
            monitors.append(monitor)
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseUp() }
        }) {
            monitors.append(monitor)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        detector.reset()
        dragging = false
    }

    private func dragged(_ event: NSEvent) {
        let count = NSPasteboard(name: .drag).changeCount
        if count != dragChangeCount {
            dragChangeCount = count
            dragging = true
            detector.reset()
        }
        guard dragging else { return }
        let location = NSEvent.mouseLocation
        if detector.add(location, at: event.timestamp) {
            onShake?(location)
        }
    }

    private func mouseUp() {
        if dragging { onDragEnded?() }
        dragging = false
        detector.reset()
    }
}
