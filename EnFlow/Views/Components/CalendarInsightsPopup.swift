import SwiftUI

/// Compact popup displaying calendar-related insights.
struct CalendarInsightsPopup: View {
    /// Patterns requiring GPT summaries.
    let patterns: [DetectedPattern]
    /// Dismissal handler provided by the sheet presenter.
    var dismiss: () -> Void

    /// Loaded insight texts.
    @State private var insights: [String] = []
    /// Fallback text shown if GPT doesn't return a summary.
    private let fallbackMessage = "EnFlow is working on your predictions, stay tuned for updates!..."

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Energy Insights")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 4)
                        if insights.isEmpty {
                            InsightBannerView(
                                text: fallbackMessage,
                                icon: "hourglass"
                            )
                        } else {
                            ForEach(insights, id: \.self) { line in
                                InsightBannerView(
                                    text: line,
                                    icon: line == fallbackMessage ? "hourglass" : "lightbulb"
                                )
                            }
                        }
                    }
                    .padding()
                }
                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
                    .padding()
            }
            .frame(width: proxy.size.width * 0.9)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .cornerRadius(20)
            .shadow(radius: 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .enflowBackground()
        }
        .task { await loadInsights() }
    }

    /// Generates summaries for all detected patterns in parallel.
    @MainActor
    private func loadInsights() async {
        guard !patterns.isEmpty else { return }

        var seen = Set<String>()

        await withTaskGroup(of: String.self) { group in
            for pattern in patterns {
                group.addTask { await generateGPTInsight(from: pattern) }
            }

            for await raw in group {
                let text = raw == fallbackMessage ?
                    fallbackMessage : raw
                if seen.insert(text).inserted {
                    insights.append(text)
                }
            }
        }
    }
}

