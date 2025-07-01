import SwiftUI

/// Tab item label that highlights the active icon.
struct TabBarLabel: View {
    let title: String
    let systemImage: String
    let index: Int
    @Binding var selection: Int

    var body: some View {
        Label(title, systemImage: systemImage)
            .modifier(ActiveHighlight(isActive: selection == index))
    }
}

private struct ActiveHighlight: ViewModifier {
    var isActive: Bool
    func body(content: Content) -> some View {
        if isActive {
            content
                .foregroundColor(.orange)
                .shimmering()
                .shadow(color: .orange.opacity(0.9), radius: 6)
        } else {
            content
        }
    }
}
