import SwiftUI

/// A soft highlight sweeping across a placeholder while its image loads (design.md §4: "a subtle
/// shimmer on the thumbnail, never a blocking spinner"). Still under Reduce Motion.
struct ShimmerPlaceholder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        Rectangle()
            .fill(Palette.fillKeycap)
            .overlay {
                if !reduceMotion {
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [.clear, Palette.fillSelected.color, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.6)
                        .offset(x: phase * geometry.size.width * 1.3)
                    }
                }
            }
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: Motion.shimmer).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .accessibilityLabel("Loading")
    }
}
