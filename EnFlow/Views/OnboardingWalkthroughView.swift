//
//  OnboardingWalkthroughView.swift
//  EnFlow
//
//  Created by Orion Goodman on 7/16/25.
//


import SwiftUI

/// A static, visually‑rich first‑run walkthrough for EnFlow.
///
/// *NOTE*  — Animations & interactive elements will be layered on later; this file
/// focuses on structure, layout, and styling only.

struct OnboardingWalkthroughView: View {
    /// Controls dismissal when "Start Using EnFlow" is tapped.
    @AppStorage("didCompleteWalkthrough") private var didCompleteWalkthrough = false

    var body: some View {
        TabView {
            PageWelcome()
            PageEnergyRing()
            PageWaveform()
            PageSync()
            PageExpectations()
            PageMeetSol()
            PageEarlyTester(didCompleteWalkthrough: $didCompleteWalkthrough)
        }
        .tabViewStyle(PageTabViewStyle())
        .ignoresSafeArea()  // full‑bleed backgrounds
    }
}

// MARK: ‑ Individual Pages ----------------------------------------------------

private struct PageWelcome: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(#colorLiteral(red:1, green:0.75, blue:0.2, alpha:1)), Color(#colorLiteral(red:0.925, green:0.28, blue:0.6, alpha:1))], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 96))
                    .foregroundColor(.white.opacity(0.9))
                Text("Welcome to EnFlow")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text("Your Energy Companion.")
                    .font(.title3.weight(.medium))
                    .foregroundColor(.white.opacity(0.9))
                Text("EnFlow helps you forecast, understand, and improve your energy throughout the day so you can move with your own rhythm.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 32)
                Spacer()
                Text("Swipe →")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 40)
            }
        }
    }
}

private struct PageEnergyRing: View {
    @State private var index: Int = 0
    private let scores: [Double] = [25, 65, 95]
    private let labels: [String] = ["Low", "Moderate", "Supercharged"]

    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
            VStack(spacing: 32) {
                Spacer(minLength: 60)
                EnergyRingPlaceholder(score: scores[index])
                    .frame(width: 200, height: 200)
                Text("Tap the ring to cycle energy levels →")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text("Your Energy Score is a blend of your mental and physical readiness. It updates throughout the day based on your sleep, recovery, activity, and schedule.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 32)
                Spacer()
            }
        }
        .onTapGesture {
            index = (index + 1) % scores.count
        }
    }
}

/// Placeholder ring (static – no animation yet)
private struct EnergyRingPlaceholder: View {
    let score: Double
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 24)
            Circle()
                .trim(from: 0, to: CGFloat(score / 100))
                .stroke(AngularGradient(gradient: Gradient(colors: [.cyan, .yellow, .orange, .red]), center: .center), style: StrokeStyle(lineWidth: 24, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(score))")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
        }
    }
}

private struct PageWaveform: View {
    /// Placeholder sine‑wave data
    private let values: [Double] = (0..<24).map { i in 0.5 + 0.4 * sin(Double(i) / 24 * .pi * 2) }
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(#colorLiteral(red:0.1, green:0.12, blue:0.25, alpha:1)), Color(#colorLiteral(red:0.05, green:0.05, blue:0.1, alpha:1))], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 32) {
                Spacer(minLength: 60)
                DailyEnergyPlaceholder(values: values)
                    .frame(height: 200)
                    .padding(.horizontal)
                Text("Your day has a natural rhythm. Sol, our intelligence engine, helps you see it. This curve reflects your forecasted energy, influenced by sleep, stress, and your calendar.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 32)
                Spacer()
            }
        }
    }
}

/// Simple static line graph using SwiftUI Path
private struct DailyEnergyPlaceholder: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            let points: [CGPoint] = values.enumerated().map { idx, val in
                let x = geo.size.width * CGFloat(idx) / CGFloat(max(values.count - 1, 1))
                let y = geo.size.height * (1 - CGFloat(val))
                return CGPoint(x: x, y: y)
            }
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
            }
            .stroke(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom), lineWidth: 3)
        }
    }
}

private struct PageSync: View {
    var body: some View {
        ZStack {
            Color(#colorLiteral(red:0.08, green:0.1, blue:0.18, alpha:1))
            VStack(spacing: 32) {
                Spacer(minLength: 40)
                HStack(spacing: 24) {
                    SyncCard(icon: "heart.fill", title: "Apple Health", subtitle: "Sleep • HRV • Steps")
                    SyncCard(icon: "calendar", title: "Calendar", subtitle: "Meetings • Events")
                }
                HStack(spacing: 24) {
                    SyncCard(icon: "bolt.horizontal.circle", title: "Wearables", subtitle: "Coming soon")
                    SyncCard(icon: "building.2.fill", title: "Work Apps", subtitle: "Coming soon")
                }
                Text("EnFlow works quietly in the background. Syncing your Health and Calendar data lets Sol personalise your forecasts.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 32)
                Spacer()
            }
        }
    }
}

private struct SyncCard: View {
    let icon: String; let title: String; let subtitle: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(width: 140, height: 120)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PageExpectations: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(#colorLiteral(red:0.12, green:0.12, blue:0.12, alpha:1)), Color(#colorLiteral(red:0.03, green:0.03, blue:0.05, alpha:1))], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 24) {
                Spacer(minLength: 60)
                ExpectationRow(image: "chart.bar.fill", text: "Forecast your energy from morning to evening")
                ExpectationRow(image: "bolt.fill", text: "Recommend quick actions to recover or optimise")
                ExpectationRow(image: "lightbulb.fill", text: "Surface patterns and personalised insights")
                ExpectationRow(image: "gearshape.2.fill", text: "Continuously learn & improve with your feedback")
                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }
}

private struct ExpectationRow: View {
    let image: String; let text: String
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: image)
                .font(.title2)
                .foregroundColor(.yellow)
            Text(text)
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
            Spacer()
        }
    }
}

private struct PageMeetSol: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(#colorLiteral(red:0.2, green:0.15, blue:0.05, alpha:1)), Color(#colorLiteral(red:0.35, green:0.25, blue:0.06, alpha:1))], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 24) {
                Spacer(minLength: 60)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.yellow)
                Text("Meet Sol")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text("Sol is your intelligent engine — part coach, part scientist. It notices when certain events boost or drain you and learns over time to forecast tomorrow by learning from yesterday.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 32)
                Spacer()
            }
        }
    }
}

private struct PageEarlyTester: View {
    @Binding var didCompleteWalkthrough: Bool
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(#colorLiteral(red:0.05, green:0.08, blue:0.2, alpha:1)), Color(#colorLiteral(red:0.1, green:0.1, blue:0.12, alpha:1))], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 28) {
                Spacer(minLength: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 72))
                    .foregroundColor(.yellow)
                Text("You’re an Early Tester ✨")
                    .font(.title.bold())
                    .foregroundColor(.white)
                Text("Some things may still be rough around the edges — but we’re improving every day. After exploring, head to **Settings → Profile** to fill in your habits so Sol can personalise your forecasts.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 32)
                Button(action: { didCompleteWalkthrough = true }) {
                    Text("Start Using EnFlow")
                        .font(.headline)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color.yellow))
                        .foregroundColor(.black)
                }
                .padding(.top, 16)
                Spacer()
            }
        }
    }
}

// MARK: ‑ Preview -------------------------------------------------------------
#if DEBUG
struct OnboardingWalkthroughView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingWalkthroughView()
    }
}
#endif
