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
            // Dropdown Header — Top Right + Insights button
            HStack {
                Button {
                    showInsights = true
                } label: {
                    Image(systemName: "lightbulb")
                        .font(.title3)
                        .padding(8)
                }
                .sheet(isPresented: $showInsights) {
                    CalendarInsightsPopup(viewModel: insightsModel)
                        .presentationDetents([.medium])
                }
                Spacer()
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
            }
            .padding(.top, 12)
            .padding(.horizontal, 20)

            // Dynamic View Injection
            switch mode {
            case .day:
                DayView(date: Date())
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
