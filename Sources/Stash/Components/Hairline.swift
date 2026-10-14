import SwiftUI

/// A one-pixel horizontal divider in the `divider` token.
struct Hairline: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(Palette.divider)
            .frame(height: 1 / displayScale)
    }
}

/// A one-pixel vertical divider in the `divider` token.
struct VerticalHairline: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(Palette.divider)
            .frame(width: 1 / displayScale)
    }
}
