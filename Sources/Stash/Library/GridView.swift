import SwiftUI

/// The moodboard (⌘G): thumbnails in a grid, titles underneath (design.md §4, "Grid").
struct GridView: View {
    @ObservedObject var library: LibraryController
    let assets: LibraryAssets
    let onClick: (Reference) -> Void

    @State private var hovered: String?

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: Metrics.gridGap, alignment: .top),
        count: LibraryController.gridColumns
    )

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: Metrics.gridGap) {
                    ForEach(library.results) { reference in
                        GridCell(
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
                .padding(Metrics.contentInset)
            }
            .onChange(of: library.selectedID) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }
}

private struct GridCell: View {
    let reference: Reference
    let isSelected: Bool
    let isHovered: Bool
    let assets: LibraryAssets

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.gridRadius, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.unit + 2) {
            Color.clear
                .aspectRatio(Metrics.gridThumb.width / Metrics.gridThumb.height, contentMode: .fit)
                .overlay { thumbnail }
                .clipShape(shape)
                .overlay {
                    if isSelected {
                        shape.strokeBorder(
                            Palette.textPrimary.opacity(Metrics.selectionRingOpacity),
                            lineWidth: Metrics.selectionRingWidth
                        )
                    }
                }
            Text(reference.displayTitle)
                .font(Typography.gridTitle)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, Metrics.unit / 2)
        }
        .padding(Metrics.unit)
        .background(
            RoundedRectangle(cornerRadius: Metrics.gridRadius + Metrics.unit, style: .continuous)
                .fill(isSelected ? Palette.fillSelected : isHovered ? Palette.fillHover : ColorToken.clear)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reference.accessibilityDescription())
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder private var thumbnail: some View {
        if let image = reference.type == .image ? reference.file : reference.thumbnail {
            AssetImage(url: assets.assetURL(image), maxPixels: 400) { placeholder }
        } else if reference.type == .text {
            // Text items render as a card with their first lines.
            Text(reference.text ?? reference.note)
                .font(Typography.gridTitle)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Metrics.unit * 3)
                .background(Palette.fillTag)
        } else if reference.type == .file, let file = reference.file {
            Rectangle()
                .fill(Palette.fillKeycap)
                .overlay {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: assets.assetURL(file).path))
                        .resizable()
                        .scaledToFit()
                        .padding(Metrics.unit * 6)
                }
        } else if assets.isLoading(reference.id) {
            ShimmerPlaceholder()
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Palette.fillKeycap)
            .overlay {
                VStack(spacing: Metrics.unit) {
                    if let icon = assets.siteIconURL(reference.site) {
                        AssetImage(url: icon, maxPixels: 64, contentMode: .fit) { EmptyView() }
                            .frame(width: Metrics.rowIconSize, height: Metrics.rowIconSize)
                    } else {
                        Image(systemName: reference.symbolName)
                            .font(.system(size: Metrics.searchIconSize))
                    }
                    if let site = reference.site {
                        Text(site).font(Typography.meta)
                    }
                }
                .foregroundStyle(Palette.textTertiary)
            }
    }
}
