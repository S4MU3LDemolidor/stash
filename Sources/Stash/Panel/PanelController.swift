import AppKit
import QuartzCore
import SwiftUI

/// Shows, positions, animates and hides the panel. Keyboard handling lives in
/// `PanelController+Keys.swift`.
@MainActor
final class PanelController: NSObject {
    let state = PanelState()
    let capture = CaptureController()
    let libraryController = LibraryController()
    let enricher = Enricher()

    var library: LibraryStore? {
        didSet {
            capture.library = library
            capture.enricher = enricher
            libraryController.library = library
            enricher.library = library
            MetadataFetcher.shared.hasSiteIcon = { [weak library] site in library?.siteIconURL(for: site) != nil }
        }
    }

    /// The app that was frontmost when the panel opened: what Capture reads from.
    private(set) var sourceApp: NSRunningApplication?

    private let panel = StashPanel()
    private let shadowWindow = PanelShadowWindow()
    private let contentView = PanelContentView()
    /// Bumped on every show/hide so a stale close animation can't hide a re-opened panel.
    private var transitionID = 0
    private(set) var isShown = false
    /// Whether Capture has looked for something to save since the panel opened.
    private var captureStarted = false

    override init() {
        super.init()
        configureContent()
        panel.delegate = self
        panel.onCancel = { [weak self] in _ = self?.handle(.cancel) }
        panel.onKeyEquivalent = { [weak self] event in self?.handleKeyEquivalent(event) ?? false }
        state.onNoteChange = { [weak self] note in self?.capture.noteChanged(note) }
        libraryController.onDismiss = { [weak self] in self?.hide() }
        libraryController.onRefocus = { [weak self] in self?.state.refocus() }
        shadowWindow.level = panel.level
        shadowWindow.collectionBehavior = panel.collectionBehavior
    }

    // MARK: Showing and hiding

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
            shadowWindow.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.transitionID == id else { return }
                self.panel.removeChildWindow(self.shadowWindow)
                self.shadowWindow.orderOut(nil)
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
            }
        }
    }

    private func show(_ mode: PanelMode) {
        isShown = true
        transitionID += 1

        // Read before showing: this is the app (usually a browser) that Capture reads from.
        let frontmost = NSWorkspace.shared.frontmostApplication
        sourceApp = frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : frontmost

        state.prepareForShow(mode: mode)
        updateAccessibilityTitle(for: mode)
        captureStarted = false
        capture.reset()
        libraryController.reset()
        if mode == .capture { startCapture() }

        let frame = frame(for: mode, on: screenWithMouse())
        panel.setFrame(frame, display: false)
        shadowWindow.layout(around: frame)

        panel.alphaValue = 0
        shadowWindow.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        panel.addChildWindow(shadowWindow, ordered: .below)

        if !reduceMotion {
            addScaleInAnimation()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.panelOpen
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            shadowWindow.animator().alphaValue = 1
        }
    }

    func switchMode(to mode: PanelMode) {
        guard mode != state.mode else { return }
        libraryController.closeActionMenu()
        state.mode = mode
        state.refocus()
        updateAccessibilityTitle(for: mode)
        if mode == .capture, !captureStarted { startCapture() }

        // Keep the top edge fixed; the panel grows or shrinks downwards (150 ms, design.md §7).
        var frame = panel.frame
        frame.origin.y = frame.maxY - mode.height
        frame.size.height = mode.height
        guard !reduceMotion else {
            panel.setFrame(frame, display: true)
            shadowWindow.layout(around: frame)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.modeSwitch
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.shadowWindow.layout(around: frame) }
        }
    }

    /// Click on a row or grid cell: select it; double-click opens it.
    private func handleClick(_ reference: Reference) {
        libraryController.selectedID = reference.id
        if NSApp.currentEvent?.clickCount == 2 {
            libraryController.open(reference, atTimestamp: false)
        } else {
            // Clicking the list must not take typing away from the search field.
            state.refocus()
        }
    }

    var windowNumber: Int { panel.windowNumber }

    /// Whether text is selected in the focused text field (then ⌘C copies that text).
    var hasSelectedText: Bool {
        ((panel.firstResponder as? NSTextView)?.selectedRange().length ?? 0) > 0
    }

    /// VoiceOver announces the panel as "Stash Capture" or "Stash Library".
    private func updateAccessibilityTitle(for mode: PanelMode) {
        panel.setAccessibilityTitle(mode == .capture ? "Stash Capture" : "Stash Library")
    }

    private func startCapture() {
        captureStarted = true
        capture.begin(sourceApp: sourceApp)
    }

    /// Something was dropped on the panel: it becomes the capture, whatever mode was showing.
    private func handleDrop(_ pasteboard: NSPasteboard) -> Bool {
        captureStarted = true
        if state.mode != .capture { switchMode(to: .capture) }
        return capture.drop(pasteboard)
    }

    // MARK: Setup

    private func configureContent() {
        Glass.configure(contentView, cornerRadius: Metrics.panelCornerRadius)
        contentView.onDropTargetChanged = { [weak self] targeted in self?.capture.isDropTargeted = targeted }
        contentView.onDrop = { [weak self] pasteboard in self?.handleDrop(pasteboard) ?? false }

        let rootView = PanelRootView(
            state: state,
            capture: capture,
            library: libraryController,
            enricher: enricher,
            onCommand: { [weak self] command in self?.handle(command) ?? false },
            onMenuCommand: { [weak self] command in self?.handleMenu(command) ?? false },
            onClick: { [weak self] reference in self?.handleClick(reference) }
        )
        let hostingView = NSHostingView(rootView: rootView)
        // The controller sizes the panel; don't let SwiftUI push window size constraints.
        hostingView.sizingOptions = []
        hostingView.frame = contentView.bounds
        hostingView.autoresizingMask = [.width, .height]
        contentView.addSubview(hostingView)

        panel.contentView = contentView
    }

    /// Scales the panel's content from 0.98 to 1 around its center (Reduce Motion skips this).
    private func addScaleInAnimation() {
        guard let layer = contentView.layer else { return }
        let size = contentView.bounds.size
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
