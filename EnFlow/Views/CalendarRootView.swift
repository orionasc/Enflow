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
    @State private var patterns: [DetectedPattern] = []

    var body: some View {
        VStack(spacing: 0) {
            // Dropdown header with trailing Insights button and mode menu
            HStack(spacing: 12) {
                Spacer(minLength: 0)
                Button(action: { showInsights = true }) {
                    Image(systemName: "lightbulb.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            Circle().fill(
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
            }
            .padding(.top, 12)
            .padding(.horizontal, 20)
            .sheet(isPresented: $showInsights) {
                CalendarInsightsPopup(patterns: patterns) { showInsights = false }
                    .task { await loadPatterns() }
                    .presentationDetents([.fraction(0.45)])
                    .presentationBackground(.clear)
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
        .task { await loadPatterns() }
    }

    private func loadPatterns() async {
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
                let summary = SummaryProvider.summary(for: day,
                                                     healthEvents: h,
                                                     calendarEvents: e,
                                                     profile: profile)
                summaries.append(summary)
            }
        }

        patterns = PatternDetectionEngine().detectPatterns(events: events,
                                                          summaries: summaries)
    }
}

struct CalendarRootView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarRootView()
    }
}
