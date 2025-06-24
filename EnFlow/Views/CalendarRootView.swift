//  CalendarRootView.swift
//  EnFlow — Unified calendar container with styled dropdown nav and gradient background

import SwiftUI

enum CalendarMode: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }
}

struct CalendarRootView: View {
    @State private var mode: CalendarMode = .day

    var body: some View {
        VStack(spacing: 0) {
            // Dropdown Header — Top Right
            HStack {
                Spacer()
                Menu {
                    ForEach(CalendarMode.allCases) { option in
                        Button {
                            withAnimation { mode = option }
                        } label: {
                            Label(option.rawValue, systemImage: mode == option ? "checkmark.circle.fill" : "circle")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(mode.rawValue)
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .offset(y: 1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                            .shadow(radius: 2)
                    )
                }
                .padding(.top, 72)
                .padding(.trailing, 20)
            }

            // Dynamic View Injection
            switch mode {
            case .day:
                DayView(date: Date())
                    .transition(.opacity)
            case .week:
                WeekCalendarView()
                    .transition(.opacity)
            case .month:
                MonthCalendarView()
                    .transition(.opacity)
            }
        }
        .enflowBackground()
        .animation(.easeInOut(duration: 0.25), value: mode)
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct CalendarRootView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarRootView()
    }
}
