import SwiftUI

/// The panel's three zones: search on top, content in the middle, action bar at the bottom.
struct PanelRootView: View {
    @ObservedObject var state: PanelState
    @ObservedObject var capture: CaptureController
    @ObservedObject var library: LibraryController
    @ObservedObject var enricher: Enricher
    /// Observed so the detail pane shows an image's text as soon as it's read.
    @ObservedObject var imageText: ImageTextIndexer
    let onCommand: (PanelKeyCommand) -> Bool
    let onMenuCommand: (PanelKeyCommand) -> Bool
    let onClick: (Reference) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(state.mode)
                .transition(.opacity)
            PanelActionBar(state: state, session: capture.session, library: library)
        }
        .animation(.easeInOut(duration: Motion.modeSwitch), value: state.mode)
        .overlay(alignment: .topLeading) {
            SuggestionsOverlay(autocomplete: state.mode == .capture ? capture.autocomplete : library.autocomplete)
        }
        .overlay(alignment: .bottomTrailing) { actionMenu }
        .animation(.easeOut(duration: Motion.actionMenu), value: library.isActionMenuOpen)
        .background(reduceTransparency ? Palette.tint.opaque : Palette.tint)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.border, lineWidth: Metrics.borderWidth))
    }

    @ViewBuilder private var searchBar: some View {
        switch state.mode {
        case .capture:
            SearchBar(
                icon: "tray.and.arrow.down",
                placeholder: String(localized: "Add a note or #tags… (optional)"),
                modeLabel: String(localized: "Capture"),
                text: $state.note,
                focusToken: state.focusToken,
                onCommand: onCommand
            )
        case .library where library.editing != nil:
            SearchBar(
                icon: "pencil",
                placeholder: String(localized: "Add a note or #tags…"),
                modeLabel: String(localized: "Edit"),
                text: $library.editText,
                focusToken: state.focusToken,
                onCommand: onCommand
            )
        case .library:
            SearchBar(
                icon: "magnifyingglass",
                placeholder: String(localized: "Search references…"),
                modeLabel: String(localized: "Library"),
                text: $library.searchText,
                focusToken: state.focusToken,
                pills: library.pills,
                onRemovePill: library.removePill,
                onCommand: onCommand
            )
        }
    }

    @ViewBuilder private var content: some View {
        switch state.mode {
        case .capture:
            CaptureView(session: capture.session, isDropTargeted: capture.isDropTargeted)
        case .library:
            LibraryView(library: library, assets: assets, onClick: onClick)
        }
    }

    @ViewBuilder private var actionMenu: some View {
        if state.mode == .library, library.isActionMenuOpen {
            ActionMenu(library: library, onCommand: onMenuCommand)
                .padding(.trailing, Metrics.contentInset)
                .padding(.bottom, Metrics.actionBarHeight + Metrics.unit)
                .transition(
                    reduceMotion ? .opacity : .opacity.combined(with: .offset(y: Metrics.unit))
                )
        }
    }

    private var assets: LibraryAssets {
        let store = library.library
        let loading = enricher.inProgress
        return LibraryAssets(
            assetURL: { store?.url(for: $0) ?? URL(fileURLWithPath: $0) },
            siteIconURL: { store?.siteIconURL(for: $0) },
            isLoading: { loading.contains($0) },
            imageText: { id in try? store?.index.fileText(id: id) }
        )
    }
}

/// Tag autocomplete, floating just under the text field.
private struct SuggestionsOverlay: View {
    @ObservedObject var autocomplete: TagAutocomplete

    var body: some View {
        if autocomplete.isShowing {
            TagSuggestionList(tags: autocomplete.suggestions, selected: autocomplete.selected)
                .padding(.top, Metrics.searchBarHeight - Metrics.unit)
                .padding(.leading, Metrics.searchBarPadding + Metrics.searchIconSize + Metrics.searchIconGap - Metrics.unit * 2)
        }
    }
}

/// The bottom bar's context and keys, which change with what ↵ and Esc will do.
private struct PanelActionBar: View {
    @ObservedObject var state: PanelState
    @ObservedObject var session: CaptureSession
    @ObservedObject var library: LibraryController

    var body: some View {
        switch state.mode {
        case .capture where session.duplicate != nil && session.item != nil:
            ActionBar(
                context: String(localized: "Already in Stash"),
                primary: ActionBarItem(label: String(localized: "Add to Existing"), keys: ["↵"]),
                secondary: ActionBarItem(label: String(localized: "Save Copy"), keys: ["⌥", "↵"])
            )
        case .capture:
            ActionBar(
                context: String(localized: "Saving to \(Preferences.libraryDisplayPath)"),
                primary: ActionBarItem(label: String(localized: "Save"), keys: ["↵"]),
                secondary: ActionBarItem(label: String(localized: "Library"), keys: ["⇥"])
            )
        case .library:
            if let candidate = library.deleteCandidate {
                ActionBar(
                    context: String(localized: "Delete “\(candidate.displayTitle)”?"),
                    contextStyle: Palette.danger,
                    primary: ActionBarItem(label: String(localized: "Delete"), keys: ["↵"]),
                    secondary: ActionBarItem(label: String(localized: "Cancel"), keys: ["esc"])
                )
            } else if let editing = library.editing {
                ActionBar(
                    context: String(localized: "Editing “\(editing.displayTitle)”"),
                    primary: ActionBarItem(label: String(localized: "Save"), keys: ["↵"]),
                    secondary: ActionBarItem(label: String(localized: "Cancel"), keys: ["esc"])
                )
            } else if library.results.isEmpty, !library.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                ActionBar(
                    context: String(localized: "No results"),
                    primary: ActionBarItem(label: String(localized: "Save as Note"), keys: ["↵"]),
                    secondary: ActionBarItem(label: String(localized: "Capture"), keys: ["⇥"])
                )
            } else {
                ActionBar(
                    context: countText,
                    primary: ActionBarItem(label: String(localized: "Open"), keys: ["↵"]),
                    secondary: ActionBarItem(label: String(localized: "Actions"), keys: ["⌘", "K"])
                )
            }
        }
    }

    private var countText: String {
        // A filter that's still being typed (#hoo) doesn't count as searching yet.
        let filtering = !library.query.isEmpty
        let count = filtering ? library.results.count : library.totalCount
        if filtering {
            return count == 1 ? String(localized: "1 result") : String(localized: "\(count) results")
        }
        return count == 1 ? String(localized: "1 reference") : String(localized: "\(count) references")
    }
}
