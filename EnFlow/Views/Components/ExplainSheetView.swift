//
//  ExplainSheetView.swift
//  EnFlow
//
//  Created by Orion Goodman on 6/17/25.
//


//  ExplainSheetView.swift
//  EnFlow
//
//  Rev. 2025-06-17  • Reusable bottom-sheet for “Why this?” explainers

import SwiftUI

struct ExplainSheetView: View {
    /// Main heading (e.g. "\(Int(score)) Energy" or suggestion title)
    let header: String
    /// 3–5 bullet driver lines
    let bullets: [String]
    /// When the data/prompt was generated
    let timestamp: Date

    /// DateFormatter for the footer timestamp
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text(header)
                .font(.title2).bold()
                .padding(.bottom, 4)

            // Bullets
            VStack(alignment: .leading, spacing: 8) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.cyan)
                            .padding(.top, 5)
                        Text(bullet)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // Footer timestamp
            Text("As of \(Self.dateFormatter.string(from: timestamp))")
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .presentationDetents([.medium])
    }
}

#if DEBUG
struct ExplainSheetView_Previews: PreviewProvider {
    static var previews: some View {
        ExplainSheetView(
            header: "78 Energy",
            bullets: [
                "Last night’s sleep was 20% below average",
                "HRV trend down 15% over past 3 days",
                "Busy morning with 3 back-to-back meetings"
            ],
            timestamp: Date()
        )
        .padding()
        .background(Color.black.opacity(0.8))
        .previewLayout(.sizeThatFits)
    }
}
#endif
