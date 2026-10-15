import AppKit

/// One row of the ⌘K action menu.
struct LibraryAction: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let keys: [String]
    var isDestructive = false
    let run: @MainActor () -> Void
}

/// The actions from design.md §4 ("Action menu").
extension LibraryController {
    /// Actions for the selected reference, in menu order (destructive last).
    var actions: [LibraryAction] {
        guard let reference = selected else { return [toggleLayoutAction] }
        var actions = [
            LibraryAction(id: "open", title: String(localized: "Open"), symbol: "arrow.up.forward.app", keys: ["↵"]) { [weak self] in
                self?.open(reference, atTimestamp: false)
            },
        ]
        if reference.isYouTube, let timestamp = reference.timestamp {
            actions.append(LibraryAction(
                id: "openAtTimestamp", title: String(localized: "Open at \(YouTube.formatTime(timestamp))"), symbol: "play.circle", keys: ["⌘", "↵"]
            ) { [weak self] in self?.open(reference, atTimestamp: true) })
        }
        actions += [
            LibraryAction(id: "copy", title: copyTitle(for: reference), symbol: "doc.on.doc", keys: ["⌘", "C"]) { [weak self] in
                self?.copy(reference)
            },
        ]
        if reference.type == .image, let text = try? library?.index.fileText(id: reference.id) {
            actions.append(LibraryAction(id: "copyImageText", title: String(localized: "Copy Text in Image"), symbol: "text.viewfinder", keys: []) { [weak self] in
                self?.copyText(text)
            })
        }
        actions += [
            LibraryAction(id: "edit", title: String(localized: "Edit Note & Tags"), symbol: "pencil", keys: ["⌘", "E"]) { [weak self] in
                self?.beginEdit()
            },
            LibraryAction(id: "reveal", title: String(localized: "Reveal in Finder"), symbol: "folder", keys: ["⌘", "⇧", "F"]) { [weak self] in
                self?.reveal(reference)
            },
            toggleLayoutAction,
            LibraryAction(id: "delete", title: String(localized: "Delete"), symbol: "trash", keys: ["⌘", "⌫"], isDestructive: true) { [weak self] in
                self?.requestDelete()
            },
        ]
        return actions
    }

    private var toggleLayoutAction: LibraryAction {
        LibraryAction(
            id: "layout",
            title: layout == .list ? String(localized: "Show as Grid") : String(localized: "Show as List"),
            symbol: layout == .list ? "square.grid.2x2" : "list.bullet",
            keys: ["⌘", "G"]
        ) { [weak self] in self?.toggleLayout() }
    }

    var filteredActions: [LibraryAction] {
        let query = actionQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return actions }
        return actions.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func copyTitle(for reference: Reference) -> String {
        switch reference.type {
        case .link: String(localized: "Copy Link")
        case .text: String(localized: "Copy Text")
        case .image: String(localized: "Copy Image")
        case .file: String(localized: "Copy File")
        }
    }

    // MARK: Action menu

    func toggleActionMenu() {
        isActionMenuOpen ? closeActionMenu() : openActionMenu()
    }

    func openActionMenu() {
        actionQuery = ""
        actionSelection = 0
        isActionMenuOpen = true
        actionMenuFocusToken += 1
    }

    func closeActionMenu() {
        guard isActionMenuOpen else { return }
        isActionMenuOpen = false
        onRefocus?()
    }

    func moveActionSelection(by offset: Int) {
        let count = filteredActions.count
        guard count > 0 else { return }
        actionSelection = (actionSelection + offset + count) % count
    }

    func runSelectedAction() {
        let actions = filteredActions
        guard actions.indices.contains(actionSelection) else { return }
        closeActionMenu()
        actions[actionSelection].run()
    }

    // MARK: Actions

    /// Links open in the browser (YouTube from the start unless `atTimestamp`); text, images and
    /// files open in their default app.
    func open(_ reference: Reference, atTimestamp: Bool) {
        guard let library else { return }
        let target: URL?
        switch reference.type {
        case .link:
            if let url = reference.url, let videoID = YouTube.videoID(in: url) {
                target = YouTube.canonicalURL(videoID: videoID, timestamp: atTimestamp ? reference.timestamp : nil)
            } else {
                target = reference.url
            }
        case .text:
            target = reference.markdownPath.map(library.url(for:))
        case .image, .file:
            target = (reference.file ?? reference.markdownPath).map(library.url(for:))
        }
        guard let target else { return }
        onDismiss?()
        NSWorkspace.shared.open(target)
    }

    func copy(_ reference: Reference) {
        guard let library else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch reference.type {
        case .link:
            guard let url = reference.url else { return }
            pasteboard.writeObjects([url as NSURL])
            pasteboard.setString(url.absoluteString, forType: .string)
        case .text:
            pasteboard.setString(reference.text ?? "", forType: .string)
        case .image, .file:
            guard let file = reference.file else { return }
            let fileURL = library.url(for: file)
            var objects: [NSPasteboardWriting] = [fileURL as NSURL]
            if reference.type == .image, let image = NSImage(contentsOf: fileURL) {
                objects.insert(image, at: 0)
            }
            pasteboard.writeObjects(objects)
        }
        // Don't offer what we just copied as the next capture.
        ClipboardMonitor.shared.ignoreCurrentContents()
        onDismiss?()
        HUDController.shared.show(.copied)
    }

    /// Plain text, e.g. what an image says.
    func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        ClipboardMonitor.shared.ignoreCurrentContents()
        onDismiss?()
        HUDController.shared.show(.copied)
    }

    func reveal(_ reference: Reference) {
        guard let library, let path = reference.markdownPath else { return }
        onDismiss?()
        NSWorkspace.shared.activateFileViewerSelecting([library.url(for: path)])
    }

    func toggleLayout() {
        layout = layout == .list ? .grid : .list
    }

    /// No results + ↵: the search becomes a text reference (pill tags included).
    func saveSearchAsNote() throws {
        guard let library else { return }
        let parsed = TagParser.parse(searchText)
        guard !parsed.text.isEmpty else { return }
        var tags = pills.compactMap { if case .tag(let tag) = $0 { tag } else { nil } }
        for tag in parsed.tags where !tags.contains(tag) { tags.append(tag) }

        let saved = try library.create(Reference(type: .text, tags: tags, text: parsed.text))
        pills = []
        searchText = ""
        selectedID = saved.id
        refresh()
        HUDController.shared.show(.saved)
    }
}
