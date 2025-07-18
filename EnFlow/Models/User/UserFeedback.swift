import Foundation

enum EnergyLevel: Int, Codable, CaseIterable {
    case low = 1
    case moderate = 2
    case high = 3

    var label: String {
        switch self {
        case .high: return "High"
        case .moderate: return "Moderate"
        case .low: return "Low"
        }
    }
}

struct DailyFeedback: Identifiable, Codable {
    let id: UUID
    let date: Date
    var energyLevel: EnergyLevel?
    var note: String?
}
