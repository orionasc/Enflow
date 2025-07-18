//  CardModifier.swift
//  EnFlow
//

import SwiftUI

struct CardModifier: ViewModifier {
    var tintScore: Double

    /// default tint = 70 (mid-range green)
    init(tintScore: Double = 70) { self.tintScore = tintScore }

    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                ZStack {
                    ColorPalette.gradient(for: tintScore).opacity(0.25)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.06), .clear]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 4)
    }
}

extension View {
    /// Convenience: `.cardStyle()` or `.cardStyle(tint: 40)`
    func cardStyle(tint: Double = 70) -> some View {
        modifier(CardModifier(tintScore: tint))
    }
}
