import SwiftUI

/// Tag autocomplete for the note: typing `#` suggests existing tags, most used first.
enum TagSuggestions {
    static let limit = 5

    /// Tags to offer for the tag being typed at the end of `note`. Tags already in the note,
    /// or exactly what's typed, aren't offered.
    static func suggestions(for note: String, from knownTags: [String]) -> [String] {
        guard let partial = TagParser.partialTag(atEndOf: note) else { return [] }
        let used = Set(TagParser.parse(note).tags)
        return Array(
            knownTags
                .filter { $0.hasPrefix(partial) && $0 != partial && !used.contains($0) }
                .prefix(limit)
        )
    }

    /// `note` with the tag being typed replaced by `#tag` and a space.
    static func complete(_ note: String, with tag: String) -> String {
        guard let hash = note.lastIndex(of: "#") else { return note }
        return String(note[..<hash]) + "#\(tag) "
    }
}

/// The suggestion list shown under the note field.
struct TagSuggestionList: View {
    let tags: [String]
    let selected: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(tags.enumerated()), id: \.element) { index, tag in
                HStack(spacing: 0) {
                    Text("#").foregroundStyle(Palette.textTertiary)
                    Text(tag).foregroundStyle(Palette.textPrimary)
                    Spacer(minLength: Metrics.unit * 4)
                    if index == selected {
                        Keycaps(keys: ["⇥"])
                    }
                }
                .font(Typography.rowSubtitle)
                .padding(.horizontal, Metrics.rowPadding - Metrics.unit)
                .frame(height: Metrics.sectionHeaderHeight)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.rowRadius - 2, style: .continuous)
                        .fill(index == selected ? Palette.fillSelected : ColorToken.clear)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tag \(tag)")
                .accessibilityAddTraits(index == selected ? .isSelected : [])
            }
        }
        .padding(Metrics.unit)
        .frame(width: Metrics.tagSuggestionsWidth)
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
}
