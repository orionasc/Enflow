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
                Text("\(profile.caffeineMgPerDay) mg/day")
                Text(caffeineTimes(profile))
            }
            Section("Activity") {
                Text("Exercise per week: \(profile.exerciseFrequency)")
            }
            if let notes = profile.notes, !notes.isEmpty {
                Section("Notes") { Text(notes) }
            }
            Section("Debug") { Text(profile.debugSummary()) }
            Section {
                NavigationLink("Data") { DataView() }
            }
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

    private func caffeineTimes(_ p: UserProfile) -> String {
        let parts = [
            p.caffeineMorning ? "Morning" : nil,
            p.caffeineAfternoon ? "Afternoon" : nil,
            p.caffeineEvening ? "Evening" : nil
        ].compactMap { $0 }
        return parts.isEmpty ? "No set time" : parts.joined(separator: ", ")
    }
}
