//
//  WeeklySummaryRefactored.swift
//  EnFlow
//
//  Created by Orion Goodman on 6/28/25.
//

import Foundation
import SwiftUI

extension TrendsView {
    // MARK: – Refactored GPT Summary Loader
    private func loadGPTSummary(forceReload: Bool = false) async {
        await MainActor.run { isGPTLoading = true }
        do {
            let raw = try await OpenAIManager.shared.generateInsight(
                prompt: weeklySummaryPrompt,
                cacheId: forceReload ? "WeeklyJSON.\(period.rawValue).\(Date().timeIntervalSince1970)" : "WeeklyJSON.\(period.rawValue)"
            )

            // strip fences and smart quotes
            let cleaned = raw
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .replacingOccurrences(of: "\u{201C}", with: "\"")
                .replacingOccurrences(of: "\u{201D}", with: "\"")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // attempt JSON parse via JSONSerialization for robustness
            if let obj = try? JSONSerialization.jsonObject(with: Data(cleaned.utf8), options: []),
               let data = try? JSONSerialization.data(withJSONObject: obj, options: []),
               let parsed = try? JSONDecoder().decode(GPTSummary.self, from: data) {
                await MainActor.run {
                    parsedGPTSummary = parsed
                }
            } else {
                await MainActor.run {
                    parsedGPTSummary = nil
                    gptSummary = cleaned
                }
            }
        } catch {
            await MainActor.run {
                parsedGPTSummary = nil
                gptSummary = "error: Unable to load summary"
            }
        }
        await MainActor.run { isGPTLoading = false }
    }

    // MARK: – Refactored Summary UI Block
    private var gptSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("GPT Weekly Summary").font(.headline)
                Spacer()
                Button(action: { Task { await loadGPTSummary(forceReload: true) } }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                }
                .accessibilityLabel("Reload GPT summary")
            }
            .padding(.horizontal)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 4)

                Group {
                    if isGPTLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.yellow)
                            .padding(20)

                    } else if let parsed = parsedGPTSummary {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(parsed.sections) { section in
                                Text(section.title)
                                    .bold()
                                    .foregroundColor(.yellow)
                                Text(section.content)
                                    .foregroundColor(.white)
                            }
                            if !parsed.events.isEmpty {
                                Divider().background(Color.yellow)
                                Text("Events")
                                    .bold()
                                    .foregroundColor(.yellow)
                                ForEach(parsed.events) { event in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text(event.date)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(event.title)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .padding()

                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("⚠️ Parsing failed")
                                .foregroundColor(.orange)
                            Text(gptSummary)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)
                                .textSelection(.enabled)
                                .padding([.horizontal, .bottom])
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
