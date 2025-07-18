//
//  InsightCardView.swift
//  EnFlow
//

import SwiftUI

struct InsightCardView: View {
    let icon: String
    let title: String
    let text: String
    let loading: Bool
    var tint: Double = 70

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(ColorPalette.gradient(for: tint))

            if loading {
                ProgressView().frame(height: 20)
            } else {
                Text(text).font(.body)
            }
        }
        .cardStyle(tint: tint)
    }
}
