import SwiftUI

/// `[icon]  Title / subtitle  #tag #tag  2h ago` (design.md §4, "List row").
struct ListRow: View {
    let reference: Reference
    let isSelected: Bool
    let isHovered: Bool
    /// Tag pills only fit in a full-width list; next to the detail pane (which shows the tags)
    /// they'd squeeze the title, so the list + preview layout leaves them out, like design.md's mock.
    var showsTags = false
    let assetURL: (String) -> URL

    var body: some View {
        HStack(spacing: Metrics.rowIconGap) {
            ReferenceIcon(reference: reference, assetURL: assetURL)

            VStack(alignment: .leading, spacing: 0) {
                Text(reference.displayTitle)
                    .font(Typography.rowTitle)
                    .foregroundStyle(Palette.textPrimary)
                if let subtitle = reference.displaySubtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Typography.rowSubtitle)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .lineLimit(1)
            .truncationMode(.tail)

            Spacer(minLength: Metrics.unit * 2)

            if showsTags {
                ForEach(reference.tags.prefix(2), id: \.self) { tag in
                    TagPill(tag: tag)
                }
            }
            Text(LibraryFormatting.relativeDate(reference.created))
                .font(Typography.meta)
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, Metrics.rowPadding)
        .frame(height: Metrics.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous)
                .fill(isSelected ? Palette.fillSelected : isHovered ? Palette.fillHover : ColorToken.clear)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reference.accessibilityDescription())
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// 20 × 20 row icon: the image itself, a thumbnail, the file's icon, or a symbol by type.
struct ReferenceIcon: View {
    let reference: Reference
    let assetURL: (String) -> URL

    var body: some View {
        RoundedRectangle(cornerRadius: Metrics.rowIconRadius, style: .continuous)
            .fill(Palette.fillKeycap)
            .overlay { content }
            .frame(width: Metrics.rowIconSize, height: Metrics.rowIconSize)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.rowIconRadius, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder private var content: some View {
        if let image = reference.type == .image ? reference.file : reference.thumbnail {
            AssetImage(url: assetURL(image), maxPixels: Int(Metrics.rowIconSize * 3)) { symbol }
        } else if reference.type == .file, let file = reference.file {
            Image(nsImage: NSWorkspace.shared.icon(forFile: assetURL(file).path))
                .resizable()
                .scaledToFit()
        } else {
            symbol
        }
    }

    private var symbol: some View {
        Image(systemName: reference.symbolName)
            .font(.system(size: Metrics.rowIconSize * 0.55))
            .foregroundStyle(Palette.textSecondary)
    }
}
