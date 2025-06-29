import Foundation

struct DailyFeedback: Identifiable, Codable {
    let id: UUID
    let date: Date
    var feltHighEnergy: Bool
    var feltStressed: Bool
    var feltWellRested: Bool
    var note: String?
}
