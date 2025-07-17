//  EnergyRingView.swift
//  EnFlow
//

import SwiftUI
import Combine

struct EnergyRingView: View {

    // ───────── Inputs ──────────────────────────────────────────────
    /// Optional score. `nil` renders a placeholder with "--" and a grey ring.
    let score: Double?
    var dashed: Bool     = false   // forecast style?
    var desaturate: Bool = false   // forecast style?
    /// Animate the ring fill from 0 on each appearance
    var animateFromZero: Bool = false
    /// Highlight the ring with a subtle shimmer animation
    var shimmer: Bool = false
    /// Supply the “why” bullets from your parent (e.g. summary.explainers)
    var explainers: [String] = []
    /// Supply the timestamp from your parent (e.g. summary.date)
    var summaryDate: Date = Date()
    /// Overall size for the ring (default 180 for full display)
    var size: CGFloat = 180
    /// Show the info button that presents additional details
    var showInfoButton: Bool = true
    /// Show the numeric score label in the center
    var showValueLabel: Bool = true
    /// Optional warning message for low confidence forecasts
    var warningMessage: String? = nil

    // ───────── Engine + State ──────────────────────────────────────
    @ObservedObject private var engine = EnergySummaryEngine.shared
    @State private var pulseScale = 1.0
    @State private var showExplanation = false
    @State private var ringProgress: Double = 0
    @State private var hasAnimated = false
    @State private var shimmerPhase: CGFloat = -1
    @State private var rotation: Double = 0
    @State private var pulseAura = false
    @State private var showLabel = false




    // Base scale applied so the composite ring appears slightly smaller
    private let baseScale: CGFloat = 0.9

    // ───────── Derived ──────────────────────────────────────────────
    private var status: String {
        guard let score else { return "N/A" }
        switch score {
        case 0..<50:
            return "LOW"
        case 50..<80:
            return "MODERATE"
        case 90..<100:
            return "SUPERCHARGED"
        default:
            return "HIGH"
        }
    }
    private var glowStrength: Double { isForecast ? 0 : (score ?? 0) / 100 }
    private var isSupercharged: Bool {
        guard let score else { return false }
        return !isForecast && score >= 90
    }
    private var isForecast: Bool { desaturate || dashed }

    // MARK: Body
    var body: some View {
        ZStack {
            if let sc = score {
                // — Soft glow halo —
                Circle()
                    .fill(ColorPalette.color(for: sc))
                    .blur(radius: glowStrength * 40)
                    .opacity(glowStrength * 0.55)
                    .frame(width: 220, height: 220)

                // — Supercharged pulsing aura —
                if isSupercharged && shimmer {
                    Circle()
                        .fill(Color.yellow.opacity(0.4))
                        .frame(width: 240, height: 240)
                        .scaleEffect(pulseAura ? 1.25 : 0.9)
                        .opacity(pulseAura ? 0.0 : 0.6)
                        .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulseAura)
                        .onAppear { pulseAura = true }

                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [Color.yellow.opacity(0.6), .clear]),
                                center: .center,
                                startRadius: 0,
                                endRadius: size
                            )
                        )
                        .blur(radius: 30)
                        .frame(width: size * 1.6, height: size * 1.6)

                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [Color.orange.opacity(0.4), .clear]),
                                center: .center,
                                startRadius: 0,
                                endRadius: size
                            )
                        )
                        .blur(radius: 60)
                        .frame(width: size * 1.6, height: size * 1.6)
                }

                // — Background track —
                Circle()
                    .stroke(ColorPalette.color(for: sc).opacity(0.15),
                            style: StrokeStyle(lineWidth: 20,
                                               lineCap: .round,
                                               dash: dashed ? [4, 2] : []))

                // — Progress arc —
                Circle()
                    .trim(from: 0, to: CGFloat(ringProgress))
                    .stroke(ColorPalette.gradient(for: sc),
                            style: StrokeStyle(lineWidth: 20,
                                               lineCap: .round,
                                               dash: dashed ? [4, 2] : []))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: ringProgress)
                    .applyIf(shimmer) { view in
                        view
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .white.opacity(0.0),
                                        .white.opacity(0.6),
                                        .white.opacity(0.0)
                                    ]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                                .rotationEffect(.degrees(30))
                                .offset(x: shimmerPhase * 250)
                                .blendMode(.plusLighter)
                                .mask(
                                    Circle()
                                        .trim(from: 0, to: CGFloat(ringProgress))
                                        .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                        // Feather the mask edges so the shimmer
                                        // fades smoothly as it travels across
                                        // the ring without hard cutoffs.
                                        .blur(radius: 3)
                                )
                            )
                    }
                    .applyIf(isSupercharged && shimmer) { view in
                        view
                            .overlay(
                                AngularGradient(
                                    gradient: Gradient(colors: [Color.yellow, Color.orange, Color.red, Color.yellow]),
                                    center: .center
                                )
                                .rotationEffect(.degrees(rotation))
                                .mask(
                                    Circle()
                                        .trim(from: 0, to: CGFloat(ringProgress))
                                        .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                )
                            )
                    }
                    .onAppear {
                        withAnimation(.linear(duration: 6.4).repeatForever(autoreverses: false)) {
                            shimmerPhase = 1
                        }
                        if isSupercharged && shimmer {
                            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                    }


                // — Label —
                if showValueLabel {
                    VStack(spacing: 4) {
                        Text("\(Int(sc))")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: ColorPalette.color(for: sc).opacity(0.8), radius: 4)
                        Text(status)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .applyIf(isSupercharged && shimmer) { view in
                        view
                            .scaleEffect(showLabel ? 1 : 0.8)
                            .opacity(showLabel ? 1 : 0)
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.6)) { showLabel = true }
                            }
                    }
                }
            } else {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 20)

                if showValueLabel {
                    VStack(spacing: 4) {
                        Text("--")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .white.opacity(0.4), radius: 3)
                        Text(status)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }

            // — Supercharged bolt & aura icon —
            if isSupercharged && shimmer {
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.8), lineWidth: 3)
                        .frame(width: 210, height: 210)
                        .blur(radius: 0.5)
                    Circle()
                        .stroke(Color.orange.opacity(0.6), lineWidth: 4)
                        .frame(width: 60, height: 60)
                        .blur(radius: 6)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.yellow)
                        .shadow(color: Color.yellow.opacity(0.9), radius: 8)
                }
                .transition(.scale.combined(with: .opacity))
            }

            // — Info & warning buttons (top-right) —
            VStack {
                HStack {
                    if let msg = warningMessage {
                        WarningIconButton(message: msg)
                    }
                    if showInfoButton {
                        Button { showExplanation = true } label: {
                            Image(systemName: "info.circle")
                                .font(.headline)
                        }
                        .buttonStyle(.embossedInfo)
                    }
                    Spacer(minLength: 0)
                }
                Spacer()
            }
        }
        .frame(width: size, height: size)
        .scaleEffect((size / 180) * baseScale * pulseScale)
        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
        .saturation(desaturate ? 0.55 : 1.0)
        .onReceive(engine.$refreshVersion.dropFirst()) { _ in
            withAnimation(.easeOut(duration: 0.35)) { pulseScale = 1.08 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.25)) { pulseScale = 1.0 }
            }
        }
        .onAppear {
            guard let sc = score else { ringProgress = 0; return }
            if animateFromZero && !hasAnimated {
                ringProgress = 0
                withAnimation(.easeOut(duration: 0.75)) {
                    ringProgress = sc / 100
                }
                hasAnimated = true
            } else {
                ringProgress = sc / 100
            }
        }
        .onChange(of: score) { newValue in
            let val = (newValue ?? 0) / 100
            withAnimation(.easeOut(duration: 0.8)) {
                ringProgress = val
            }
        }
        .sheet(isPresented: $showExplanation) {
            EnergyRingInfoView()
        }
    }
}

#if DEBUG
struct EnergyRingView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            EnergyRingView(score: 74, shimmer: true)
            EnergyRingView(score: 93, shimmer: true)
            EnergyRingView(score: nil, shimmer: true)
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
#endif
