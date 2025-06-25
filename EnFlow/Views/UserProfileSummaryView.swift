import SwiftUI

struct UserProfileSummaryView: View {
    @State private var profile: UserProfile = UserProfileStore.load()
    @State private var showEdit = false

    var body: some View {
        List {
            Section("Sleep") {
                Text("Wake: \(time(profile.typicalWakeTime))")
                Text("Sleep: \(time(profile.typicalSleepTime))")
                Text("Chronotype: \(profile.chronotype.rawValue.capitalized)")
            }
            Section("Caffeine") {
                Text("Intake: \(profile.caffeineMgPerDay) mg/day")
                Text("Morning: \(profile.caffeineMorning ? "Yes" : "No")")
                Text("Afternoon: \(profile.caffeineAfternoon ? "Yes" : "No")")
                Text("Evening: \(profile.caffeineEvening ? "Yes" : "No")")
                Text("e.g. 1 cup coffee ≈ 95 mg, 1 iced tea ≈ 40 mg")
                    .font(.footnote).foregroundColor(.secondary)
            }
            Section("Activity") {
                Text("Exercise per week: \(profile.exerciseFrequency)")
            }
            if let notes = profile.notes, !notes.isEmpty {
                Section("Notes") { Text(notes) }
            }
            Section {
                NavigationLink("Data") {
                    DataView()
                }
            }
            Section("Debug") { Text(profile.debugSummary()) }
        }
        .navigationTitle("User Profile")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit Profile") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: { profile = UserProfileStore.load() }) {
            UserProfileQuizView()
        }
    }

    private func time(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: d)
    }
}
