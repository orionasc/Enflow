//  EnergyRingView.swift
//  EnFlow
//

import SwiftUI
import Combine

struct EnergyRingView: View {

    // ───────── Inputs ──────────────────────────────────────────────
    let score: Double              // 0 … 100
    var dashed: Bool     = false   // forecast style?
    var desaturate: Bool = false   // forecast style?
    /// Supply the “why” bullets from your parent (e.g. summary.explainers)
    var explainers: [String] = []
    /// Supply the timestamp from your parent (e.g. summary.date)
    var summaryDate: Date = Date()

    // ───────── Engine + State ──────────────────────────────────────
    @ObservedObject private var engine = EnergySummaryEngine.shared
    @State private var pulseScale = 1.0
    @State private var showExplanation = false

    // ───────── Derived ──────────────────────────────────────────────
    private var status: String {
        switch score {
        case 0..<50  : "LOW"
        case 50..<80 : "MODERATE"
        case 90..<100: "SUPERCHARGED"
        default      : "HIGH"
        }
    }
    private var glowStrength: Double { isForecast ? 0 : score / 100 }
    private var isSupercharged: Bool { !isForecast && score >= 90 }
    private var isForecast: Bool { desaturate || dashed }

    // MARK: Body
    var body: some View {
        ZStack {
            // — Soft glow halo —
            Circle()
                .fill(ColorPalette.color(for: score))
                .blur(radius: glowStrength * 40)
                .opacity(glowStrength * 0.55)
                .frame(width: 220, height: 220)

            // — Background track —
            Circle()
                .stroke(ColorPalette.color(for: score).opacity(0.15),
                        style: StrokeStyle(lineWidth: 20,
                                           lineCap: .round,
                                           dash: dashed ? [4, 2] : []))

            // — Progress arc —
            Circle()
                .trim(from: 0, to: CGFloat(score / 100))
                .stroke(ColorPalette.gradient(for: score),
                        style: StrokeStyle(lineWidth: 20,
                                           lineCap: .round,
                                           dash: dashed ? [4, 2] : []))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: score)

            // — Label —
            VStack(spacing: 4) {
                Text("\(Int(score))")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                Text(status)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
            }

            // — Supercharged bolt & orange ring —
            if isSupercharged {
                Circle()
                    .stroke(Color.orange.opacity(0.8), lineWidth: 3)
                    .blur(radius: 0.5)
                    .frame(width: 210, height: 210)
                    .overlay(
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.orange)
                    )
                    .transition(.scale.combined(with: .opacity))
            }

            // — Info button (top-right) —
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showExplanation = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(6)
                }
                Spacer()
            }
        }
        .frame(width: 180, height: 180)
        .scaleEffect(pulseScale)
        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
        .saturation(desaturate ? 0.55 : 1.0)
        .onReceive(engine.$refreshVersion.dropFirst()) { _ in
            withAnimation(.easeOut(duration: 0.35)) { pulseScale = 1.08 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.25)) { pulseScale = 1.0 }
            }
        }
        .sheet(isPresented: $showExplanation) {
            ExplainSheetView(
                header: "Your Energy Score: \(Int(score))",
                bullets: explainers,
                timestamp: summaryDate
            )
        }
    }
}

#if DEBUG
struct EnergyRingView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            EnergyRingView(score: 74)
            EnergyRingView(score: 93)
            EnergyRingView(score: 30, dashed: true, desaturate: true) // forecast
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
#endif
