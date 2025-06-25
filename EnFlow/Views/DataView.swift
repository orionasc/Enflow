import SwiftUI

/// DataView lists recent HealthEvent values and optional raw Calendar events.
struct DataView: View {
    @State private var healthEvents: [HealthEvent] = []
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var showCalendarEvents = false
    @State private var showDateSheet = false
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
    @State private var endDate: Date = Date()
    @AppStorage("useSimulatedHealthData") private var useSimulatedHealthData = false

    var body: some View {
        List {
            Toggle("Use Simulated Health Data", isOn: $useSimulatedHealthData)
                .onChange(of: useSimulatedHealthData) { _ in Task { await loadHealth() } }

            Toggle("Show Calendar Events", isOn: $showCalendarEvents)
                .onChange(of: showCalendarEvents) { val in
                    if val { Task { await loadCalendar() } }
                }

            Section("Health Data") {
                ForEach(healthEvents, id: \.date) { h in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(h.date, format: .dateTime.month().day())
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Steps: \(h.steps)")
                            Text("HRV: \(Int(h.hrv)) ms")
                            Text("Resting HR: \(Int(h.restingHR)) bpm")
                            Text("Sleep Eff: \(Int(h.sleepEfficiency)) %")
                            Text("Sleep Latency: \(Int(h.sleepLatency)) min")
                            Text("Deep Sleep: \(Int(h.deepSleep)) min")
                            Text("REM Sleep: \(Int(h.remSleep)) min")
                            Text("Calories: \(Int(h.calories)) kcal")
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                    .onAppear { loadMoreIfNeeded(current: h) }
                }
            }

            if showCalendarEvents {
                Section("Calendar Events") {
                    ForEach(calendarEvents) { ev in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ev.startTime, format: .dateTime.month().day().hour().minute())
                                .font(.headline)
                            Text(ev.eventTitle)
                                .font(.subheadline)
                            if let delta = ev.energyDelta {
                                Text("Δ \(delta, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Data")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showDateSheet = true } label: {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel("Choose Date Range")
            }
        }
        .sheet(isPresented: $showDateSheet) { dateRangeSheet }
        .task { await loadHealth() }
        .enflowBackground()
    }

    private func loadHealth() async {
        let daysToFetch = max(Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0, 0) + 1
        let all = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: daysToFetch)
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        healthEvents = all.filter { $0.date >= start && $0.date <= end }
            .sorted { $0.date > $1.date }
    }


    private func loadCalendar() async {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDate)) ?? endDate
        calendarEvents = await CalendarDataPipeline.shared.fetchEvents(start: start, end: end)
    }

    private func loadMoreIfNeeded(current: HealthEvent) {
        guard current.date == healthEvents.last?.date else { return }
        startDate = Calendar.current.date(byAdding: .day, value: -7, to: startDate) ?? startDate
        Task {
            await loadHealth()
            if showCalendarEvents { await loadCalendar() }
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
