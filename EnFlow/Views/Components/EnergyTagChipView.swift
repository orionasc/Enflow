//
//  EnergyTagChipView.swift
//  EnFlow
//
//  Created by Orion Goodman on 6/14/25.
//


import SwiftUI

struct EnergyTagChipView: View {
    let label: String
    let score: Double        // −100…100

    private var magnitude: Double { min(100, abs(score)) }

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(ColorPalette.gradient(for: magnitude))
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
            .foregroundColor(.white)
    }
}
