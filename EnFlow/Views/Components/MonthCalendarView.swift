//  MonthCalendarView.swift
//  EnFlow — Month view with full overflow tiles, snap‐scroll months, and floating trends button

import SwiftUI

struct MonthCalendarView: View {
    @State private var energyMap: [Date: Double] = [:]
    @State private var displayMonth: Date = Calendar.current.startOfDay(for: Date())
    @State private var showMonthlyTrends = false

    private let calendar = Calendar.current

    /// Builds a 6×7 grid of dates: overflow from prev month + this month + next month
    private var monthDates: [Date] {
        let comps = calendar.dateComponents([.year, .month], from: displayMonth)
        let startOfMonth = calendar.date(from: comps)!
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)!
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)

        var grid: [Date] = []

        // leading days (previous month)
        for offset in stride(from: firstWeekday - 1, to: 0, by: -1) {
            if let d = calendar.date(byAdding: .day, value: -offset, to: startOfMonth) {
                grid.append(d)
            }
        }
        // this month
        for day in daysInMonth {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                grid.append(d)
            }
        }
        // trailing days (next month) to fill 6×7
        while grid.count % 7 != 0 || grid.count < 42 {
            if let last = grid.last,
               let nxt  = calendar.date(byAdding: .day, value: 1, to: last) {
                grid.append(nxt)
            }
        }
        return grid
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.enflowBackground()

                VStack(spacing: 8) {
                    // Month header with up/down chevrons
                    HStack {
                        Button { changeMonth(by: -1) } label: {
                            Image(systemName: "chevron.up")
                                .font(.title3)
                                .padding(8)
                        }
                        Spacer()
                        Text(displayMonth, format: .dateTime.month().year())
                            .font(.title2.bold())
                        Spacer()
                        Button { changeMonth(by: 1) } label: {
                            Image(systemName: "chevron.down")
                                .font(.title3)
                                .padding(8)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    // 6×7 grid of date-tiles
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 7),
                        spacing: 8
                    ) {
                        ForEach(monthDates, id: \.self) { date in
                            NavigationLink(destination: DayView(date: date, showBackButton: true)) {
                                tile(for: date)
                            }
                        }
                    }
                    .padding(.horizontal, 8)

                    Spacer()
                }
                // vertical-swipe to snap between months
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { val in
                            if val.translation.height < -50 {
                                withAnimation(.easeOut) { changeMonth(by: 1) }
                            } else if val.translation.height > 50 {
                                withAnimation(.easeOut) { changeMonth(by: -1) }
                            }
                        }
                )
                .task(id: displayMonth) { await loadEnergy() }

                // Floating “Monthly Trends” button (raised above tab bar)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showMonthlyTrends = true
                        } label: {
                            Label("Monthly Trends", systemImage: "chart.bar.fill")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.ultraThinMaterial)
                                        .shadow(radius: 4)
                                )
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 80) // raised to clear tab bar
                        .sheet(isPresented: $showMonthlyTrends) {
                            // Stubbed trends bar
                            VStack {
                                Capsule()
                                    .frame(width: 40, height: 5)
                                    .padding(.top, 8)
                                Text("Monthly Trends")
                                    .font(.headline)
                                    .padding()
                                Spacer()
                            }
                            .presentationDetents([.medium, .large])
                        }
                    }
                }
            }
        }
    }

    // MARK: – Helper functions

    private func changeMonth(by delta: Int) {
        if let newMonth = calendar.date(
            byAdding: .month,
            value: delta,
            to: displayMonth
        ) {
            displayMonth = newMonth
        }
    }

    @ViewBuilder
    private func tile(for date: Date) -> some View {
        let isCurrent = calendar.isDate(date, equalTo: displayMonth, toGranularity: .month)
        let energy    = energyMap[date] ?? -1

        ZStack {
            if isCurrent {
                ColorPalette.color(for: energy)
                    .opacity(0.25)
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.08),
                                Color.black.opacity(0.15)
                            ]),
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.04),
                        Color.black.opacity(0.10)
                    ]),
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }

            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption.weight(.medium))
                    .foregroundColor(isCurrent ? .white : .gray)

                if isCurrent, energy >= 0 {
                    Capsule()
                        .fill(ColorPalette.gradient(for: energy))
                        .frame(width: 20, height: 4)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        calendar.isDateInToday(date) ? Color.orange : .clear,
                        lineWidth: 2
                    )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .aspectRatio(1, contentMode: .fit)
    }

    private func loadEnergy() async {
        var results: [Date: Double] = [:]

        let allHealth = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: 60)
        let monthStart = calendar.date(
            byAdding: .month,
            value: -1,
            to: displayMonth
        ) ?? displayMonth
        let allEvents = await CalendarDataPipeline.shared.fetchEvents(
            start: monthStart,
            end: calendar.date(byAdding: .month, value: 1, to: displayMonth)!
        )

        for date in monthDates where calendar.isDate(date, equalTo: displayMonth, toGranularity: .month) {
            let dayHealth = allHealth.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let dayEvents = allEvents.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
            let summary = UnifiedEnergyModel.shared.summary(for: date,
                                                           healthEvents: dayHealth,
                                                           calendarEvents: dayEvents)
            results[date] = summary.overallEnergyScore
        }

        await MainActor.run { energyMap = results }
    }
}


