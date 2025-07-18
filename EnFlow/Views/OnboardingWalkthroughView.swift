import SwiftUI

// MARK: ─────────────────────────────────────────────────────────────
//  EnFlow Onboarding Walkthrough – Cohesive Styling Pass 2025‑07‑18
//  -----------------------------------------------------------------
//  • Adds a subtle glowing frame + ambient radial overlay to every
//    onboarding page for visual unity (tap‑through now fixed).
//  • Applies page‑specific background tweaks per design brief.
//  • Introduces a simple Color(hex:) helper for hex literals.
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
            MeetSolPage().tag(4)
            EarlyTesterPage(onFinish: completeOnboarding).tag(5)
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

// MARK: – Shared View Modifiers
private extension View {
    /// Subtle glowing frame used on every onboarding page. Now ignores hit‑testing so taps pass through.
    func onboardingFrame() -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 32)
                .strokeBorder(
                    LinearGradient(colors: [
                        Color.white.opacity(0.06),
                        Color.yellow.opacity(0.04)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )
                .blur(radius: 2)
                .padding(.horizontal, 20)
                .allowsHitTesting(false) // ← critical fix
        )
    }

    /// Soft radial glow at the top of every page. Hit‑testing disabled to allow underlying gestures.
    func onboardingAmbientGlow() -> some View {
        self.overlay(
            RadialGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.03), .clear]),
                center: .top,
                startRadius: 10,
                endRadius: 600
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
    }
}

// MARK: – PAGE 1 — Welcome
struct WelcomePage: View {
    var mg: Namespace.ID
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Existing animated radial background
            TimelineView(.animation(minimumInterval: 1/20)) { context in
                let t = context.date.timeIntervalSinceReferenceDate / 6
                let x = 0.5 + 0.1 * cos(t)
                let y = 0.5 + 0.1 * sin(t)
                RadialGradient(
                    colors: [
                        Color(#colorLiteral(red: 0.984, green: 0.749, blue: 0.141, alpha: 1)),
                        Color(#colorLiteral(red: 0.9098039269, green: 0.4784313738, blue: 0.6431372762, alpha: 1))
                    ],
                    center: .init(x: x, y: y),
                    startRadius: 40,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 18) {
                Spacer()
                ZStack {
                    RadialGradient(
                        gradient: Gradient(colors: [Color.yellow.opacity(0.6), .clear]),
                        center: .center,
                        startRadius: 10,
                        endRadius: 120
                    )
                    .scaleEffect(pulse ? 2 : 2.6)
                    .opacity(pulse ? 0.8 : 0.6)

                    Image(systemName: "bolt")
                        .font(.system(size: 250, weight: .light))
                        .blur(radius: 3)
                        .foregroundStyle(LinearGradient(colors: [.white, .white], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .yellow.opacity(0.6), radius: 20)
                        .scaleEffect(pulse ? 1.05 : 0.95)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { pulse = true }
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
                Image(systemName: "chevron.right")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(0.8)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal)
        }
        .onboardingFrame()
        .onboardingAmbientGlow()
    }
}

struct EnergyRingDemoPage: View {
    @State private var demoScore: Double = 25
    @State private var index = 0
    @State private var cycleInterval: TimeInterval = 10
    @State private var demoTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct DemoState { let score: Double; let title: String; let description: String }

    private let demoStates: [DemoState] = [
        .init(score: 25, title: "Low Energy", description: "Your body is signaling a need for rest or recovery. It’s a good day for lighter commitments and extra care."),
        .init(score: 65, title: "Functional", description: "You’re in a steady, usable state — focused enough to move through your day without much friction."),
        .init(score: 80, title: "High Energy", description: "You’re energized and in rhythm. This is a great time for productivity, engagement, and forward motion."),
        .init(score: 95, title: "Supercharged", description: "You’re at your peak. Leverage this window for challenging tasks, creative work, or deep focus."),
        .init(score: 100, title: "Radiant", description: "An exceptional recovery state. Expect mental clarity, resilience, and a strong physical baseline.")
    ]

    private var demoScores: [Double] { demoStates.map { $0.score } }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#0b0c23"), Color(hex: "#1b1036")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer(minLength: 60)

                Text("Your Energy Score")
                    .font(.title.bold())
                    .foregroundColor(.white)

                EnergyRingView(score: demoScore, animateFromZero: true, shimmer: demoScore < 95)
                    .frame(width: 200, height: 200)
                    .clipShape(Circle())
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: demoScore)
                    .onTapGesture { cycleState() }

                let state = demoStates[index]
                Text(state.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .transition(.opacity)
                    .animation(reduceMotion ? nil : .easeInOut, value: index)

                Text(state.description)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity)
                    .animation(reduceMotion ? nil : .easeInOut, value: index)

                Text("Tap below to explore different energy states")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.headline)

                HStack(spacing: 16) {
                    ForEach(demoScores.indices, id: \.self) { i in
                        Circle()
                            .fill(i == index ? Color.yellow : Color.white.opacity(0.3))
                            .frame(width: 14, height: 14)
                            .onTapGesture { selectState(i) }
                    }
                }

                Text("Your score is a reflection of your current energy. Note that it does not reflect your overall health. Energy levels can fluctuate over time.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding()

                Spacer()
            }
            .onAppear { restartCycleTimer() }
            .onReceive(demoTimer) { _ in cycleState() }
        }
        .onboardingFrame()
        .onboardingAmbientGlow()
    }

    private func cycleState() {
        withAnimation {
            index = (index + 1) % demoScores.count
            demoScore = demoScores[index]
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func selectState(_ i: Int) {
        withAnimation {
            index = i
            demoScore = demoScores[i]
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        restartCycleTimer()
    }

    private func restartCycleTimer() {
        demoTimer = Timer.publish(every: cycleInterval, on: .main, in: .common).autoconnect()
    }
}


// MARK: – PAGE 3 — Waveform Demo
struct WaveformDemoPage: View {
    @State private var drawWave = false

    private var sampleWave: [Double] {
        let count = 240
        return (0..<count).map { i in
            let x = Double(i) / Double(count - 1) * .pi * 2
            return 0.5 + 0.4 * sin(x)
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(#colorLiteral(red: 0.05, green: 0.08, blue: 0.2, alpha: 1)), Color(#colorLiteral(red: 0.12, green: 0.12, blue: 0.12, alpha: 1))], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            // Subtle yellow glow beneath the waveform
            RadialGradient(gradient: Gradient(colors: [Color.yellow.opacity(0.05), .clear]), center: .center, startRadius: 10, endRadius: 400)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 40)
                Text("Your Energy Waveform")
                    .font(.title.bold())
                    .foregroundColor(.white)

                DailyEnergyForecastView(values: sampleWave, startHour: 0)
                    .frame(height: 140)
                    .padding(.horizontal)
                    .mask(
                        Rectangle()
                            .scaleEffect(x: drawWave ? 1 : 0, anchor: .leading)
                            .animation(.easeOut(duration: 1.5), value: drawWave)
                    )
                    .onAppear { drawWave = true }

                Text("Your energy waveform is a continuous view of how your mind and body tend to rise, peak, and wind down throughout the day. The more you use EnFlow, the more personal and accurate this becomes.")
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
        }
        .onboardingFrame()
        .onboardingAmbientGlow()
    }
}

// MARK: – PAGE 4 — Sync Tips
struct SyncTipsPage: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(#colorLiteral(red: 0.08, green: 0.09, blue: 0.18, alpha: 1)), Color(#colorLiteral(red: 0.04, green: 0.05, blue: 0.1, alpha: 1))], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

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
        // Soft top‑center glow to unify pages
        .onboardingFrame()
        .onboardingAmbientGlow()
        .overlay(
            RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.04), .clear]), center: .top, startRadius: 20, endRadius: 300)
                .ignoresSafeArea()
        )
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

// MARK: – PAGE 5 — Meet Sol
struct MeetSolPage: View {
    @State private var factIndex = 0
    private let facts = [
        "Sol weighs your sleep quality and HRV trends.",
        "Sol notices when certain events boost or drain you.",
        "Sol forecasts tomorrow by learning from yesterday."
    ]

    var body: some View {
        ZStack {
            // Bright yellow base + subtle orange radial fade for depth
            RadialGradient(gradient: Gradient(colors: [Color.yellow, Color.orange]), center: .center, startRadius: 20, endRadius: 500)
                .ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color.orange.opacity(0.2), .clear]), center: .center, startRadius: 10, endRadius: 600)
                .ignoresSafeArea()

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
                Text("Sol is the adaptive energy model that helps you sleep better, recover faster, and perform at your best.")
                    .foregroundColor(.white.opacity(0.9))
                Text("In future updates, Sol will become interactive — a chatbot that understands your needs and can even help you reschedule, adjust plans, or nudge you toward better recovery.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal)
                Text(facts[factIndex])
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
            .padding(.horizontal)
        }
        .onboardingFrame()
        .onboardingAmbientGlow()
    }
}

// MARK: – PAGE 6 — Early Tester / CTA
struct EarlyTesterPage: View {
    let onFinish: () -> Void
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(#colorLiteral(red: 0.15, green: 0.12, blue: 0.32, alpha: 1)), Color(#colorLiteral(red: 0.03, green: 0.04, blue: 0.08, alpha: 1))], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            // Lighten bottom area slightly
            LinearGradient(colors: [Color.white.opacity(0.02), .clear], startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()

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

                Text("The accuracy of your forecasts depends on how often you use your wearable health device. While encouraged, you don’t have to wear it to sleep — but the more health data you provide the better our forecasts will be.")
                    .font(.footnote)
                    .foregroundColor(.yellow.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("Feel free to start exploring or visit Settings → Profile to fill out your habits — they help Sol personalize your forecasts.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    withAnimation(.spring()) { showConfetti = true }
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { onFinish() }
                } label: {
                    Text("Start Using Enflow")
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
        .onboardingFrame()
        .onboardingAmbientGlow()
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
        .onAppear { for i in particles.indices { particles[i].animate() } }
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

// MARK: – Utilities
private extension Color {
    /// Convenience initializer for hex strings like "#1b1036".
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 3: // RGB (12‑bit)
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RGB (24‑bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB (32‑bit)
            (r, g, b, a) = (int >> 24 & 0xFF, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (1, 1, 1, 1)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
