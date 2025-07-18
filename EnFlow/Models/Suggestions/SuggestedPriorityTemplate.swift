//
//  SuggestedPriorityTemplate.swift
//  EnFlow
//
//  Created by Orion Goodman on 6/16/25.
//


//
//  SuggestedPriorityTemplate.swift
//  EnFlow
//
//  Created by ChatGPT on 2025-06-16.
//

import Foundation
import SwiftUI

/// Enumeration of all supported priority suggestion templates.
public enum SuggestedPriorityTemplate: String, CaseIterable, Identifiable, Codable {
    case deepWork           = "Deep Work"
    case lightAdmin         = "Light Admin"
    case activeRecovery     = "Active Recovery"
    case socialRecharge     = "Social Recharge"
    case morningReflection  = "Morning Reflection"
    case windDown           = "Wind-down"
    case creativeSpur       = "Creative Spur"
    case quickPhysicalReset = "Quick Physical Reset"

    // MARK: - Identifiable
    public var id: String { rawValue }

    // MARK: - Display Properties
    /// Preferred SF Symbol for UI rendering.
    public var sfSymbol: String {
        switch self {
        case .deepWork:           return "brain.head.profile"
        case .lightAdmin:         return "tray.full"
        case .activeRecovery:     return "figure.mind.and.body"
        case .socialRecharge:     return "person.2.wave.2"
        case .morningReflection:  return "sunrise.fill"
        case .windDown:           return "moon.zzz.fill"
        case .creativeSpur:       return "paintbrush.fill"
        case .quickPhysicalReset: return "bolt.heart.fill"
        }
    }

    /// Base weighting used by the scoring engine before contextual rules are applied.
    public var baseWeight: Double {
        switch self {
        case .deepWork:           return 1.0
        case .lightAdmin:         return 0.9
        case .activeRecovery:     return 0.9
        case .socialRecharge:     return 0.8
        case .morningReflection:  return 1.0
        case .windDown:           return 1.0
        case .creativeSpur:       return 0.85
        case .quickPhysicalReset: return 0.8
        }
    }
}
