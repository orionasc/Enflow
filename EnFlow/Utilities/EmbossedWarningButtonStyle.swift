import SwiftUI

/// Button style for warning icons with an embossed glow.
struct EmbossedWarningButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.yellow)
            .padding(4)
            .background(
                Circle()
                    .fill(Color.yellow.opacity(0.25))
                    .shadow(color: .black.opacity(0.4), radius: configuration.isPressed ? 1 : 2, x: 1, y: 1)
                    .shadow(color: .white.opacity(0.4), radius: configuration.isPressed ? 1 : 2, x: -1, y: -1)
            )
            .clipShape(Circle())
    }
}

extension ButtonStyle where Self == EmbossedWarningButtonStyle {
    static var embossedWarning: EmbossedWarningButtonStyle { EmbossedWarningButtonStyle() }
}
