import SwiftUI

/// Capture mode content: the preview card of what ↵ will save (design.md §4, "Capture preview
/// card"), or a drop zone when there's nothing yet, plus a one-line tip when needed.
struct CaptureView: View {
    @ObservedObject var session: CaptureSession
    let isDropTargeted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.unit * 2) {
            if let item = session.item {
                CaptureCard(item: item, preview: session.preview, isTargeted: isDropTargeted)
            } else if let browser = session.readingBrowser {
                CaptureCard.loading(from: browser)
            } else {
                emptyState
            }

            if let hint = session.hint {
                Text(hint)
                    .font(Typography.meta)
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Metrics.unit)
            }
            if session.item != nil || session.readingBrowser != nil {
                Spacer(minLength: 0)
            }
        }
        .padding(Metrics.contentInset)
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: Metrics.previewCardRadius, style: .continuous)
            .fill(isDropTargeted ? Palette.fillHover : ColorToken.clear)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.previewCardRadius, style: .continuous)
                    .strokeBorder(
                        isDropTargeted ? Palette.textTertiary : Palette.divider,
                        style: StrokeStyle(lineWidth: Metrics.borderWidth, dash: Metrics.dashPattern)
                    )
            )
            .overlay {
                Text(isDropTargeted ? "Drop to capture" : "Paste, type or drop anything")
                    .font(Typography.rowSubtitle)
                    .foregroundStyle(Palette.textTertiary)
            }
            .accessibilityElement(children: .combine)
    }
}
