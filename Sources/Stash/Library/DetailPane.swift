import SwiftUI

/// Right side of the list: media, title, note, then the details (design.md §4, "Detail pane").
struct DetailPane: View {
    let reference: Reference
    let assets: LibraryAssets

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.unit * 3) {
                media
                Text(reference.displayTitle)
                    .font(Typography.detailTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if reference.type == .text, let text = reference.text, text != reference.displayTitle {
                    Text(text)
                        .font(Typography.detailBody)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !reference.note.isEmpty, reference.note != reference.displayTitle {
                    Text(reference.note)
                        .font(Typography.detailBody)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                metadata
                    .padding(.top, Metrics.unit)
            }
            .padding(Metrics.detailPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.automatic)
        .accessibilityElement(children: .contain)
    }

    // MARK: Media

    @ViewBuilder private var media: some View {
        switch reference.type {
        case .image:
            if let file = reference.file {
                AssetImage(url: assets.assetURL(file), maxPixels: 800, contentMode: .fit) { mediaPlaceholder(symbol: "photo") }
                    .frame(maxWidth: .infinity, maxHeight: Metrics.detailMediaMaxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.gridRadius, style: .continuous))
            }
        case .link:
            if let thumbnail = reference.thumbnail {
                videoFrame { AssetImage(url: assets.assetURL(thumbnail), maxPixels: 800) { mediaPlaceholder(symbol: reference.symbolName) } }
            } else if assets.isLoading(reference.id) {
                videoFrame { ShimmerPlaceholder() }
            } else if reference.isYouTube {
                videoFrame { mediaPlaceholder(symbol: reference.symbolName) }
            }
        case .file:
            if let file = reference.file {
                Image(nsImage: NSWorkspace.shared.icon(forFile: assets.assetURL(file).path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: Metrics.detailFileIconSize, height: Metrics.detailFileIconSize)
            }
        case .text:
            EmptyView()
        }
    }

    /// 16:9, like a video.
    private func videoFrame<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay { content() }
            .clipShape(RoundedRectangle(cornerRadius: Metrics.gridRadius, style: .continuous))
    }

    private func mediaPlaceholder(symbol: String) -> some View {
        Rectangle()
            .fill(Palette.fillKeycap)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: Metrics.emptyIconSize))
                    .foregroundStyle(Palette.textTertiary)
            }
    }

    // MARK: Details

    private var metadata: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Metrics.unit * 3, verticalSpacing: Metrics.unit * 2) {
            if let site = reference.site {
                row("Site", site)
            }
            row("Saved", LibraryFormatting.savedDate(reference.created))
            if let timestamp = reference.timestamp {
                row("Timestamp", YouTube.formatTime(timestamp))
            }
            row("Type", typeDescription)
            if !reference.tags.isEmpty {
                GridRow {
                    label("Tags")
                    FlowTags(tags: reference.tags)
                }
            }
            if let path = reference.markdownPath {
                row("File", (path as NSString).lastPathComponent)
            }
        }
    }

    private var typeDescription: String {
        guard reference.type == .image, let width = reference.width, let height = reference.height else {
            return reference.kindDescription
        }
        return "Image · \(width)×\(height)"
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            label(title)
            Text(value)
                .font(Typography.detailBody)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .font(Typography.detailBody)
            .foregroundStyle(Palette.textTertiary)
            .gridColumnAlignment(.leading)
    }
}

/// Tag pills that wrap onto more lines when needed.
private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        // Rows of three: references rarely have more tags than that.
        VStack(alignment: .leading, spacing: Metrics.unit) {
            ForEach(Array(stride(from: 0, to: tags.count, by: 3)), id: \.self) { start in
                HStack(spacing: Metrics.unit) {
                    ForEach(tags[start..<min(start + 3, tags.count)], id: \.self) { TagPill(tag: $0) }
                }
            }
        }
    }
}
