import AppKit
import Combine
import SwiftUI

/// Shows, sizes and positions the shelf, takes drops, and takes items off once they've been
/// dragged out (unless ⌥ was held). The shelf stays on screen while it holds anything.
@MainActor
final class ShelfController: NSObject, NSWindowDelegate {
    let store: ShelfStore
    private let state = ShelfViewState()
    private let thumbnails = ShelfThumbnails()
    private let panel = ShelfPanel()
    private let shadowWindow = PanelShadowWindow()
    private var cancellables = Set<AnyCancellable>()
    private var isShown = false
    private var hideWork: DispatchWorkItem?

    init(store: ShelfStore) {
        self.store = store
        super.init()

        let content = ShelfContentView(frame: NSRect(origin: .zero, size: panel.frame.size))
        Glass.configure(content, cornerRadius: Metrics.panelCornerRadius)
        content.onTargetedChange = { [weak self] in self?.state.dropTargeted = $0 }
        content.onDrop = { [weak self] in self?.accept($0) ?? false }
        let hosting = NSHostingView(rootView: ShelfView(store: store, state: state, thumbnails: thumbnails, actions: actions))
        hosting.frame = content.bounds
        hosting.autoresizingMask = [.width, .height]
        content.addSubview(hosting)
        panel.contentView = content
        panel.delegate = self
        panel.setAccessibilityLabel("Shelf")

        shadowWindow.level = panel.level
        shadowWindow.collectionBehavior = panel.collectionBehavior

        store.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in self?.itemsChanged(items) }
            .store(in: &cancellables)
    }

    // MARK: Showing

    /// Opens the shelf centered on `point` (screen coordinates), or moves it there.
    func show(at point: NSPoint) {
        hideWork?.cancel()
        let size = targetSize
        place(NSRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height))
        present()
    }

    /// At launch: a shelf that still holds items comes back where it was.
    func restore() {
        guard !store.items.isEmpty else { return }
        let size = targetSize
        if let origin = Preferences.shelfOrigin {
            place(NSRect(origin: origin, size: size))
            present()
        } else if let screen = NSScreen.main {
            show(at: NSPoint(x: screen.visibleFrame.maxX - size.width, y: screen.visibleFrame.midY))
        }
    }

    /// A drag ended somewhere. An empty shelf (shaken open, then not used) fades out.
    func dragEnded() {
        scheduleHideIfEmpty()
    }

    /// Takes a drop (on the shelf or on the menu bar icon). Returns whether anything was added.
    @discardableResult
    func accept(_ pasteboard: NSPasteboard) -> Bool {
        let promises = ShelfPasteboard.promises(in: pasteboard)
        if !promises.isEmpty {
            receive(promises)
            return true
        }
        do {
            let items = try ShelfPasteboard.items(from: pasteboard, store: store)
            guard !items.isEmpty else { return false }
            store.add(items)
            return true
        } catch {
            HUDController.shared.show(.shelfFailed)
            return false
        }
    }

    // MARK: Actions from the view

    private var actions: ShelfActions {
        ShelfActions(
            writers: { [weak self] items in
                guard let self else { return [] }
                return ShelfPasteboard.writers(for: items, store: self.store)
            },
            dragEnded: { [weak self] items, operation in self?.dragged(items, operation: operation) },
            toggleExpanded: { [weak self] in self?.toggleExpanded() },
            clear: { [weak self] in self?.clear() },
            remove: { [weak self] item in self?.store.remove([item.id]) },
            fileURL: { [weak self] item in self?.store.fileURL(for: item) },
            isMissing: { [weak self] item in self?.store.isMissing(item) ?? true }
        )
    }

    private func dragged(_ items: [ShelfItem], operation: NSDragOperation) {
        // Cancelled or refused: everything stays. ⌥ held: the drop made a copy, keep ours too.
        guard !operation.isEmpty, !NSEvent.modifierFlags.contains(.option) else { return }
        store.remove(Set(items.map(\.id)))
    }

    private func toggleExpanded() {
        state.expanded.toggle()
        resize(animated: true)
    }

    private func clear() {
        if store.holdsPrivateCopies {
            let alert = NSAlert()
            alert.messageText = "Clear the shelf?"
            alert.informativeText = "Some items exist only on the shelf (things dragged from a browser or another app) and will be deleted. Your files stay where they are."
            alert.addButton(withTitle: "Clear")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate()
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        store.clear()
    }

    // MARK: Promised files

    private func receive(_ promises: [NSFilePromiseReceiver]) {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        for receiver in promises {
            let folder: URL
            do {
                folder = try store.makePromiseFolder()
            } catch {
                HUDController.shared.show(.shelfFailed)
                continue
            }
            receiver.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: queue) { [weak self] url, error in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        if error != nil {
                            try? FileManager.default.removeItem(at: folder)
                            HUDController.shared.show(.shelfFailed)
                        } else {
                            self.store.addReceivedFile(url)
                        }
                    }
                }
            }
        }
    }

    // MARK: Layout

    private func itemsChanged(_ items: [ShelfItem]) {
        thumbnails.keep(only: Set(items.map(\.id)))
        for item in items { thumbnails.load(item, url: store.fileURL(for: item)) }
        if items.isEmpty {
            state.expanded = false
            hide()
        } else if isShown {
            resize(animated: true)
        }
    }

    private var targetSize: NSSize {
        guard state.expanded else { return NSSize(width: Metrics.shelfWidth, height: Metrics.shelfCollapsedHeight) }
        let rows = CGFloat(min(max(store.items.count, 1), Metrics.shelfMaxVisibleRows))
        return NSSize(width: Metrics.shelfExpandedWidth, height: Metrics.shelfHeaderHeight + rows * Metrics.shelfRowHeight + Metrics.contentInset)
    }

    /// Keeps the top-left corner where it is.
    private func resize(animated: Bool) {
        let old = panel.frame
        let size = targetSize
        let frame = clamped(NSRect(x: old.minX, y: old.maxY - size.height, width: size.width, height: size.height))
        if animated, isShown, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Motion.modeSwitch
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
        shadowWindow.layout(around: frame)
    }

    private func place(_ frame: NSRect) {
        let frame = clamped(frame)
        panel.setFrame(frame, display: true)
        shadowWindow.layout(around: frame)
        Preferences.shelfOrigin = frame.origin
    }

    /// Pulls the frame onto the screen it's mostly on (or the main screen if that one is gone).
    private func clamped(_ frame: NSRect) -> NSRect {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return frame }
        var result = frame
        result.origin.x = min(max(result.minX, visible.minX + 8), visible.maxX - result.width - 8)
        result.origin.y = min(max(result.minY, visible.minY + 8), visible.maxY - result.height - 8)
        return result
    }

    private func present() {
        guard !isShown else { return }
        isShown = true
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let final = panel.frame
        panel.alphaValue = 0
        shadowWindow.alphaValue = 0
        if !reduceMotion {
            panel.setFrame(final.insetBy(dx: final.width * 0.06, dy: final.height * 0.06), display: false)
        }
        panel.orderFrontRegardless()
        panel.addChildWindow(shadowWindow, ordered: .below)
        shadowWindow.layout(around: final)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.shelfAppear
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            shadowWindow.animator().alphaValue = 1
            if !reduceMotion { panel.animator().setFrame(final, display: true) }
        }
    }

    private func hide() {
        guard isShown else { return }
        isShown = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.hudFadeOut
            panel.animator().alphaValue = 0
            shadowWindow.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isShown else { return }
                self.panel.removeChildWindow(self.shadowWindow)
                self.shadowWindow.orderOut(nil)
                self.panel.orderOut(nil)
            }
        }
    }

    private func scheduleHideIfEmpty() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.store.items.isEmpty else { return }
                self.hide()
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Motion.shelfEmptyGrace, execute: work)
    }

    // MARK: NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        shadowWindow.layout(around: panel.frame)
        Preferences.shelfOrigin = panel.frame.origin
    }

    // MARK: Debug

    #if DEBUG
    func setExpanded(_ expanded: Bool) {
        guard state.expanded != expanded else { return }
        toggleExpanded()
    }
    #endif
}
