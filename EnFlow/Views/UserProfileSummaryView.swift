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
                Text("Cups per day: \(profile.caffeineIntakePerDay)")
                Text("Last at: \(time(profile.caffeineTimeLastUsed))")
            }
            Section("Activity") {
                Text("Exercise per week: \(profile.exerciseFrequency)")
                Text("Stress: \(profile.stressLevel)/5")
            }
            if let notes = profile.notes, !notes.isEmpty {
                Section("Notes") { Text(notes) }
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
