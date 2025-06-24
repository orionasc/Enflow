import SwiftUI

/// DataView lists recent HealthEvent values and optional raw Calendar events.
struct DataView: View {
    @State private var healthEvents: [HealthEvent] = []
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var showCalendar = false
    @AppStorage("useSimulatedHealthData") private var useSimulatedHealthData = false

    var body: some View {
        List {
            Toggle("Use Simulated Health Data", isOn: $useSimulatedHealthData)
                .onChange(of: useSimulatedHealthData) { _ in Task { await loadHealth() } }

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
                }
            }
            if showCalendar {
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
        .navigationTitle("Data")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCalendar.toggle()
                    if showCalendar { Task { await loadCalendar() } }
                } label: {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel(showCalendar ? "Hide Calendar" : "Show Calendar")
            }
        }
        .task { await loadHealth() }
        .enflowBackground()
    }

    private func loadHealth() async {
        healthEvents = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: 7)
    }

    private func loadCalendar() async {
        calendarEvents = await CalendarDataPipeline.shared.fetchUpcomingDays(days: 7)
    }
}

struct DataView_Previews: PreviewProvider {
    static var previews: some View { DataView() }
}
