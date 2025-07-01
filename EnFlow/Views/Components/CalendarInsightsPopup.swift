import SwiftUI

/// Compact popup displaying calendar-related insights.
struct CalendarInsightsPopup: View {
    @ObservedObject var viewModel: CalendarInsightsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.insights, id: \.self) { line in
                            InsightBannerView(text: line)
                        }
                    }
                    .padding()
                }
                Button("Close") { dismiss() }
                    .padding()
            }
            .frame(width: proxy.size.width * 0.9)
            .frame(height: proxy.size.height * 0.45)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .cornerRadius(20)
            .shadow(radius: 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .enflowBackground()
        }
    }
}

