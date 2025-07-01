import Foundation

/// Represents a behavioral pattern that impacts the user's energy.
struct DetectedPattern: Identifiable, Codable {
    let id = UUID()
    let pattern: String      // "3+ meetings after 1 PM"
    let effect: String       // "-18% avg energy"
    let evidenceCount: Int
    let confidence: Double   // 0.0 – 1.0
}
