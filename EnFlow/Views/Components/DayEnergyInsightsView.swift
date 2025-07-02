import SwiftUI
import Foundation

struct DayEnergyInsightsView: View {
    let forecast: [Double]
    let events: [CalendarEvent]
    let date: Date
    
    private let calendar = Calendar.current
    
    private var peakHour: Int? {
        guard let maxVal = forecast.max() else { return nil }
        return forecast.firstIndex(of: maxVal)
    }
    private var lowHour: Int? {
        guard let minVal = forecast.min() else { return nil }
        return forecast.firstIndex(of: minVal)
    }
    
    private func hourLabel(_ hr: Int) -> String {
        var comps = DateComponents()
        comps.hour = hr
        return calendar.date(from: comps)?.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))) ?? "\(hr)h"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let peak = peakHour {
                insightRow(icon: "arrow.up", color: .yellow, title: "Peak", hour: peak, score: Int(forecast[peak]*100))
            }
            if let low = lowHour {
                insightRow(icon: "arrow.down", color: .blue, title: "Low", hour: low, score: Int(forecast[low]*100))
            }
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(events) { ev in
                        EnergyImpactEventRow(event: ev)
                    }
                }
                .padding(.top, 8)
            }
            if let feedback = FeedbackStore.shared.feedback(for: date),
               let note = feedback.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func insightRow(icon: String, color: Color, title: String, hour: Int, score: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.8), radius: 4)
            Text("\(title): \(hourLabel(hour)) – Score: \(score)")
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct EnergyImpactEventRow: View {
    let event: CalendarEvent
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
    
    private var tagColor: Color {
        guard let delta = event.energyDelta else { return Color.green.opacity(0.3) }
        if delta > 0.05 { return .yellow }
        if delta < -0.05 { return .blue }
        return Color.green.opacity(0.3)
    }
    
    private var tagLabel: String? {
        guard let delta = event.energyDelta else { return nil }
        let pct = Int(delta * 100)
        if delta > 0 { return "+\(pct)% boost" }
        if delta < 0 { return "\(pct)% drop" }
        return nil
    }
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.eventTitle)
                    .font(.subheadline.bold())
                Text("\(formatter.string(from: event.startTime)) – \(formatter.string(from: event.endTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let tag = tagLabel {
                Text(tag)
                    .font(.caption2.bold())
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(tagColor)
                    .clipShape(Capsule())
                    .foregroundColor(.black)
            }
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#if DEBUG
struct DayEnergyInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        DayEnergyInsightsView(
            forecast: Array(repeating: 0.5, count: 24),
            events: [],
            date: Date()
        )
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
#endif
