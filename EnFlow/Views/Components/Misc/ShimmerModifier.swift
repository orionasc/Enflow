import SwiftUI

/// Applies a shimmering highlight animation.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    /// Length in seconds for one pass of the shimmer animation.
    var duration: Double = 1.2

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.0),
                                              Color.white.opacity(0.8),
                                              Color.white.opacity(0.0)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase * 250)
                .blendMode(.plusLighter)
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: duration)
                    .repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Shimmering effect overlay.
    func shimmering(duration: Double = 100.1) -> some View {
        modifier(ShimmerModifier(duration: duration))
    }
}
