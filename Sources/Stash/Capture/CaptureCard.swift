import SwiftUI
import UniformTypeIdentifiers

/// `[thumb]  Title / site · at 4:32  [From Arc]`
struct CaptureCard: View {
    let symbol: String
    let image: NSImage?
    let title: String
    /// Shown dimmer when the real title isn't known yet (a bare URL, or still loading).
    let titleIsPlaceholder: Bool
    let subtitle: String?
    let badge: String
    var isTargeted = false

    var body: some View {
        HStack(spacing: Metrics.rowPadding) {
            thumbnail
            VStack(alignment: .leading, spacing: Metrics.unit / 2) {
                Text(title)
                    .font(Typography.rowTitle)
                    .foregroundStyle(titleIsPlaceholder ? Palette.textSecondary : Palette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.rowSubtitle)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer(minLength: Metrics.unit * 2)
            Text(badge)
                .font(Typography.tag)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, Metrics.tagPadding)
                .frame(height: Metrics.tagHeight)
                .background(Capsule().fill(Palette.fillTag))
        }
        .padding(Metrics.unit * 2)
        .background(
            RoundedRectangle(cornerRadius: Metrics.previewCardRadius, style: .continuous)
                .fill(isTargeted ? Palette.fillKeycap : Palette.fillSelected)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, subtitle, badge].compactMap { $0 }.joined(separator: ", "))
    }

    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: Metrics.rowIconRadius + 1, style: .continuous)
            .fill(Palette.fillKeycap)
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: Metrics.searchIconSize))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .frame(width: Metrics.previewThumb.width, height: Metrics.previewThumb.height)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.rowIconRadius + 1, style: .continuous))
    }
}

extension CaptureCard {
    init(item: CaptureItem, preview: NSImage?, isTargeted: Bool) {
        let badge = item.origin.badge
        switch item.content {
        case .link(let url, let title, let timestamp):
            let isVideo = YouTube.videoID(in: url) != nil
            let site = Reference.site(for: YouTube.normalize(url) ?? url) ?? url.absoluteString
            let at = timestamp ?? (isVideo ? YouTube.timestamp(in: url) : nil)
            self.init(
                symbol: isVideo ? "play.rectangle.fill" : "link",
                image: nil,
                title: title ?? url.absoluteString,
                titleIsPlaceholder: title == nil,
                subtitle: at.map { "\(site) · at \(YouTube.formatTime($0))" } ?? site,
                badge: badge,
                isTargeted: isTargeted
            )
        case .text(let text):
            let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
            self.init(
                symbol: "text.quote",
                image: nil,
                title: firstLine,
                titleIsPlaceholder: false,
                subtitle: "Text · \(text.count) characters",
                badge: badge,
                isTargeted: isTargeted
            )
        case .image(let data, let fileExtension):
            let size = ImageInfo.pixelSize(data: data).map { " · \($0.width)×\($0.height)" } ?? ""
            self.init(
                symbol: "photo",
                image: preview,
                title: "Image",
                titleIsPlaceholder: false,
                subtitle: fileExtension.uppercased() + size,
                badge: badge,
                isTargeted: isTargeted
            )
        case .file(let url):
            let kind = UTType(filenameExtension: url.pathExtension)?.localizedDescription ?? "File"
            let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map {
                " · " + ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
            } ?? ""
            self.init(
                symbol: "doc",
                image: preview,
                title: url.lastPathComponent,
                titleIsPlaceholder: false,
                subtitle: kind + bytes,
                badge: badge,
                isTargeted: isTargeted
            )
        }
    }

    /// While the browser's tab is being read.
    static func loading(from browser: Browser) -> CaptureCard {
        CaptureCard(
            symbol: "globe",
            image: nil,
            title: "Reading \(browser.name)…",
            titleIsPlaceholder: true,
            subtitle: nil,
            badge: "From \(browser.name)"
        )
    }
}
