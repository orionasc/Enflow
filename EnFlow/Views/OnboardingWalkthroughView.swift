import SwiftUI

// MARK: ─────────────────────────────────────────────────────────────
//  EnFlow Onboarding Walkthrough (full structure + interaction stubs)
//  -----------------------------------------------------------------
//  • This file REPLACES the prior skeleton. It now declares every page
//    as its own View struct, wired into a single `TabView` sequence.
//  • All interactive / animated regions are clearly marked with TODOs.
//  • Real assets (EnergyRingView, DailyEnergyForecastView, etc.) are
//    referenced but NOT implemented here — they already exist in the
//    project.
//  • Codex / devs should flesh out the TODOs where noted.
// -------------------------------------------------------------------

struct OnboardingWalkthroughView: View {
    // 0‑based page index so we can pause animations if page is off‑screen
    @State private var pageIndex: Int = 0
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false

    // Namespace for future matched‑geometry transitions
    @Namespace private var mg

    var body: some View {
        TabView(selection: $pageIndex) {
            WelcomePage(mg: mg).tag(0)
            EnergyRingDemoPage().tag(1)
            WaveformDemoPage().tag(2)
            SyncTipsPage().tag(3)
            ExpectationsPage().tag(4)
            MeetSolPage().tag(5)
            EarlyTesterPage(onFinish: completeOnboarding).tag(6)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .ignoresSafeArea()
        .onChange(of: pageIndex) { _ in
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    private func completeOnboarding() {
        didCompleteOnboarding = true
    }
}

// MARK: ‑‑‑ PAGE 1 — Welcome ‑‑‑
struct WelcomePage: View {
    var mg: Namespace.ID
    @State private var pulse = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(#colorLiteral(red: 0.984, green: 0.749, blue: 0.141, alpha: 1)), Color(#colorLiteral(red: 0.925, green: 0.286, blue: 0.6, alpha: 1))], startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 28) {
                Spacer()
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 120))
                    .foregroundColor(.yellow)
                    .scaleEffect(pulse ? 1.1 : 0.9)
                    .opacity(pulse ? 1 : 0.7)
                    .matchedGeometryEffect(id: "sun", in: mg)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }

                Text("Welcome to EnFlow")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text("Your Energy Companion.")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))

                Text("EnFlow helps you forecast, understand, and improve your energy throughout the day. Whether you're planning, recovering, or just surviving your calendar — we're here to help you move with your rhythm.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal)

                Spacer()
                Image(systemName: "chevron.down")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(0.8)
                    .padding(.bottom, 40)
            }
            .padding()
        }
    }
}

// MARK: ‑‑‑ PAGE 2 — Energy Ring Demo ‑‑‑
struct EnergyRingDemoPage: View {
    @State private var demoScore: Double = 25
    @State private var index = 0

    private let demoScores: [Double] = [25, 65, 95]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(#colorLiteral(red: 0.129, green: 0.129, blue: 0.157, alpha: 1))], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 40) {
                Spacer(minLength: 80)
                EnergyRingView(score: demoScore,  animateFromZero: true, shimmer: true)
                    .frame(width: 200, height: 200)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: demoScore)

                Text("Tap below to explore different energy states")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.headline)

                HStack(spacing: 16) {
                    ForEach(demoScores.indices, id: \ .self) { i in
                        Circle()
                            .fill(i == index ? Color.yellow : Color.white.opacity(0.3))
                            .frame(width: 14, height: 14)
                            .onTapGesture {
                                withAnimation {
                                    index = i
                                    demoScore = demoScores[i]
                                }
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: ‑‑‑ PAGE 3 — Waveform Demo ‑‑‑
struct WaveformDemoPage: View {
    enum Slice: String, CaseIterable { case morning, afternoon, evening }
    @State private var slice: Slice = .morning

    // Placeholder synthetic wave — replace with realistic sample if desired
    private let fullWave: [Double] = (0..<24).map { i in 0.5 + 0.35 * sin(Double(i)/3) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(#colorLiteral(red: 0.05, green: 0.08, blue: 0.2, alpha: 1)), Color(#colorLiteral(red: 0.12, green: 0.12, blue: 0.12, alpha: 1))], startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 28) {
                Spacer(minLength: 40)
                Text("Your Energy Waveform")
                    .font(.title.bold())
                    .foregroundColor(.white)

                DailyEnergyForecastView(values: currentSlice, startHour: startHour)
                    .frame(height: 140)
                    .padding(.horizontal)
                    // TODO: animate path draw‑in using trim from 0→1

                Picker("", selection: $slice) {
                    ForEach(Slice.allCases, id: \ .self) { s in
                        Text(s.rawValue.capitalized).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
                .onChange(of: slice) { _ in UIImpactFeedbackGenerator(style: .soft).impactOccurred() }

                Text(sliceDescription)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
        }
    }

    private var startHour: Int { slice == .morning ? 6 : slice == .afternoon ? 12 : 18 }
    private var currentSlice: [Double] {
        let range = startHour..<(startHour+8)
        return Array(fullWave[range])
    }
    private var sliceDescription: String {
        switch slice {
        case .morning: return "Morning energy often reflects your sleep quality and baseline recovery."
        case .afternoon: return "Afternoon energy is heavily shaped by workload and caffeine timing."
        case .evening: return "Evening energy shows lingering stress and how well you wind down."
        }
    }
}

// MARK: ‑‑‑ PAGE 4 — Sync Tips ‑‑‑
struct SyncTipsPage: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(#colorLiteral(red: 0.08, green: 0.09, blue: 0.18, alpha: 1)), Color(#colorLiteral(red: 0.04, green: 0.05, blue: 0.1, alpha: 1))], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                Text("How We Sync With You")
                    .font(.title.bold())
                    .foregroundColor(.white)

                VStack(spacing: 16) {
                    SyncCard(icon: "heart.fill", title: "Apple Health", subtitle: "Sleep, heart rate, steps")
                    SyncCard(icon: "calendar", title: "Apple Calendar", subtitle: "Meetings & events")
                    SyncCard(icon: "link", title: "Google / Outlook", subtitle: "Via Apple Calendar today — direct support soon!", comingSoon: true)
                }
                .padding(.horizontal)
                Spacer()
            }
        }
    }
}

private struct SyncCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var comingSoon: Bool = false
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.1)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            if comingSoon {
                Text("Soon")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }
}

// MARK: ‑‑‑ PAGE 5 — Expectations ‑‑‑
struct ExpectationsPage: View {
    @State private var screenshotIndex = 0
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(#colorLiteral(red: 0.05, green: 0.08, blue: 0.2, alpha: 1)), Color(#colorLiteral(red: 0.12, green: 0.12, blue: 0.12, alpha: 1))], startPoint: .topLeading, endPoint: .bottom)
            VStack(spacing: 28) {
                Text("What Can I Expect?")
                    .font(.title.bold())
                    .foregroundColor(.yellow)

                TabView(selection: $screenshotIndex) {
                    // TODO: replace Color placeholders with actual screenshots
                    Color.orange.tag(0)
                    Color.blue.tag(1)
                    Color.purple.tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)
                .onReceive(timer) { _ in
                    withAnimation {
                        screenshotIndex = (screenshotIndex + 1) % 3
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Forecast your energy", systemImage: "waveform.path.ecg")
                    Label("Quick action nudges", systemImage: "bolt.circle")
                    Label("Pattern insights & trends", systemImage: "chart.bar.doc.horizontal")
                }
                .font(.headline)
                .foregroundColor(.white)
                .labelStyle(.titleAndIcon)
                Spacer()
            }
        }
    }
}

// MARK: ‑‑‑ PAGE 6 — Meet Sol ‑‑‑
struct MeetSolPage: View {
    @State private var factIndex = 0
    private let facts = [
        "Sol weighs your sleep quality and HRV trends.",
        "Sol notices when certain events boost or drain you.",
        "Sol forecasts tomorrow by learning from yesterday."
    ]

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color.yellow.opacity(0.6), Color.orange.opacity(0.3)], center: .center, startRadius: 40, endRadius: 400).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer(minLength: 60)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 120))
                    .foregroundColor(.yellow)
                    .shadow(radius: 10)
                    .onTapGesture {
                        withAnimation(.spring()) { factIndex = (factIndex + 1) % facts.count }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                Text("Meet Sol")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text(facts[factIndex])
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: ‑‑‑ PAGE 7 — Early Tester / CTA ‑‑‑
struct EarlyTesterPage: View {
    let onFinish: () -> Void
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(#colorLiteral(red: 0.15, green: 0.12, blue: 0.32, alpha: 1)), Color(#colorLiteral(red: 0.03, green: 0.04, blue: 0.08, alpha: 1))], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 28) {
                Spacer(minLength: 60)
                Text("You’re an Early Tester ✨")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("Thanks for being one of the first to try EnFlow. Some things may still be rough around the edges, but we’re working hard to improve the app every day. Your feedback is much appreciated!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal)

                Text("After you explore, first visit Settings → Profile to fill out your habits — it helps Sol personalize your forecasts.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    withAnimation(.spring()) { showConfetti = true }
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { onFinish() }
                } label: {
                    Text("Start Using EnFlow")
                        .padding(.horizontal, 48).padding(.vertical, 14)
                        .background(Capsule().fill(Color.yellow))
                        .foregroundColor(.black)
                        .scaleEffect(showConfetti ? 1.05 : 1)
                }
                .padding(.top, 20)

                Spacer()
            }
            if showConfetti { ConfettiView() }
        }
        .onDisappear { showConfetti = false }
    }
}

// Simple confetti using SF Symbols. Replace with better emitter if desired.
private struct ConfettiView: View {
    @State private var particles: [Particle] = (0..<30).map { _ in Particle() }
    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Image(systemName: "circle.fill")
                    .font(.system(size: p.size))
                    .foregroundColor(p.color)
                    .position(p.position)
                    .opacity(p.opacity)
                    .animation(.easeOut(duration: p.duration), value: p.position)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            for i in particles.indices {
                particles[i].animate()
            }
        }
    }
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint = .zero
        var opacity: Double = 1
        var size: CGFloat = CGFloat(Int.random(in: 4...10))
        let color: Color = [Color.yellow, .orange, .pink, .white].randomElement()!
        var duration: Double = Double.random(in: 1.0...1.8)
        mutating func animate() {
            let screen = UIScreen.main.bounds
            position = CGPoint(x: Double.random(in: 0...screen.width), y: -20)
            withAnimation(.easeOut(duration: duration)) {
                position = CGPoint(x: position.x + Double.random(in: -100...100), y: screen.height + 40)
                opacity = 0
            }
        }
    }
}
