//  WeekCalendarView.swift
//  EnFlow — Google Calendar-style scrollable week view with improved layout, correct energy, swipe nav

import SwiftUI

struct WeekCalendarView: View {
    @State private var startOfWeek: Date = Calendar.current.startOfWeek(for: Date())
    @State private var energyMatrix: [[Double?]] = Array(
        repeating: Array(repeating: nil, count: 20),
        count: 7
    )
    @State private var events: [CalendarEvent] = []
    @State private var selectedDay: Date? = nil

    private let calendar = Calendar.current
    private let hours = Array(4..<24)   // 4 AM … 11 PM
    private let rowHeight: CGFloat = 44


    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ─── Two-line header: “Week” + “Week of …” ─────────────
                VStack(spacing: 6) {
                    HStack {
                        Button { shiftWeek(by: -1) } label: {
                            Image(systemName: "chevron.left")
                                .padding(8)
                        }
                        Spacer()
                        Button { shiftWeek(by: 1) } label: {
                            Image(systemName: "chevron.right")
                                .padding(8)
                        }
                    }
                    .padding(.horizontal)

                    Text(weekTitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal)
                }
                .padding(.top, 1)
                .padding(.bottom, 80)

                // ─── Week grid, vertical-only scroll ────────────────────
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 1) {
                        // — Column headers (Sun–Sat) —
                        HStack(spacing: 1) {
                            Spacer().frame(width: 46) // time-label column
                            ForEach(0..<7, id: \.self) { day in
                                let date = calendar.date(
                                    byAdding: .day,
                                    value: day,
                                    to: startOfWeek
                                )!
                                VStack(spacing: 4) {
                                    Text(shortWeekday(from: date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    // show correct 0–100 score, not 0
                                    let avgScore = energyMatrix[day].average()
                                    energyChip(score: avgScore != nil ? avgScore! * 100 : nil)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(6)
                                .background(Color.black.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            calendar.isDateInToday(date) ? .orange : .clear,
                                            lineWidth: 2
                                        )
                                )
                                .onTapGesture { selectedDay = date }
                            }
                        }

                        // — Hour rows with events spanning multi-hour durations —
                        ForEach(0..<hours.count, id: \.self) { hIndex in
                            HStack(spacing: 1) {
                                Text(hourLabel(hours[hIndex]))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 46, alignment: .trailing)

                                ForEach(0..<7, id: \.self) { day in
                                    let energyPct     = (energyMatrix[day][hIndex] ?? 0) * 100
                                    let nextEnergyPct = (hIndex + 1 < hours.count
                                                         ? (energyMatrix[day][hIndex + 1] ?? 0) * 100
                                                         : energyPct)
                                    let date          = calendar.date(byAdding: .day, value: day, to: startOfWeek)!

                                    ZStack(alignment: .topLeading) {
                                        // Smooth vertical blend when we have data
                                        if energyMatrix[day][hIndex] != nil {
                                            LinearGradient(
                                                gradient: Gradient(stops: [
                                                    .init(color: ColorPalette.color(for: energyPct).opacity(0.2), location: 0),
                                                    .init(color: ColorPalette.color(for: nextEnergyPct).opacity(0.2), location: 1)
                                                ]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        } else {
                                            Color.clear
                                        }

                                        ForEach(eventsForHour(date: date, hour: hours[hIndex]), id: \.id) { ev in
                                            // compute minute‐fraction offset
                                            let startMinute = calendar.component(.minute, from: ev.startTime)
                                            let minuteOffset = rowHeight * CGFloat(startMinute) / 60

                                            RoundedRectangle(cornerRadius: 6)
                                              .fill(.ultraThinMaterial)
                                              // full height = duration in hours × rowHeight
                                              .frame(height: eventHeight(from: ev))
                                              .overlay(
                                                Text(ev.eventTitle)
                                                  .font(.caption2.bold())
                                                  .padding(4)
                                                  .lineLimit(1),
                                                alignment: .topLeading
                                              )
                                              // shift down by the start‐minute fraction
                                              .offset(x: 2, y: minuteOffset)
                                            .zIndex(1)

                                        }
                                    }
                                    .frame(height: rowHeight)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 40)
                }
                // tap on a day header drills into DayView
                .navigationDestination(
                    isPresented: Binding(
                        get: { selectedDay != nil },
                        set: { if !$0 { selectedDay = nil } }
                    )
                ) {
                    if let selected = selectedDay {
                        DayView(date: selected)
                    }
                }
            }
            // make the persistent nav-bar show “Week of …” instead of static “Week”
            .navigationTitle(weekTitle)
            .navigationBarTitleDisplayMode(.inline)

            // add left/right swipe anywhere to change weeks
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.width > 50 {
                            shiftWeek(by: -1)
                        } else if value.translation.width < -50 {
                            shiftWeek(by: 1)
                        }
                    }
            )
            .task { await loadWeekData() }
            .enflowBackground()
        }
    }

    // MARK: — Helpers unchanged from original version —

    private func shiftWeek(by delta: Int) {
        if let newStart = calendar.date(
            byAdding: .day,
            value: delta * 7,
            to: startOfWeek
        ) {
            startOfWeek = newStart
            Task { await loadWeekData() }
        }
    }

    private var weekTitle: String {
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        let end = calendar.date(
            byAdding: .day,
            value: 6,
            to: startOfWeek
        ) ?? startOfWeek
        return "Week of \(fmt.string(from: startOfWeek)) – \(fmt.string(from: end))"
    }

    private func shortWeekday(from date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "E"
        return f.string(from: date)
    }

    private func hourLabel(_ hour: Int) -> String {
        var c = DateComponents(); c.hour = hour
        return calendar.date(from: c)?
            .formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
            ?? "\(hour)h"
    }

    private func energyChip(score: Double?) -> some View {
        Text(score != nil ? "\(Int(score!))" : "--")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                if let score {
                    ColorPalette.gradient(for: score)
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .clipShape(Capsule())
    }

    private func eventsForHour(date: Date, hour: Int) -> [CalendarEvent] {
        events.filter {
            calendar.isDate($0.startTime, inSameDayAs: date) &&
            calendar.component(.hour, from: $0.startTime) == hour
        }
    }

    private func eventHeight(from ev: CalendarEvent) -> CGFloat {
        let hours = ev.endTime.timeIntervalSince(ev.startTime) / 3600
        return max(rowHeight, rowHeight * CGFloat(hours))
    }

    private func loadWeekData() async {
        var matrix = Array(
            repeating: Array(repeating: Double?.none, count: hours.count),
            count: 7
        )

        let health = await HealthDataPipeline.shared
            .fetchDailyHealthEvents(daysBack: 7)
        let allEvents = await CalendarDataPipeline.shared
            .fetchEvents(
                start: startOfWeek,
                end: calendar.date(
                    byAdding: .day,
                    value: 7,
                    to: startOfWeek
                ) ?? startOfWeek
            )

        let today = calendar.startOfDay(for: Date())

        for d in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: d, to: startOfWeek) {
                if day > today {
                    matrix[d] = Array(repeating: nil, count: hours.count)
                } else {
                    let dayHealth = health.filter { calendar.isDate($0.date, inSameDayAs: day) }
                   let dayEvents = allEvents.filter { calendar.isDate($0.startTime, inSameDayAs: day) }
                    let profile = UserProfileStore.load()
                    let summary = UnifiedEnergyModel.shared.summary(for: day,
                                                                  healthEvents: dayHealth,
                                                                  calendarEvents: dayEvents,
                                                                  profile: profile)
                    if summary.coverageRatio < 0.3 {
                        matrix[d] = Array(repeating: nil, count: hours.count)
                    } else {
                        matrix[d] = Array(summary.hourlyWaveform[4...23])
                    }
                    events = allEvents
                }
            }
        }

        await MainActor.run {
            energyMatrix = matrix
        }
    }
}

// — Array average extension unchanged —
private extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0.0 }
        return reduce(0, +) / Double(count)
    }
}

private extension Array where Element == Double? {
    func average() -> Double? {
        let vals = compactMap { $0 }
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let comps = dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: date
        )
        return self.date(from: comps) ?? startOfDay(for: date)
    }
}
