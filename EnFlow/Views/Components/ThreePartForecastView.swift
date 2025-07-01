//  ThreePartForecastView.swift
//  EnFlow
//
//  Added dashed + desaturate support
//

import SwiftUI

struct ThreePartForecastView: View {
  /// `nil` values indicate missing Health data for that period.
  let parts: EnergyForecastModel.EnergyParts?
  var dashed: Bool = false
  var desaturate: Bool = false

  private let ringSize: CGFloat = 80
  private let lineWidth: CGFloat = 6
  private let spacing: CGFloat = 20

  var body: some View {
    HStack(spacing: spacing) {
      ring(title: "Morning", value: parts?.morning, startHour: 5)
      ring(title: "Afternoon", value: parts?.afternoon, startHour: 12)
      ring(title: "Evening", value: parts?.evening, startHour: 17)
    }
    .frame(maxWidth: .infinity)
    .saturation(desaturate ? 0.6 : 1.0)
  }

  @ViewBuilder
  private func ring(title: String, value: Double?, startHour: Int) -> some View {
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

        if isAvailable, let val = value {
          Circle()
            .trim(from: 0, to: CGFloat(val / 100))
            .stroke(
              ColorPalette.gradient(for: val),
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
            Text("\(Int(val))")
              .font(Font.system(.title3, design: .rounded).weight(.bold))
              .foregroundColor(.white)
              .shadow(color: ColorPalette.color(for: val).opacity(0.8), radius: 3)
          }
        } else {
          Text("--")
            .font(Font.system(.title3, design: .rounded))
            .foregroundColor(.white.opacity(0.6))
            .shadow(color: .white.opacity(0.3), radius: 2)
        }
      }

      if isAvailable, let val = value {
        Text(status(for: val))
          .font(.caption2)
          .fontWeight(.medium)
          .foregroundColor(ColorPalette.color(for: val))
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
