import SwiftUI

struct InsightBannerView: View {
    let text: String
    var icon: String = "lightbulb"
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.white)
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color.yellow, Color.orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    InsightBannerView(text: "You're most alert around 10am today.")
        .padding()
        .background(Color.black)
}
