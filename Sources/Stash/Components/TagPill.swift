import SwiftUI

/// `#hooks` capsule (design.md §4, "Tag pill").
struct TagPill: View {
    let tag: String
    /// Active filters use the accent color.
    var isActive = false

    var body: some View {
        HStack(spacing: 0) {
            Text("#").foregroundStyle(Palette.textTertiary)
            Text(tag).foregroundStyle(isActive ? Palette.accent : Palette.textSecondary)
        }
        .font(Typography.tag)
        .lineLimit(1)
        .padding(.horizontal, Metrics.tagPadding)
        .frame(height: Metrics.tagHeight)
        .background(Capsule().fill(Palette.fillTag))
    }
}

/// A search filter in the search bar, with a × to remove it.
struct FilterPillView: View {
    let pill: FilterPill
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Metrics.unit) {
            switch pill {
            case .tag(let tag):
                HStack(spacing: 0) {
                    Text("#").foregroundStyle(Palette.textTertiary)
                    Text(tag).foregroundStyle(Palette.accent)
                }
            case .type:
                Text(pill.label).foregroundStyle(Palette.textSecondary)
            }
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: Metrics.tagHeight / 2, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove filter \(pill.label)")
        }
        .font(Typography.tag)
        .lineLimit(1)
        .padding(.horizontal, Metrics.tagPadding)
        .frame(height: Metrics.tagHeight)
        .background(Capsule().fill(Palette.fillTag))
    }
}
