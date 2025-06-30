import SwiftUI

struct SuggestedPrioritiesInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showProfileQuiz = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(PriorityTemplate.allCases, id: \.\.self) { t in
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

    private func priorityRow(_ template: PriorityTemplate) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: template.sfSymbol)
                .font(.title2)
                .frame(width: 32)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(template.title)
                    .font(.headline)
                Text(template.blurb)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    SuggestedPrioritiesInfoView()
}
