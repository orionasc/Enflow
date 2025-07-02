import SwiftUI

struct UserProfileQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile: UserProfile = UserProfileStore.load()

    var body: some View {
        NavigationView {
            Form {
                Section("Sleep") {
                    DatePicker("Usual Wake Time", selection: $profile.typicalWakeTime, displayedComponents: .hourAndMinute)
                    DatePicker("Usual Bed Time", selection: $profile.typicalSleepTime, displayedComponents: .hourAndMinute)
                    Toggle("Use Sleep Aid", isOn: $profile.usesSleepAid)
                    Toggle("Screens Before Bed", isOn: $profile.screensBeforeBed)
                    Toggle("Regular Meals", isOn: $profile.mealsRegular)
                    Picker("Most Energy [Self Report]", selection: $profile.chronotype) {
                        ForEach(UserProfile.Chronotype.allCases) { c in
                            Text(c.rawValue.capitalized).tag(Optional(c))
                        }
                    }
                }

                Section("Caffeine") {
                    Stepper("Daily Intake (mg): \(profile.caffeineMgPerDay)", value: $profile.caffeineMgPerDay, in: 0...1000, step: 10)
                    Toggle("Morning", isOn: $profile.caffeineMorning)
                    Toggle("Afternoon", isOn: $profile.caffeineAfternoon)
                    Toggle("Evening", isOn: $profile.caffeineEvening)
                    Text("e.g. 1 cup coffee ≈ 95 mg, 1 iced tea ≈ 40 mg")
                        .font(.footnote).foregroundColor(.secondary)
                }

                Section("Activity") {
                    Stepper("Exercise per Week: \(profile.exerciseFrequency)", value: $profile.exerciseFrequency, in: 0...14)
                }

                Section("Additional Notes for Sol?") {
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
