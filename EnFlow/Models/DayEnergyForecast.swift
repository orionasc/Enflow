import Foundation

/// Forecasted energy values and metadata for a given day.
struct DayEnergyForecast: Codable {
    enum SourceType: String, Codable {
        case historicalModel
        case defaultHeuristic
    }

    let date: Date
    let values: [Double]          // 24 values, 0.0…1.0
    let score: Double             // 0…100 daily average
    let confidenceScore: Double   // 0…1
    let missingMetrics: [MetricType]
    let sourceType: SourceType
    /// Optional debug description when forecast confidence is low.
    let debugInfo: String?
}
