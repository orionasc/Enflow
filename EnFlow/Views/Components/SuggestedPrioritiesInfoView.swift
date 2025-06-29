import SwiftUI

struct SuggestedPrioritiesInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showProfileQuiz = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(SuggestedPriorityTemplate.allCases) { t in
                        priorityRow(t)
                    }
                    Divider()
                    Text("Sol combines 3-part energy forecasts with your calendar gaps, sleep quality and HRV trends. A GPT engine ranks templates by fit. Your feedback — pin, snooze or dismiss — tunes future recommendations.")
                        .font(.body)
                    Button("Update your profile") { showProfileQuiz = true }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding()
            }
            .navigationTitle("How Priorities Are Picked")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showProfileQuiz) { NavigationStack { UserProfileQuizView() } }
        }
    }

    private func priorityRow(_ template: SuggestedPriorityTemplate) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: template.sfSymbol)
                .font(.title2)
                .frame(width: 32)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(template.rawValue)
                    .font(.headline)
                Text(blurb(for: template))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func blurb(for t: SuggestedPriorityTemplate) -> String {
        switch t {
        case .deepWork:           return "Best used during peak mental energy."
        case .lightAdmin:         return "Great for lower focus periods."
        case .activeRecovery:     return "Helps you bounce back after effort."
        case .socialRecharge:     return "Connect with others to restore mood."
        case .morningReflection:  return "Start your day with clarity."
        case .windDown:           return "Ideal near bedtime or after intense sessions."
        case .creativeSpur:       return "Suggested when mental energy is high but physical is moderate."
        case .quickPhysicalReset: return "Short movement to perk up energy."
        }
    }
}

#Preview {
    SuggestedPrioritiesInfoView()
}
