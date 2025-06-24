import SwiftUI

struct EnergyLineChartView: View {
    let values: [Double] // expects 24 values 0–1

    var body: some View {
        GeometryReader { proxy in
            let count = values.count
            let width = proxy.size.width
            let height = proxy.size.height

            // Build the entire waveform path
            let waveform = Path { p in
                for i in 0..<count {
                    let x = width * CGFloat(i) / CGFloat(count - 1)
                    let y = height * (1 - CGFloat(values[i]))
                    if i == 0 {
                        p.move(to: CGPoint(x: x, y: y))
                    } else {
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }

            // Gradient: blue → green → yellow
            let gradient = ColorPalette.gradient(for: average(values) * 100)

            // Mask the gradient with the stroke of the path
            gradient
                .mask(
                    waveform
                        .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                )
        }
        .frame(height: 60)
    }
    
    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.5 }
        return values.reduce(0, +) / Double(values.count)
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
