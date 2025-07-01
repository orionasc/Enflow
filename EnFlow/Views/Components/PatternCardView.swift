import SwiftUI

/// Displays a detected calendar pattern with its impact on energy.
struct PatternCardView: View {
    let pattern: DetectedPattern
    @State private var showExamples = false

    /// Returns the textual confidence label.
    private var confidenceLabel: String {
        pattern.confidence >= 0.8 ? "High Confidence" : "Emerging Pattern"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pattern.pattern)
                .font(.headline)

            HStack {
                Text(pattern.effect)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(confidenceLabel)
                    .font(.caption.bold())
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(Color.blue.opacity(0.2)))
            }

            if showExamples {
                Text("Example days: …")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
        .onTapGesture {
            withAnimation { showExamples.toggle() }
        }
    }
}

#if DEBUG
struct PatternCardView_Previews: PreviewProvider {
    static var previews: some View {
        PatternCardView(pattern: DetectedPattern(pattern: "3+ meetings after 1 PM",
                                                effect: "-18% energy",
                                                evidenceCount: 5,
                                                confidence: 0.85))
            .padding()
            .previewLayout(.sizeThatFits)
            .background(Color.black)
    }
}
#endif
