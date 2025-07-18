import SwiftUI

/// Small warning icon that shows a popover with details when tapped or hovered.
struct WarningIconButton: View {
    let message: String
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .buttonStyle(.embossedWarning)
        .accessibilityLabel(message)
        .help(message)
        .popover(isPresented: $show) {
            Text(message)
                .font(.body)
                .padding()
                .frame(maxWidth: 240)
        }
    }
}
