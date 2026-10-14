import AppKit

/// Capture mode: decides what to save when the panel opens (browser tab, recent clipboard or
/// nothing), handles paste/drop/clear, tag autocomplete, and saving.
@MainActor
final class CaptureController: ObservableObject {
    enum CaptureError: LocalizedError {
        case libraryUnavailable
        var errorDescription: String? { "The library folder isn't available." }
    }

    @Published private(set) var session = CaptureSession()
    @Published private(set) var suggestions: [String] = []
    @Published private(set) var selectedSuggestion = 0
    @Published var isDropTargeted = false

    var library: LibraryStore?

    private let clipboard = ClipboardMonitor()
    private let reader = BrowserTabReader.shared
    private var knownTags: [String] = []
    /// The note for which the user dismissed suggestions with Esc.
    private var dismissedSuggestionsFor: String?

    init() {
        clipboard.start()
        prepareBrowserScripts()
    }

    /// Compiles the AppleScript for browsers that are running now or come to the front later,
    /// so the first capture doesn't spend its deadline loading the browser's dictionary.
    private func prepareBrowserScripts() {
        let reader = self.reader
        for app in NSWorkspace.shared.runningApplications {
            if let browser = Browser.matching(app) { reader.prepare(browser) }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if let browser = Browser.matching(app) { reader.prepare(browser) }
        }
    }

    // MARK: Session

    /// An empty session, with no detection (e.g. the panel opened in Library mode).
    func reset() {
        session.detection?.cancel()
        session = CaptureSession()
        suggestions = []
        dismissedSuggestionsFor = nil
        knownTags = (try? library?.index.tags().map(\.name)) ?? []
    }

    /// Starts a capture: an image or file copied recently, else the browser's current tab,
    /// else anything else copied recently, else nothing.
    func begin(sourceApp: NSRunningApplication?) {
        reset()
        let session = self.session
        let clipboardContent = clipboard.changed(within: Preferences.clipboardWindow)
            ? ClipboardReader.content(of: .general)
            : nil

        if let clipboardContent, clipboardContent.isImageOrFile {
            session.item = CaptureItem(content: clipboardContent, origin: .clipboard)
        } else if let browser = Browser.matching(sourceApp) {
            session.readingBrowser = browser
            session.detection = Task { await self.readTab(of: browser, into: session, fallback: clipboardContent) }
        } else if let clipboardContent {
            session.item = CaptureItem(content: clipboardContent, origin: .clipboard)
        }
    }

    private func readTab(of browser: Browser, into session: CaptureSession, fallback: CaptureContent?) async {
        let tab = await reader.currentTab(of: browser)
        guard !Task.isCancelled else { return }
        session.readingBrowser = nil

        switch tab {
        case .success(let info) where ClipboardReader.webURL(info.url.absoluteString) != nil:
            let title = CaptureTitle.clean(info.title, for: info.url)
            session.item = CaptureItem(content: .link(info.url, title: title, timestamp: nil), origin: .browser(browser.name))
            if YouTube.videoID(in: info.url) != nil {
                await readVideoPosition(of: browser, url: info.url, into: session)
            }
        case .success:
            // New tab, settings page, local file…: nothing worth saving from the tab.
            session.item = fallback.map { CaptureItem(content: $0, origin: .clipboard) }
        case .failure(let error):
            if error == .notPermitted {
                session.hint = "Stash isn't allowed to read \(browser.name)'s tab. "
                    + "Turn it on in System Settings › Privacy & Security › Automation."
            }
            session.item = fallback.map { CaptureItem(content: $0, origin: .clipboard) }
        }
    }

    /// YouTube: the position the video is playing at. If the browser doesn't allow it, the link
    /// keeps any `t=` it already has, and a one-time tip explains how to turn it on.
    private func readVideoPosition(of browser: Browser, url: URL, into session: CaptureSession) async {
        session.readingVideoPosition = true
        let position = await reader.videoPosition(in: browser)
        session.readingVideoPosition = false
        guard !Task.isCancelled, case .link(url, let title, _)? = session.item?.content else { return }

        switch position {
        case .success(let seconds?) where seconds > 0:
            session.item?.content = .link(url, title: title, timestamp: seconds)
        case .failure(.javaScriptDisabled):
            let key = "javaScriptHintShown.\(browser.bundleID)"
            if !UserDefaults.standard.bool(forKey: key) {
                UserDefaults.standard.set(true, forKey: key)
                session.hint = browser.javaScriptHint
            }
        default:
            break
        }
    }

    // MARK: Replacing what's captured

    /// ⌘V: the clipboard replaces whatever was detected.
    func paste() {
        guard let content = ClipboardReader.content(of: .general) else {
            NSSound.beep()
            return
        }
        replace(with: content, origin: .pasted)
    }

    func drop(_ pasteboard: NSPasteboard) -> Bool {
        guard let content = ClipboardReader.content(of: pasteboard) else { return false }
        replace(with: content, origin: .dropped)
        return true
    }

    /// ⌘⌫: back to the empty state.
    func clear() {
        stopDetection()
        session.item = nil
    }

    private func replace(with content: CaptureContent, origin: CaptureOrigin) {
        stopDetection()
        session.item = CaptureItem(content: content, origin: origin)
    }

    private func stopDetection() {
        session.detection?.cancel()
        session.readingBrowser = nil
        session.readingVideoPosition = false
        session.hint = nil
    }

    // MARK: Saving

    func canSave(note: String) -> Bool {
        session.item != nil || session.readingBrowser != nil || !TagParser.parse(note).text.isEmpty
    }

    /// Saves the current session, first waiting for a browser read that's still in flight.
    /// Returns nil when there turned out to be nothing to save.
    func save(note: String) async throws -> Reference? {
        let session = self.session
        await session.detection?.value
        guard let library else { throw CaptureError.libraryUnavailable }
        return try await CaptureSaver(library: library).save(session.item, note: note)
    }

    // MARK: Tag autocomplete

    func noteChanged(_ note: String) {
        if note != dismissedSuggestionsFor { dismissedSuggestionsFor = nil }
        suggestions = dismissedSuggestionsFor == nil ? TagSuggestions.suggestions(for: note, from: knownTags) : []
        selectedSuggestion = 0
    }

    func moveSuggestion(by offset: Int) {
        guard !suggestions.isEmpty else { return }
        selectedSuggestion = (selectedSuggestion + offset + suggestions.count) % suggestions.count
    }

    /// The note with the selected suggestion filled in, or nil if no suggestions are showing.
    func completeSuggestion(in note: String) -> String? {
        guard suggestions.indices.contains(selectedSuggestion) else { return nil }
        return TagSuggestions.complete(note, with: suggestions[selectedSuggestion])
    }

    func dismissSuggestions(for note: String) {
        dismissedSuggestionsFor = note
        suggestions = []
    }
}
