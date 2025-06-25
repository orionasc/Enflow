import SwiftUI

struct UserProfileQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile: UserProfile = UserProfileStore.load()

    var body: some View {
        NavigationView {
            Form {
                Section("Sleep") {
                    DatePicker("Wake Time", selection: $profile.typicalWakeTime, displayedComponents: .hourAndMinute)
                    DatePicker("Sleep Time", selection: $profile.typicalSleepTime, displayedComponents: .hourAndMinute)
                    Toggle("Use Sleep Aid", isOn: $profile.usesSleepAid)
                    Toggle("Screens Before Bed", isOn: $profile.screensBeforeBed)
                    Toggle("Regular Meals", isOn: $profile.mealsRegular)
                    Picker("Chronotype", selection: $profile.chronotype) {
                        ForEach(UserProfile.Chronotype.allCases) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }
                }

                Section("Caffeine") {
                    Stepper("Cups per Day: \(profile.caffeineIntakePerDay)", value: $profile.caffeineIntakePerDay, in: 0...10)
                    DatePicker("Last Caffeine", selection: $profile.caffeineTimeLastUsed, displayedComponents: .hourAndMinute)
                }

                Section("Activity") {
                    Stepper("Exercise per Week: \(profile.exerciseFrequency)", value: $profile.exerciseFrequency, in: 0...14)
                    Picker("Stress Level", selection: $profile.stressLevel) {
                        ForEach(1...5, id: \.self) { v in Text("\(v)").tag(v) }
                    }
                }

                Section("Notes") {
                    TextEditor(text: Binding(get: { profile.notes ?? "" }, set: { profile.notes = $0 }))
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Your Habits")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func save() {
        profile.lastUpdated = Date()
        UserProfileStore.save(profile)
        dismiss()
    }
}
