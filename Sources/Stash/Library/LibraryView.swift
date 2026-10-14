import KeyboardShortcuts
import SwiftUI

/// Library mode content. For now only the empty state (design.md §4, "Empty states");
/// the list, detail pane and grid arrive in M4.
struct LibraryView: View {
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
