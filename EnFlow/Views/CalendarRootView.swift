//  CalendarRootView.swift
//  EnFlow — Unified calendar container with styled dropdown nav and gradient background

import SwiftUI

enum CalendarMode: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }
}

struct CalendarRootView: View {
    @State private var mode: CalendarMode = .day
    @State private var showInsights = false
    @StateObject private var insightsModel = CalendarInsightsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Dropdown Header with centered Insights button + mode menu
            HStack(spacing: 12) {
                Spacer(minLength: 0)
                Button(action: { showInsights = true }) {
                    Text("Insights")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
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
                Menu {
                    ForEach(CalendarMode.allCases) { option in
                        Button {
                            withAnimation { mode = option }
                        } label: {
                            Label(option.rawValue, systemImage: mode == option ? "checkmark.circle.fill" : "circle")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(mode.rawValue)
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .offset(y: 1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                            .shadow(radius: 2)
                    )
                }
                .foregroundColor(.white)
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .padding(.horizontal, 20)
            .sheet(isPresented: $showInsights) {
                CalendarInsightsPopup(viewModel: insightsModel)
                    .task { await loadInsights() }
                    .presentationDetents([.medium])
            }

            // Dynamic View Injection
            switch mode {
            case .day:
                // Use startOfDay to ensure DayView loads energy correctly
                DayView(date: Calendar.current.startOfDay(for: Date()))
                    .transition(.opacity)
            case .week:
                WeekCalendarView()
                    .transition(.opacity)
            case .month:
                MonthCalendarView()
                    .transition(.opacity)
            }
        }
        .enflowBackground()
        .animation(.easeInOut(duration: 0.25), value: mode)
        .edgesIgnoringSafeArea(.bottom)
        .task { await loadInsights() }
    }

    private func loadInsights() async {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -30, to: end) else { return }

        let health = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: 30)
        let events = await CalendarDataPipeline.shared.fetchEvents(start: start, end: end)

        var summaries: [DayEnergySummary] = []
        for offset in 0..<30 {
            if let day = cal.date(byAdding: .day, value: offset, to: start) {
                let h = health.filter { cal.isDate($0.date, inSameDayAs: day) }
                let e = events.filter { cal.isDate($0.startTime, inSameDayAs: day) }
                let profile = UserProfileStore.load()
                let summary = UnifiedEnergyModel.shared.summary(for: day,
                                                               healthEvents: h,
                                                               calendarEvents: e,
                                                               profile: profile)
                summaries.append(summary)
            }
        }

        let patterns = PatternDetectionEngine().detectPatterns(events: events,
                                                               summaries: summaries)
        await insightsModel.loadInsights(from: patterns)
    }
}

struct CalendarRootView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarRootView()
    }
}
