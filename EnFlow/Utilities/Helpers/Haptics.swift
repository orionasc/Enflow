//
//  Haptics.swift
//  EnFlow
//
//  Created by Orion Goodman on 6/16/25.
//


//
//  Haptics.swift
//  EnFlow
//
//  Lightweight utility for one-line haptic triggers.
//  Added 2025-06-16
//

import Foundation

#if os(iOS)
import UIKit
#endif

/// Central helper – call `Haptics.play(.rigid)`, etc.
enum Haptics {

    /// Plays an impact haptic if running on iOS hardware.
    /// - Parameter style: `.light`, `.medium`, `.heavy`, `.soft`, `.rigid`
    static func play(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
        #endif
    }
}
