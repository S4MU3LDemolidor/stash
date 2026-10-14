import SwiftUI

/// Capture mode content. For now only the "nothing to capture" state (design.md §4,
/// "Capture preview card"); source detection and the preview card arrive in M3.
struct CaptureView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Metrics.previewCardRadius, style: .continuous)
            .strokeBorder(Palette.divider, style: StrokeStyle(lineWidth: Metrics.borderWidth, dash: Metrics.dashPattern))
            .overlay {
                Text("Paste, type or drop anything")
                    .font(Typography.rowSubtitle)
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(Metrics.contentInset)
    }
}
