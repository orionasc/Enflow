import SwiftUI

/// Simple button style that provides a press-down scale animation.
struct ScalingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == ScalingButtonStyle {
    static var scaling: ScalingButtonStyle { ScalingButtonStyle() }
}
