import SwiftUI

/// Button style for ℹ️ icons with an embossed look.
struct EmbossedInfoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white.opacity(0.7))
            .padding(6)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .shadow(color: .black.opacity(0.4), radius: configuration.isPressed ? 1 : 2, x: 1, y: 1)
                    .shadow(color: .white.opacity(0.4), radius: configuration.isPressed ? 1 : 2, x: -1, y: -1)
            )
            .clipShape(Circle())
    }
}

extension ButtonStyle where Self == EmbossedInfoButtonStyle {
    static var embossedInfo: EmbossedInfoButtonStyle { EmbossedInfoButtonStyle() }
}
