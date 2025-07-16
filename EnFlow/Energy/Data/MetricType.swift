import Foundation

/// Health metrics used to compute energy scores.
enum MetricType: String, CaseIterable, Codable {
    // Required
    case stepCount
    case activeEnergyBurned
    case heartRate
    case timeInBed

    // Optional
    case restingHR
    case heartRateVariabilitySDNN
    case appleExerciseTime
    case vo2Max
    case sleepEfficiency
    case sleepLatency
    case deepSleep
    case remSleep
    case respiratoryRate
    case walkingHeartRateAverage
    case oxygenSaturation
    case environmentalAudioExposure
    case menstrualFlow
    case mindfulMinutes
}
