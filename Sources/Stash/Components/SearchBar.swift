import SwiftUI

/// Top zone of the panel: icon, borderless input on glass, mode label, hairline below.
struct SearchBar: View {
    let icon: String
    let placeholder: String
    let modeLabel: String
    @Binding var text: String
    let focusToken: Int
    let onCommand: (PanelKeyCommand) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.searchIconGap) {
                Image(systemName: icon)
                    .font(.system(size: Metrics.searchIconSize))
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityHidden(true)

                SearchField(
                    text: $text,
                    placeholder: placeholder,
                    focusToken: focusToken,
                    onCommand: onCommand
                )
                .frame(maxWidth: .infinity)

                // Active filter pills go here (M4).

                Text(modeLabel)
                    .font(Typography.meta)
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(.horizontal, Metrics.searchBarPadding)
            .frame(height: Metrics.searchBarHeight)

            Hairline()
        }
    }
}
