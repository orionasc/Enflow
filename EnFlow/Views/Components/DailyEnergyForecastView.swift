import SwiftUI

struct DailyEnergyForecastView: View {
    /// Energy values from 7 AM to 7 PM inclusive (13 values, 0-1)
    let values: [Double]
    private let startHour = 7
    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { proxy in
            let count = values.count
            let width = proxy.size.width
            let height = proxy.size.height

            // points for smoothed path
            let points = (0..<count).map { i -> CGPoint in
                let x = width * CGFloat(i) / CGFloat(max(count - 1, 1))
                let y = height * (1 - CGFloat(values[i]))
                return CGPoint(x: x, y: y)
            }
            let path = smoothPath(points)
            let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)

            // gradient line
            ColorPalette.verticalEnergyGradient
                .mask(path.stroke(style: stroke))
                .overlay(
                    ColorPalette.gradient(for: average(values) * 100)
                        .mask(path.stroke(style: stroke))
                        .blendMode(.overlay)
                )

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
