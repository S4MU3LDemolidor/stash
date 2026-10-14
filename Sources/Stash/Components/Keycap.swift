import KeyboardShortcuts
import SwiftUI

/// One key in a shortcut. Shortcuts show one cap per key: `⌘` `K`, not `⌘K`.
struct Keycap: View {
    let key: String

    private var font: Font {
        let isAlphanumeric = key.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains)
        return isAlphanumeric ? Typography.keycap : Typography.keycapSymbol
    }

    var body: some View {
        Text(key)
            .font(font)
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, Metrics.keycapPadding)
            .frame(minWidth: Metrics.keycapMinWidth)
            .frame(height: Metrics.keycapHeight)
            .background(
                RoundedRectangle(cornerRadius: Metrics.keycapRadius, style: .continuous)
                    .fill(Palette.fillKeycap)
            )
    }
}

struct Keycaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: Metrics.keycapGap) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Keycap(key: key)
            }
        }
    }
}

extension KeyboardShortcuts.Name {
    /// The current shortcut split into keycaps, e.g. `["⌥", "⇧", "S"]`. Empty if unset.
    @MainActor
    var keycaps: [String] {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: self) else { return [] }
        let modifiers = shortcut.modifiers.ks_symbolicRepresentation
        let key = String(shortcut.description.dropFirst(modifiers.count))
        return modifiers.map(String.init) + [key]
    }
}
