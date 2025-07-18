import SwiftUI

/// Capsule tag used to display short rationale labels.
struct RationaleChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15))
            )
    }
}

#Preview {
    RationaleChip(text: "Low HRV")
        .padding()
        .background(Color.black)
}
