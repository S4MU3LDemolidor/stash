import AppKit

/// A filter shown as a removable pill in the search bar.
enum FilterPill: Equatable, Hashable {
    case tag(String)
    case type(ReferenceType)

    var label: String {
        switch self {
        case .tag(let tag): tag
        case .type(.link): String(localized: "Links")
        case .type(.text): String(localized: "Text")
        case .type(.image): String(localized: "Images")
        case .type(.file): String(localized: "Files")
        }
    }
}

enum LibraryLayout: String {
    case list
    case grid
}

/// Library mode: search with filter pills, sections, selection, editing and deleting.
/// Actions (open, copy, reveal…) are in `LibraryController+Actions.swift`.
@MainActor
final class LibraryController: ObservableObject {
    @Published var searchText = "" {
        didSet { if searchText != oldValue { searchTextChanged() } }
    }
    @Published var pills: [FilterPill] = []
    @Published private(set) var results: [Reference] = []
    @Published private(set) var sections: [LibrarySection] = []
    @Published var selectedID: String?
    @Published private(set) var totalCount = 0
    @Published var layout: LibraryLayout {
        didSet { UserDefaults.standard.set(layout.rawValue, forKey: Self.layoutKey) }
    }

    /// Set while ⌘⌫ waits for confirmation.
    @Published var deleteCandidate: Reference?
    /// Set while editing the note and tags of a reference (⌘E).
    @Published private(set) var editing: Reference?
    @Published var editText = "" {
        didSet { if editing != nil { autocomplete.update(for: editText) } }
    }

    @Published var isActionMenuOpen = false
    @Published var actionQuery = "" {
        didSet { actionSelection = 0 }
    }
    @Published var actionSelection = 0
    @Published var actionMenuFocusToken = 0

    let autocomplete = TagAutocomplete()
    private(set) var query = SearchQuery()

    var library: LibraryStore? {
        didSet { refresh() }
    }
    /// Closes the panel (after Open, Copy, Reveal…).
    var onDismiss: (() -> Void)?
    /// Gives keyboard focus back to the panel's main text field.
    var onRefocus: (() -> Void)?

    private static let layoutKey = "libraryLayout"

    init() {
        layout = UserDefaults.standard.string(forKey: Self.layoutKey).flatMap(LibraryLayout.init) ?? .list
        NotificationCenter.default.addObserver(forName: .libraryDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    var selected: Reference? { results.first { $0.id == selectedID } }
    /// Search terms are typed (not just filters): results are ranked rather than grouped by date.
    var isSearching: Bool { !query.terms.isEmpty }
    var hasQuery: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty || !pills.isEmpty }

    // MARK: Lifecycle

    /// Fresh state each time the panel opens.
    func reset() {
        pills = []
        deleteCandidate = nil
        editing = nil
        isActionMenuOpen = false
        autocomplete.reset(knownTags: (try? library?.index.tags().map(\.name)) ?? [])
        selectedID = nil
        if searchText.isEmpty { refresh() } else { searchText = "" }
    }

    func refresh() {
        query = currentQuery()
        guard let library else {
            (results, sections, totalCount) = ([], [], 0)
            return
        }
        totalCount = (try? library.index.count()) ?? 0
        results = (try? library.index.search(query)) ?? []
        sections = LibraryFormatting.sections(for: results, searching: isSearching)
        if selectedID == nil || !results.contains(where: { $0.id == selectedID }) {
            selectedID = results.first?.id
        }
    }

    // MARK: Search and filter pills

    private func searchTextChanged() {
        // Finished filter tokens (followed by a space) turn into pills.
        let words = searchText.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        var kept: [String] = []
        var found: [FilterPill] = []
        for word in words.dropLast() {
            if let pill = Self.pill(for: word) { found.append(pill) } else { kept.append(word) }
        }
        if !found.isEmpty {
            for pill in found where !pills.contains(pill) { pills.append(pill) }
            // Keep a trailing space so the next word doesn't stick to the previous one.
            searchText = String((kept + [words.last ?? ""]).joined(separator: " ").drop(while: \.isWhitespace))
            return // didSet runs again with the cleaned text
        }
        refresh()
        autocomplete.update(for: searchText, excluding: Set(pills.compactMap { if case .tag(let t) = $0 { t } else { nil } }))
    }

    private static func pill(for word: String) -> FilterPill? {
        if word.hasPrefix("#") { return TagParser.normalize(word).map(FilterPill.tag) }
        if word.lowercased().hasPrefix("type:") {
            return ReferenceType(filterValue: String(word.dropFirst(5))).map(FilterPill.type)
        }
        return nil
    }

    /// The query from the pills plus the text, ignoring a filter that's still being typed.
    private func currentQuery() -> SearchQuery {
        var words = searchText.split(whereSeparator: \.isWhitespace).map(String.init)
        if let last = words.last, !searchText.hasSuffix(" "), last.hasPrefix("#") || last.lowercased().hasPrefix("type:") {
            words.removeLast()
        }
        var query = SearchQuery.parse(words.joined(separator: " "))
        for pill in pills {
            switch pill {
            case .tag(let tag) where !query.tags.contains(tag): query.tags.append(tag)
            case .type(let type) where !query.types.contains(type): query.types.append(type)
            default: break
            }
        }
        return query
    }

    func removePill(_ pill: FilterPill) {
        pills.removeAll { $0 == pill }
        refresh()
    }

    /// ⌫ in an empty search field removes the last pill.
    func removeLastPill() -> Bool {
        guard searchText.isEmpty, !pills.isEmpty else { return false }
        pills.removeLast()
        refresh()
        return true
    }

    /// Esc: clears the search first. Returns false when there was nothing to clear.
    func clearSearch() -> Bool {
        guard hasQuery else { return false }
        pills = []
        searchText = ""
        refresh()
        return true
    }

    /// ⇥/↵ on a tag suggestion: it becomes a pill.
    func completeTagSuggestion() -> Bool {
        guard let tag = autocomplete.selectedTag, let hash = searchText.lastIndex(of: "#") else { return false }
        if !pills.contains(.tag(tag)) { pills.append(.tag(tag)) }
        searchText = String(searchText[..<hash].drop(while: \.isWhitespace))
        refresh()
        return true
    }

    // MARK: Selection

    enum Direction { case up, down, left, right }

    /// Columns in the grid, for moving up and down by a row.
    static let gridColumns = 4

    func moveSelection(_ direction: Direction) {
        guard !results.isEmpty else { return }
        let current = results.firstIndex { $0.id == selectedID } ?? 0
        let step = switch (direction, layout) {
        case (.up, .grid): -Self.gridColumns
        case (.down, .grid): Self.gridColumns
        case (.up, _), (.left, _): -1
        case (.down, _), (.right, _): 1
        }
        let target = min(max(current + step, 0), results.count - 1)
        selectedID = results[target].id
    }

    // MARK: Editing (⌘E)

    func beginEdit() {
        guard let reference = selected else { return }
        editing = reference
        let tags = reference.tags.map { "#\($0)" }.joined(separator: " ")
        let text = [reference.note, tags].filter { !$0.isEmpty }.joined(separator: " ")
        // A trailing space, so a new #tag can be typed straight away.
        editText = text.isEmpty ? "" : text + " "
        autocomplete.reset(knownTags: (try? library?.index.tags().map(\.name)) ?? [])
        onRefocus?()
    }

    func commitEdit() throws {
        guard let reference = editing, let library else { return }
        let parsed = TagParser.parse(editText)
        try library.update(id: reference.id) { updated in
            updated.note = parsed.text
            updated.tags = parsed.tags
        }
        editing = nil
        onRefocus?()
    }

    func cancelEdit() {
        editing = nil
        autocomplete.reset(knownTags: (try? library?.index.tags().map(\.name)) ?? [])
        onRefocus?()
    }

    /// ⇥/↵ on a tag suggestion while editing: completes it in the text.
    func completeEditSuggestion() -> Bool {
        guard let tag = autocomplete.selectedTag else { return false }
        editText = TagSuggestions.complete(editText, with: tag)
        return true
    }

    // MARK: Deleting (⌘⌫, confirmed inline)

    func requestDelete() {
        deleteCandidate = selected
    }

    func confirmDelete() throws {
        guard let reference = deleteCandidate, let library else { return }
        // Keep the selection in place: move it to the neighbor before the list changes.
        if let index = results.firstIndex(where: { $0.id == reference.id }) {
            let neighbor = results.indices.contains(index + 1) ? index + 1 : index - 1
            selectedID = results.indices.contains(neighbor) ? results[neighbor].id : nil
        }
        deleteCandidate = nil
        try library.delete(id: reference.id)
    }
}
