import KeyboardShortcuts
import SwiftUI

/// Library mode content: list + detail, or the grid, or an empty state.
struct LibraryView: View {
    @ObservedObject var library: LibraryController
    let assets: LibraryAssets
    let onClick: (Reference) -> Void

    var body: some View {
        if library.totalCount == 0 {
            EmptyLibrary()
        } else if library.results.isEmpty {
            NoResults(searchText: library.searchText)
        } else if library.layout == .grid {
            GridView(library: library, assets: assets, onClick: onClick)
        } else {
            HStack(spacing: 0) {
                LibraryList(library: library, assets: assets, onClick: onClick)
                VerticalHairline()
                Group {
                    if let selected = library.selected {
                        DetailPane(reference: selected, assets: assets)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: (Metrics.panelWidth * Metrics.detailWidthFraction).rounded())
            }
        }
    }
}

private struct LibraryList: View {
    @ObservedObject var library: LibraryController
    let assets: LibraryAssets
    let onClick: (Reference) -> Void

    @State private var hovered: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(library.sections) { section in
                        Text(section.title)
                            .font(Typography.section)
                            .foregroundStyle(Palette.textTertiary)
                            .padding(.leading, Metrics.sectionHeaderPadding)
                            .frame(height: Metrics.sectionHeaderHeight)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(section.items) { reference in
                            ListRow(
                                reference: reference,
                                isSelected: reference.id == library.selectedID,
                                isHovered: reference.id == hovered,
                                assets: assets
                            )
                            .id(reference.id)
                            .onTapGesture { onClick(reference) }
                            .onHover { inside in
                                if inside { hovered = reference.id } else if hovered == reference.id { hovered = nil }
                            }
                        }
                    }
                }
                .padding(Metrics.contentInset)
            }
            .onChange(of: library.selectedID) { _, id in
                // Selection moves instantly; scroll just enough to keep it visible.
                if let id { proxy.scrollTo(id) }
            }
        }
    }
}

/// Nothing saved yet.
private struct EmptyLibrary: View {
    var body: some View {
        VStack(spacing: Metrics.unit * 2) {
            Image(systemName: "tray")
                .font(.system(size: Metrics.emptyIconSize))
                .foregroundStyle(Palette.textTertiary)
                .padding(.bottom, Metrics.unit)
                .accessibilityHidden(true)

            Text("Nothing stashed yet")
                .font(Typography.rowTitle)
                .foregroundStyle(Palette.textSecondary)

            HStack(spacing: Metrics.unit * 2) {
                Text("Press")
                Keycaps(keys: KeyboardShortcuts.Name.capture.keycaps)
                Text("to capture")
            }
            .font(Typography.meta)
            .foregroundStyle(Palette.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Search with no matches; ↵ saves the search as a note.
private struct NoResults: View {
    let searchText: String

    private var trimmed: String { searchText.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: Metrics.unit * 2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Metrics.emptyIconSize))
                .foregroundStyle(Palette.textTertiary)
                .padding(.bottom, Metrics.unit)
                .accessibilityHidden(true)

            Text(trimmed.isEmpty ? "No references match these filters" : "No results for “\(trimmed)”")
                .font(Typography.rowTitle)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if !trimmed.isEmpty {
                HStack(spacing: Metrics.unit * 2) {
                    Text("Press")
                    Keycaps(keys: ["↵"])
                    Text("to save it as a note")
                }
                .font(Typography.meta)
                .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.horizontal, Metrics.searchBarPadding)
        .accessibilityElement(children: .combine)
    }
}
