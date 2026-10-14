import SwiftUI

struct ActionBarItem {
    let label: String
    let keys: [String]
}

/// Bottom zone of the panel: glyph + context on the left, primary action and
/// secondary action (separated by a thin divider) on the right.
struct ActionBar: View {
    let context: String
    var contextStyle = Palette.textSecondary
    let primary: ActionBarItem
    let secondary: ActionBarItem

    var body: some View {
        VStack(spacing: 0) {
            Hairline()

            HStack(spacing: Metrics.unit * 2) {
                StashGlyph()
                Text(context)
                    .font(Typography.meta)
                    .foregroundStyle(contextStyle)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: Metrics.unit * 4)

                item(primary, labelStyle: Palette.textPrimary)
                VerticalHairline()
                    .frame(height: Metrics.actionBarDividerHeight)
                    .padding(.horizontal, Metrics.unit)
                item(secondary, labelStyle: Palette.textSecondary)
            }
            .padding(.horizontal, Metrics.actionBarPadding)
            .frame(height: Metrics.actionBarHeight)
        }
    }

    private func item(_ item: ActionBarItem, labelStyle: ColorToken) -> some View {
        HStack(spacing: Metrics.unit * 2) {
            Text(item.label)
                .font(Typography.meta)
                .foregroundStyle(labelStyle)
            Keycaps(keys: item.keys)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.label), \(item.keys.joined(separator: " "))")
    }
}

/// The small Stash mark at the left of the action bar.
struct StashGlyph: View {
    var body: some View {
        Image(systemName: "tray.and.arrow.down.fill")
            .font(.system(size: Metrics.glyphSize * 0.75))
            .foregroundStyle(Palette.textSecondary)
            .frame(width: Metrics.glyphSize, height: Metrics.glyphSize)
            .accessibilityHidden(true)
    }
}
