import Foundation
import Combine

enum DataMode {
    case real
    case simulated
}

final class DataModeManager: ObservableObject {
    static let shared = DataModeManager()
    @Published var currentDataMode: DataMode {
        didSet {
            UserDefaults.standard.set(currentDataMode == .simulated, forKey: Self.storeKey)
            ForecastCache.shared.clearAllCachedData()
            NotificationCenter.default.post(name: .didChangeDataMode, object: nil)
        }
    }
    private static let storeKey = "useSimulatedHealthData"

    private init() {
        let simulated = UserDefaults.standard.bool(forKey: Self.storeKey)
        currentDataMode = simulated ? .simulated : .real
    }

    func isSimulated() -> Bool {
        currentDataMode == .simulated
    }

    func setMode(_ mode: DataMode) {
        guard mode != currentDataMode else { return }
        currentDataMode = mode
    }
}

extension Notification.Name {
    static let didChangeDataMode = Notification.Name("didChangeDataMode")
}
