import Foundation
import Combine

@MainActor
final class FeedbackStore: ObservableObject {
    static let shared = FeedbackStore()

    @Published private(set) var feedback: [DailyFeedback] = []

    private init() { load() }

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("DailyFeedback.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([DailyFeedback].self, from: data) else { return }
        feedback = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(feedback) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    func save(_ entry: DailyFeedback) {
        let cal = Calendar.current
        if let idx = feedback.firstIndex(where: { cal.isDate($0.date, inSameDayAs: entry.date) }) {
            feedback[idx] = entry
        } else {
            feedback.append(entry)
        }
        persist()
    }

    func feedback(for date: Date) -> DailyFeedback? {
        let cal = Calendar.current
        return feedback.first { cal.isDate($0.date, inSameDayAs: date) }
    }

    func recent(days: Int) -> [DailyFeedback] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date().addingTimeInterval(-Double(days - 1) * 86_400))
        return feedback.filter { $0.date >= start }
    }
}
