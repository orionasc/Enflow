import SwiftUI

struct SuggestedPrioritiesInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showProfileQuiz = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(PriorityTemplate.allCases, id: \.self) { t in
                        priorityRow(t)
                    }
                    Divider()
                    Text("Sol blends energy forecasts with your schedule, sleep and recovery to surface three quick nudges each day. Cards include an urgency badge and short rationale tags so you know why they matter. Pin, snooze or dismiss to refine future picks.")
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
            .enflowBackground()
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
