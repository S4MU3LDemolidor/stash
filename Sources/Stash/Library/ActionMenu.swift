import SwiftUI

/// The ⌘K menu: its own search field, actions with their keys, destructive ones last
/// (design.md §4, "Action menu"). `Esc` closes only the menu.
struct ActionMenu: View {
    @ObservedObject var library: LibraryController
    let onCommand: (PanelKeyCommand) -> Bool

    var body: some View {
        let actions = library.filteredActions
        let firstDestructive = actions.firstIndex(where: \.isDestructive)

        VStack(spacing: 0) {
            SearchField(
                text: $library.actionQuery,
                placeholder: String(localized: "Search actions…"),
                focusToken: library.actionMenuFocusToken,
                font: Typography.actionSearchNS,
                onCommand: onCommand
            )
            .padding(.horizontal, Metrics.rowPadding)
            .frame(height: Metrics.actionSearchHeight)

            Hairline()

            VStack(spacing: 0) {
                if actions.isEmpty {
                    Text("No matching actions")
                        .font(Typography.rowSubtitle)
                        .foregroundStyle(Palette.textTertiary)
                        .frame(height: Metrics.actionRowHeight)
                }
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    if index == firstDestructive, index > 0 {
                        Hairline().padding(.vertical, Metrics.unit)
                    }
                    row(action, isSelected: index == library.actionSelection)
                        .onTapGesture {
                            library.actionSelection = index
                            library.runSelectedAction()
                        }
                }
            }
            .padding(Metrics.unit)
        }
        .frame(width: Metrics.actionMenuWidth)
        .background(
            RoundedRectangle(cornerRadius: Metrics.previewCardRadius, style: .continuous)
                .fill(Palette.tint.opaque)
                .shadow(
                    color: .black.opacity(Metrics.popoverShadowOpacity),
                    radius: Metrics.popoverShadowRadius,
                    y: Metrics.popoverShadowOffsetY
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.previewCardRadius, style: .continuous)
                .strokeBorder(Palette.border, lineWidth: Metrics.borderWidth)
        )
    }

    private func row(_ action: LibraryAction, isSelected: Bool) -> some View {
        HStack(spacing: Metrics.rowIconGap) {
            Image(systemName: action.symbol)
                .frame(width: Metrics.searchIconSize)
            Text(action.title)
            Spacer(minLength: Metrics.unit * 2)
            Keycaps(keys: action.keys)
        }
        .font(Typography.rowSubtitle)
        .foregroundStyle(action.isDestructive ? Palette.danger : Palette.textPrimary)
        .padding(.horizontal, Metrics.unit * 2)
        .frame(height: Metrics.actionRowHeight)
        .background(
            RoundedRectangle(cornerRadius: Metrics.rowRadius - 2, style: .continuous)
                .fill(isSelected ? Palette.fillSelected : ColorToken.clear)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([action.title, action.keys.joined(separator: " ")].joined(separator: ", "))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
