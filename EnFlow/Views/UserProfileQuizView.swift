import SwiftUI

struct UserProfileQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile: UserProfile = UserProfileStore.load()
    @State private var lastValidWake: Date = UserProfileStore.load().typicalWakeTime
    @State private var lastValidSleep: Date = UserProfileStore.load().typicalSleepTime
    @State private var sleepError: String? = nil

    var body: some View {
        NavigationView {
            Form {
                Section("Sleep") {
                    DatePicker("Usual Wake Time", selection: $profile.typicalWakeTime, displayedComponents: .hourAndMinute)
                        .onChange(of: profile.typicalWakeTime) { handleWakeChange($0) }
                    DatePicker("Usual Bed Time", selection: $profile.typicalSleepTime, displayedComponents: .hourAndMinute)
                        .onChange(of: profile.typicalSleepTime) { handleSleepChange($0) }
                    if let sleepError {
                        Text(sleepError)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                    Toggle("Use Sleep Aid", isOn: $profile.usesSleepAid)
                    Toggle("Screens Before Bed", isOn: $profile.screensBeforeBed)
                    Toggle("Regular Meals", isOn: $profile.mealsRegular)
                    HStack {
                        Picker("Most Energy [Self Report]", selection: $profile.chronotype) {
                            ForEach(UserProfile.Chronotype.selectableCases) { c in
                                Text(c.rawValue.capitalized).tag(c)
                            }
                        }
                        Button {
                            profile.chronotype = .none
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("When do you feel you have the most energy?")
                        .font(.footnote)
                        .foregroundColor(.secondary)
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

    private func validWakeSleep(wake: Date, sleep: Date) -> Bool {
        var interval = sleep.timeIntervalSince(wake)
        if interval < 0 { interval += 24 * 3600 }
        return interval >= 12 * 3600
    }

    private func handleWakeChange(_ new: Date) {
        if validWakeSleep(wake: new, sleep: profile.typicalSleepTime) {
            lastValidWake = new
            sleepError = nil
            profile.typicalWakeTime = new
        } else {
            profile.typicalWakeTime = lastValidWake
            sleepError = "Need 12h gap"
        }
    }

    private func handleSleepChange(_ new: Date) {
        if validWakeSleep(wake: profile.typicalWakeTime, sleep: new) {
            lastValidSleep = new
            sleepError = nil
            profile.typicalSleepTime = new
        } else {
            profile.typicalSleepTime = lastValidSleep
            sleepError = "Need 12h gap"
        }
    }
}
