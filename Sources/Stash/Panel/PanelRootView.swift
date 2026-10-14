import SwiftUI

/// The panel's three zones: search on top, content in the middle, action bar at the bottom.
struct PanelRootView: View {
    @ObservedObject var state: PanelState
    let onCommand: (PanelKeyCommand) -> Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            actionBar
        }
        .background(reduceTransparency ? Palette.tint.opaque : Palette.tint)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.border, lineWidth: Metrics.borderWidth))
    }

    @ViewBuilder private var searchBar: some View {
        switch state.mode {
        case .capture:
            SearchBar(
                icon: "tray.and.arrow.down",
                placeholder: "Add a note or #tags… (optional)",
                modeLabel: "Capture",
                text: $state.query,
                focusToken: state.focusToken,
                onCommand: onCommand
            )
        case .library:
            SearchBar(
                icon: "magnifyingglass",
                placeholder: "Search references…",
                modeLabel: "Library",
                text: $state.query,
                focusToken: state.focusToken,
                onCommand: onCommand
            )
        }
    }

    @ViewBuilder private var content: some View {
        switch state.mode {
        case .capture: CaptureView()
        case .library: LibraryView()
        }
    }

    @ViewBuilder private var actionBar: some View {
        switch state.mode {
        case .capture:
            ActionBar(
                context: "Saving to \(Preferences.libraryDisplayPath)",
                primary: ActionBarItem(label: "Save", keys: ["↵"]),
                secondary: ActionBarItem(label: "Library", keys: ["⇥"])
            )
        case .library:
            ActionBar(
                context: "No references",
                primary: ActionBarItem(label: "Open", keys: ["↵"]),
                secondary: ActionBarItem(label: "Actions", keys: ["⌘", "K"])
            )
        }
    }
}
