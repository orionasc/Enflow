import SwiftUI

struct EnergyLineChartView: View {
    let values: [Double] // expects 24 values 0–1

    var body: some View {
        GeometryReader { proxy in
            let count = values.count
            let width = proxy.size.width
            let height = proxy.size.height

            // Convert values to points
            let points = (0..<count).map { i -> CGPoint in
                let x = width * CGFloat(i) / CGFloat(count - 1)
                let y = height * (1 - CGFloat(values[i]))
                return CGPoint(x: x, y: y)
            }

            // Smoothed waveform path
            let waveform = smoothPath(points)
            let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)

            // Vertical heatmap masked by waveform
            ColorPalette.verticalEnergyGradient
                .mask(waveform.stroke(style: stroke))
                .overlay(
                    // Subtle left→right tint based on average score
                    ColorPalette.gradient(for: average(values) * 100)
                        .mask(waveform.stroke(style: stroke))
                        .blendMode(.overlay)
                )
        }
        .frame(height: 60)
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.5 }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Path smoothing
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

#Preview {
    ZStack {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.08, blue: 0.20),
                Color(red: 0.12, green: 0.12, blue: 0.12)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        EnergyLineChartView(
            values: [0.1, 0.3, 0.6, 0.5, 0.8, 1.0, 0.7, 0.4,
                     0.2, 0.4, 0.6, 0.9, 0.7, 0.5, 0.3, 0.2,
                     0.3, 0.5, 0.8, 1.0, 0.9, 0.6, 0.4, 0.2]
        )
        .padding(.horizontal)
    }
    .frame(height: 80)
}


//needs to be smoothed, have sleep logic (so it should be able to predict consistently low energy levels during the night, if sleep data is provided great it should use that, but it should still be reletaively accurate if no sleep data is provided, needs to have a low value -> high value color gradient applied to it from top to bottom. can use our color pallete, but I still want the subtle right to left gradient too. 
