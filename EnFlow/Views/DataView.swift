import SwiftUI

/// DataView lists recent HealthEvent values and optional raw Calendar events.
enum DataRange: String, CaseIterable, Identifiable {
    case week = "7 Days"
    case month = "30 Days"
    case allTime = "All Time"
    var id: String { rawValue }
}

struct DataView: View {
    @State private var healthEvents: [HealthEvent] = []
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var showCalendarEvents = false
    @State private var showDateSheet = false
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
    @State private var endDate: Date = Date()
    @State private var range: DataRange = .week
    @State private var isLoading = false
    @ObservedObject private var dataMode = DataModeManager.shared
    @Environment(\.dismiss) private var dismiss

    /// Sorted list of dates that have either health or calendar data
    private var displayDates: [Date] {
        let cal = Calendar.current
        let healthDays = healthEvents.map { cal.startOfDay(for: $0.date) }
        let eventDays  = calendarEvents.map { cal.startOfDay(for: $0.startTime) }
        let unique = Set(healthDays + eventDays)
        return unique.sorted(by: >)
    }

    var body: some View {
        ZStack {
            List {
                Picker("Range", selection: $range) {
                    ForEach(DataRange.allCases) { r in Text(r.rawValue).tag(r) }
                }
                .pickerStyle(.segmented)
                .onChange(of: range) { _ in
                    applyRange()
                    Task {
                        await loadHealth()
                        if showCalendarEvents { await loadCalendar() }
                    }
                }

                Section("Health Data") {
                    ForEach(displayDates, id: \.self) { day in
                        HStack(alignment: .top) {
                            healthColumn(for: healthEvent(for: day), day: day)
                            if showCalendarEvents {
                                Divider()
                                calendarColumn(for: eventsForDay(day))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Toggle("Use Simulated Health Data", isOn: Binding(
                    get: { dataMode.isSimulated() },
                    set: { DataModeManager.shared.setMode($0 ? .simulated : .real) }
                ))

                Toggle("Show Calendar Events", isOn: $showCalendarEvents)
                    .onChange(of: showCalendarEvents) { val in
                        if val { Task { await loadCalendar() } }
                    }
            }
        if isLoading {
            ProgressView().progressViewStyle(.circular)
        }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Data")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                        Text("Back")
                    }
                }
                .padding(.leading, 32)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showDateSheet = true } label: {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel("Choose Date Range")
            }
        }
        .sheet(isPresented: $showDateSheet) { dateRangeSheet }
        .task { await loadHealth() }
        .onReceive(NotificationCenter.default.publisher(for: .didChangeDataMode)) { _ in
            Task {
                await loadHealth()
                if showCalendarEvents { await loadCalendar() }
            }
        }
        .enflowBackground()
    }

    private func loadHealth() async {
        isLoading = true
        let daysToFetch = max(Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0, 0) + 1
        let all = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: daysToFetch)
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        healthEvents = all.filter { $0.date >= start && $0.date <= end }
            .sorted { $0.date > $1.date }
        isLoading = false
    }


    private func loadCalendar() async {
        isLoading = true
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDate)) ?? endDate
        calendarEvents = await CalendarDataPipeline.shared.fetchEvents(start: start, end: end)
        isLoading = false
    }

    private func healthEvent(for day: Date) -> HealthEvent? {
        let cal = Calendar.current
        return healthEvents.first { cal.isDate($0.date, inSameDayAs: day) }
    }

    private func eventsForDay(_ day: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        return calendarEvents.filter { cal.isDate($0.startTime, inSameDayAs: day) }
    }

    @ViewBuilder
    private func healthColumn(for event: HealthEvent?, day: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day, format: .dateTime.month().day())
                .font(.headline)
            if let h = event {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Steps: \(h.steps)")
                    Text("Avg HR: \(Int(h.heartRate)) bpm")
                    Text("HRV: \(Int(h.hrv)) ms")
                    Text("Resting HR: \(Int(h.restingHR)) bpm")
                    Text("Sleep Eff: \(Int(h.sleepEfficiency)) %")
                    Text("Sleep Latency: \(Int(h.sleepLatency)) min")
                    Text("Deep Sleep: \(Int(h.deepSleep)) min")
                    Text("REM Sleep: \(Int(h.remSleep)) min")
                    Text("Time in Bed: \(Int(h.timeInBed)) min")
                    Text("Calories: \(Int(h.calories)) kcal")
                }
                .font(.caption)
            } else {
                Text("No Data")
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private func calendarColumn(for events: [CalendarEvent]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if events.isEmpty {
                Text("No Events")
                    .font(.caption)
            } else {
                ForEach(events) { ev in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ev.startTime, format: .dateTime.hour().minute())
                            .font(.subheadline)
                        Text(ev.eventTitle)
                            .font(.caption)
                        if let delta = ev.energyDelta {
                            Text("Δ \(String(format: "%.2f", delta))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func applyRange() {
        let cal = Calendar.current
        switch range {
        case .week:
            startDate = cal.date(byAdding: .day, value: -6, to: Date())!
            endDate = Date()
        case .month:
            startDate = cal.date(byAdding: .day, value: -29, to: Date())!
            endDate = Date()
        case .allTime:
            startDate = Date(timeIntervalSince1970: 0)
            endDate = Date()
        }
    }

    @ViewBuilder private var dateRangeSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                Button("Done") {
                    showDateSheet = false
                    Task { await loadHealth() }
                }
                .padding()
            }
            .padding()
            .navigationTitle("Select Range")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showDateSheet = false } } }
        }
    }
}

struct DataView_Previews: PreviewProvider {
    static var previews: some View { DataView() }
}
