//  ThreePartForecastView.swift
//  EnFlow
//
//  Added dashed + desaturate support
//

import SwiftUI

struct ThreePartForecastView: View {
  let parts: EnergyForecastModel.EnergyParts
  var dashed: Bool = false
  var desaturate: Bool = false

  private let ringSize: CGFloat = 80
  private let lineWidth: CGFloat = 6
  private let spacing: CGFloat = 20

  var body: some View {
    HStack(spacing: spacing) {
      ring(title: "Morning", value: parts.morning, startHour: 5)
      ring(title: "Afternoon", value: parts.afternoon, startHour: 12)
      ring(title: "Evening", value: parts.evening, startHour: 17)
    }
    .frame(maxWidth: .infinity)
    .saturation(desaturate ? 0.6 : 1.0)
  }

  @ViewBuilder
  private func ring(title: String, value: Double, startHour: Int) -> some View {
    let currentHour = Calendar.current.component(.hour, from: Date())
    let isAvailable = currentHour >= startHour

    VStack(spacing: 6) {
      ZStack {
        Circle()
          .stroke(
            Color.white.opacity(0.10),
            style: StrokeStyle(
              lineWidth: lineWidth,
              dash: dashed ? [4, 2] : [])
          )
          .frame(width: ringSize, height: ringSize)

        if isAvailable {
          Circle()
            .trim(from: 0, to: CGFloat(value / 100))
            .stroke(
              ColorPalette.gradient(for: value),
              style: StrokeStyle(
                lineWidth: lineWidth,
                lineCap: .round,
                dash: dashed ? [4, 2] : [])
            )
            .rotationEffect(.degrees(-90))
            .frame(width: ringSize, height: ringSize)

          VStack(spacing: 2) {
            Text(title)
              .font(.caption)
              .foregroundColor(.white)
            Text("\(Int(value))")
              .font(.title3.bold())
              .foregroundColor(.white)
          }
        } else {
          Text("--")
            .font(.title3)
            .foregroundColor(.white.opacity(0.6))
        }
      }

      if isAvailable {
        Text(status(for: value))
          .font(.caption2)
          .fontWeight(.medium)
          .foregroundColor(ColorPalette.color(for: value))
      }
    }
    .frame(width: ringSize, height: ringSize + 24)
  }

  private func status(for v: Double) -> String {
    switch v {
    case 0..<50: "Low"
    case 50..<80: "Moderate"
    default: "High"
    }
  }
}
