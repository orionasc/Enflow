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

            // points for smoothed path
            let clamped = values.map { min(max($0, 0), 1) }
            let points = (0..<count).map { i -> CGPoint in
                let x = width * CGFloat(i) / CGFloat(max(count - 1, 1))
                let y = height * (1 - CGFloat(clamped[i]))
                return CGPoint(x: x, y: y)
            }
            let path = smoothPath(points)
            let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)

            // gradient line
            ColorPalette.verticalEnergyGradient
                .mask(path.stroke(style: stroke))
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

            // hour labels
            ForEach(0..<count, id: \.self) { idx in
                let x = width * CGFloat(idx) / CGFloat(max(count - 1, 1))
                Text(hourLabel(startHour + idx))
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .position(x: x, y: height + 10)
            }

            // peak/trough indicators
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
        }
        .frame(height: 80)
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
            let prev = pts[i-1]
            let curr = pts[i]
            let dx = curr.x - prev.x
            let c1 = CGPoint(x: prev.x + dx * 0.6, y: prev.y)
            let c2 = CGPoint(x: curr.x - dx * 0.6, y: curr.y)
            path.addCurve(to: curr, control1: c1, control2: c2)
        }
        return path
    }
}
