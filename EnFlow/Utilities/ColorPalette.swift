//  ColorPalette.swift
//  EnFlow – Centralised colour logic
//
//  Added 2025-06-17: navy→aqua→lime→yellow ramp + helpers.
//

import SwiftUI

enum ColorPalette {

    // ------------------------------------------------------------------------
    // MARK: – Core ramp (0-100)
    // ------------------------------------------------------------------------

    private static let stops: [Double: Color] = [
        0   : Color(red: 0.05, green: 0.08, blue: 0.20),            // dark-navy
        33  : Color(red: 0.00, green: 0.60, blue: 0.88),            // aqua
        66  : Color(red: 0.45, green: 0.85, blue: 0.35),            // lime
        100 : Color(red: 0.95, green: 0.90, blue: 0.25)             // yellow
    ]

    /// Single flat colour for a percentile score (0-100).
    static func color(for score: Double) -> Color {
        let s = score.clamped(to: 0...100)

        // linear interpolation between nearest lower/upper stop
        let keys = stops.keys.sorted()
        guard let lowerKey = keys.last(where: { $0 <= s }),
              let upperKey = keys.first(where: { $0 >= s }) else { return stops[100]! }

        if lowerKey == upperKey { return stops[lowerKey]! }

        let fraction = (s - lowerKey) / (upperKey - lowerKey)
        return stops[lowerKey]!.interpolated(to: stops[upperKey]!, amount: fraction)
    }

    /// Left→right gradient matching the score.
    static func gradient(for score: Double) -> LinearGradient {
        let base = color(for: score)
        return LinearGradient(
            colors: [base.opacity(0.6), base],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Micro-tile gradient (top-left → bottom-right) for month-grid tiles.
    static func microGradient(for score: Double) -> LinearGradient {
        let base = color(for: score)
        return LinearGradient(
            colors: [base.opacity(0.28), base.opacity(0.9)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// --------------------------------------------------------------------
// MARK: – Utility extensions
// --------------------------------------------------------------------

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension Color {
    /// Linear RGB space interpolation (naïve but fine for UI tinting).
    func interpolated(to other: Color, amount t: Double) -> Color {
        let (r1,g1,b1,a1) = rgbaComponents()
        let (r2,g2,b2,a2) = other.rgbaComponents()
        return Color(
            red:   r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue:  b1 + (b2 - b1) * t,
            opacity: a1 + (a2 - a1) * t
        )
    }

    /// Extract RGBA components (in sRGB) – safe for custom interpolation.
    private func rgbaComponents() -> (Double,Double,Double,Double) {
        #if os(iOS) || os(tvOS) || os(watchOS)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
        #else
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(self).usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
        #endif
    }
}
