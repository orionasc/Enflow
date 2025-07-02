import SwiftUI
import Foundation

struct DayEnergyInsightsView: View {
    let forecast: [Double]
    let events: [CalendarEvent]
    /// Events shown in the "Event Impact" section after filtering out
    /// all-day events and ones longer than six hours.
    private var impactEvents: [CalendarEvent] {
        events.filter { ev in
            !ev.isAllDay &&
            ev.endTime.timeIntervalSince(ev.startTime) <= 6 * 3600
        }
    }
    let date: Date
    
    @State private var showEventImpact: Bool
    
    private let calendar = Calendar.current
    
    init(forecast: [Double], events: [CalendarEvent], date: Date) {
        self.forecast = forecast
        self.events = events
        self.date = date
        // Show the section by default only when a small number of
        // qualifying events exist.
        let filtered = events.filter { ev in
            !ev.isAllDay &&
            ev.endTime.timeIntervalSince(ev.startTime) <= 6 * 3600
        }
        _showEventImpact = State(initialValue: filtered.count < 3)
    }
    
    private var peakHour: Int? {
        guard let maxVal = forecast.max() else { return nil }
        return forecast.firstIndex(of: maxVal)
    }
    private var lowHour: Int? {
        let rangeHours = 7...19
        let filtered = forecast.enumerated().filter { rangeHours.contains($0.offset) }
        guard let minPair = filtered.min(by: { $0.element < $1.element }) else { return nil }
        return minPair.offset
    }
    
    private func hourLabel(_ hr: Int) -> String {
        var comps = DateComponents()
        comps.hour = hr
        return calendar.date(from: comps)?.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))) ?? "\(hr)h"
    }
    
    var body: some View {
        if forecast.isEmpty {
            Text("No energy data available for this day.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                if let peak = peakHour {
                    insightRow(icon: "arrow.up", color: .yellow, title: "Peak", hour: peak, score: Int(forecast[peak]*100))
                }
                if let low = lowHour {
                    insightRow(icon: "arrow.down", color: .blue, title: "Low", hour: low, score: Int(forecast[low]*100))
                } else {
                    Text("No low point during the active day.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if !impactEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: { withAnimation(.easeInOut) { showEventImpact.toggle() } }) {
                            HStack {
                                Text("Event Impact")
                                    .font(.headline)
                                Image(systemName: "bolt.arrow.up.circle.fill")
                                    .foregroundColor(.yellow)
                                    .brightness(0.3)
                                    .saturation(1.8)
                                    .shadow(color: Color.yellow.opacity(0.8), radius: 4)
                                Spacer()
                                if !showEventImpact {
                                    Text("\(impactEvents.count) events today")
                                        .foregroundColor(.secondary)
                                }
                                Image(systemName: "chevron.down")
                                    .rotationEffect(.degrees(showEventImpact ? 0 : -90))
                            }
                        }

                        if showEventImpact {
                            ForEach(impactEvents) { ev in
                                EnergyImpactEventRow(event: ev, forecast: forecast)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .animation(.easeInOut, value: showEventImpact)
                }
                
                if let feedback = FeedbackStore.shared.feedback(for: date),
                   let note = feedback.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
    
    private struct EnergyImpactEventRow: View {
        let event: CalendarEvent
        let forecast: [Double]
        
        private let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f
        }()
        
        private let calendar = Calendar.current
        
        private func energy(at date: Date) -> Double? {
            let hr = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            guard forecast.indices.contains(hr) else { return nil }
            let base = forecast[hr]
            let next = forecast.indices.contains(hr + 1) ? forecast[hr + 1] : base
            return base + (next - base) * Double(minute) / 60.0
        }
        
        private enum ImpactType {
            case boost(Double)
            case drain(Double)
            case neutral(Double)
            case insufficient
            
            var color: Color {
                switch self {
                case .boost: return .yellow
                case .drain: return .cyan
                case .neutral: return Color.green.opacity(0.4)
                case .insufficient: return .gray
                }
            }
            
            var brightness: Double {
                switch self {
                case .boost, .drain: return 0.3
                default: return 0.0
                }
            }
            
            var saturation: Double {
                switch self {
                case .boost: return 1.8
                case .drain: return 1.5
                default: return 1.0
                }
            }
            
            var icon: String {
                switch self {
                case .boost: return "bolt.arrow.up"
                case .drain: return "arrow.down.circle.fill"
                case .neutral: return "equal.circle"
                case .insufficient: return "questionmark"
                }
            }
            
            var label: String {
                switch self {
                case .boost(let v): return String(format: "+%.0f%%", v)
                case .drain(let v): return String(format: "%.0f%%", v)
                case .neutral(let v): return String(format: "%.0f%%", v)
                case .insufficient: return "Insufficient data"
                }
            }
        }
        
        private var impact: ImpactType {
            guard let before = energy(at: event.startTime.addingTimeInterval(-1800)),
                  let after = energy(at: event.endTime.addingTimeInterval(1800)) else {
                return .insufficient
            }
            let change = (after - before) * 100
            if change >= 5 { return .boost(change) }
            if change <= -5 { return .drain(change) }
            return .neutral(change)
        }
        
        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: impact.icon)
                    .foregroundColor(impact.color)
                    .brightness(impact.brightness)
                    .saturation(impact.saturation)
                    .shadow(color: impact.color.opacity(0.8), radius: 3)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.eventTitle)
                        .font(.subheadline.bold())
                    Text("\(formatter.string(from: event.startTime)) – \(formatter.string(from: event.endTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(impact.label)
                    .font(.caption2.weight(.semibold))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule()
                            .fill(impact.color.opacity(0.2))
                    )
            }
            .padding(8)
            .frame(minHeight: 60)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                Rectangle()
                    .fill(impact.color)
                    .brightness(impact.brightness)
                    .saturation(impact.saturation)
                    .frame(width: 3),
                alignment: .leading
            )
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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

