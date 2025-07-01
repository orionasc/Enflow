import SwiftUI

struct DailyEnergyForecastView: View {
    /// Energy values for consecutive hours starting at `startHour`.
    let values: [Double]
    /// First hour represented in `values`. Defaults to 7AM for backward
    /// compatibility with the dashboard.
    let startHour: Int
    /// Hour to highlight with a pulsing dot. Nil to disable.
    let highlightHour: Int?
    
    @State private var pulse = false
    @State private var activeIndex: Int? = nil
    @State private var tooltipWidth: CGFloat = 0
    @State private var dragging = false
    
    private let calendar = Calendar.current
    
    init(values: [Double], startHour: Int = 7, highlightHour: Int? = nil) {
        self.values = values
        self.startHour = startHour
        self.highlightHour = highlightHour
    }
    
    var body: some View {
        GeometryReader { proxy in
            let count = values.count
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                let clamped = values.map { min(max($0, 0), 1) }
                let points = (0..<count).map { i -> CGPoint in
                    let x = width * CGFloat(i) / CGFloat(max(count - 1, 1))
                    let y = height * (1 - CGFloat(clamped[i]))
                    return CGPoint(x: x, y: y)
                }
                let path = smoothPath(points)
                let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                
                ColorPalette.verticalEnergyGradient
                    .mask(path.stroke(style: stroke))
                    .overlay(
                        ColorPalette.verticalEnergyGradient
                            .mask(path.stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)))
                            .blur(radius: 3)
                            .opacity(0.7)
                    )
                    .overlay(
                        ColorPalette.gradient(for: average(clamped) * 100)
                            .mask(path.stroke(style: stroke))
                            .blendMode(.overlay)
                    )
                
                if let h = highlightHour, h >= startHour, h < startHour + count {
                    let idx = h - startHour
                    let pt = points[idx]
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                                .scaleEffect(pulse ? 1.6 : 1)
                                .opacity(pulse ? 0 : 1)
                        )
                        .position(pt)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                                pulse.toggle()
                            }
                        }
                }

                ForEach(Array(stride(from: 0, to: count, by: 2)), id: \.self) { idx in
                    let x = width * CGFloat(idx) / CGFloat(max(count - 1, 1))
                    Text(hourLabel(startHour + idx))
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .position(x: x, y: height + 10)
                }

                ForEach(significantPeaksAndTroughs(), id: \.self) { idx in
                    let x = width * CGFloat(idx) / CGFloat(max(count - 1, 1))
                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: height))
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.5), location: 0.5),
                                .init(color: .clear, location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }

                if let idx = activeIndex {
                    let point = points[idx]
                    let score = Int(clamped[idx] * 100)
                    let label = hourLabel(startHour + idx)

                    Path { p in
                        p.move(to: point)
                        p.addLine(to: CGPoint(x: point.x, y: point.y - 18))
                    }
                    .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [2]))

                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .position(point)

                    TooltipBubble(hour: label, score: score)
                        .background(GeometryReader { g in
                            Color.clear.onAppear { tooltipWidth = g.size.width }
                        })
                        .position(x: clamp(point.x, lower: tooltipWidth / 2, upper: width - tooltipWidth / 2),
                                  y: point.y - 28)
                        .animation(.easeInOut(duration: 0.25), value: activeIndex)
                        .transition(.opacity)
                }
            }
        }
        .frame(height: 80)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragging = true
                    let x = min(max(0, value.location.x), width)
                    let idx = Int(round(x / width * CGFloat(max(count - 1, 1))))
                    if idx != activeIndex {
                        activeIndex = idx
                    }
                }
                .onEnded { _ in
                    dragging = false
                    withAnimation(.easeOut(duration: 0.2)) { activeIndex = nil }
                }
        )
#if !os(iOS)
        .onHover { inside in
            if !inside && !dragging {
                activeIndex = nil
            }
        }
#endif
    }

    private func average(_ vals: [Double]) -> Double {
        guard !vals.isEmpty else { return 0.5 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents(); comps.hour = hour
        return calendar.date(from: comps)?
            .formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))) ?? "\(hour)h"
    }

    private func significantPeaksAndTroughs(threshold: Double = 0.15) -> [Int] {
        guard values.count > 2 else { return [] }
        var result: [Int] = []
        for i in 1..<(values.count - 1) {
            let prev = values[i - 1]
            let curr = values[i]
            let next = values[i + 1]
            let isPeak = curr > prev && curr > next && curr - min(prev, next) > threshold
            let isTrough = curr < prev && curr < next && max(prev, next) - curr > threshold
            if isPeak || isTrough { result.append(i) }
        }
        return result
    }

    private func smoothPath(_ pts: [CGPoint]) -> Path {
        var path = Path()
        guard pts.count > 1 else { return path }
        path.move(to: pts[0])
        for i in 1..<pts.count {
            let prev = pts[i - 1]
            let curr = pts[i]
            let dx = curr.x - prev.x
            let c1 = CGPoint(x: prev.x + dx * 0.6, y: prev.y)
            let c2 = CGPoint(x: curr.x - dx * 0.6, y: curr.y)
            path.addCurve(to: curr, control1: c1, control2: c2)
        }
        return path
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

private struct TooltipBubble: View {
    let hour: String
    let score: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(hour)
            Text("\(score)")
        }
        .font(.caption.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
        .foregroundColor(.white)
    }
}
