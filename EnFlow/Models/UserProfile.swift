import Foundation

struct UserProfile: Codable, Equatable {
    enum Chronotype: String, CaseIterable, Identifiable, Codable {
        case morning
        case intermediate
        case evening
        var id: String { rawValue }
    }

    var caffeineIntakePerDay: Int
    var caffeineTimeLastUsed: Date
    var exerciseFrequency: Int
    var typicalWakeTime: Date
    var typicalSleepTime: Date
    var usesSleepAid: Bool
    var screensBeforeBed: Bool
    var mealsRegular: Bool
    var stressLevel: Int
    var chronotype: Chronotype
    var lastUpdated: Date
    var notes: String?
}

extension UserProfile {
    static var `default`: UserProfile {
        let cal = Calendar.current
        let wake = cal.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        let sleep = cal.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        return UserProfile(
            caffeineIntakePerDay: 0,
            caffeineTimeLastUsed: wake,
            exerciseFrequency: 3,
            typicalWakeTime: wake,
            typicalSleepTime: sleep,
            usesSleepAid: false,
            screensBeforeBed: true,
            mealsRegular: true,
            stressLevel: 3,
            chronotype: .intermediate,
            lastUpdated: Date(),
            notes: nil
        )
    }

    func debugSummary() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return "Caffeine: \(caffeineIntakePerDay)/day, last at \(fmt.string(from: caffeineTimeLastUsed)). " +
        "Wake \(fmt.string(from: typicalWakeTime)), Sleep \(fmt.string(from: typicalSleepTime)), " +
        "Exercise \(exerciseFrequency)x/week, Stress \(stressLevel)/5, Chronotype \(chronotype.rawValue)."
    }
}
