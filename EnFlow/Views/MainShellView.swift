//
//  MainShellView.swift
//  EnFlow
//
//  Rev. 2025-06-17   • gear-icon → floating Settings sheet
//

import SwiftUI

struct MainShellView: View {
    @State private var showSettings = false
    private let accent = ColorPalette.color(for: 70)

    var body: some View {
        ZStack(alignment: .topLeading) {

            // ───────── Main content (tabs) ─────────
            #if os(iOS)
            TabView {
                NavigationView { DashboardView() }
                    .tabItem { Label("Dashboard", systemImage: "waveform.path.ecg") }

                NavigationView { CalendarRootView() }
                    .tabItem { Label("Calendar", systemImage: "calendar") }

                NavigationView { TrendsView() }
                    .tabItem { Label("Trends", systemImage: "chart.bar.fill") }

                NavigationView { UserProfileSummaryView() }
                    .tabItem { Label("User", systemImage: "person.crop.circle") }
            }
            .tint(accent)
            .enflowBackground()
            #else
            NavigationSplitView {
                List {
                    NavigationLink(destination: DashboardView())      { Label("Dashboard", systemImage: "waveform.path.ecg") }
                    NavigationLink(destination: EnergyCalendarView()) { Label("Calendar",  systemImage: "calendar") }
                    NavigationLink(destination: TrendsView())         { Label("Trends",    systemImage: "chart.bar.fill") }
                    NavigationLink(destination: UserProfileSummaryView()) { Label("User", systemImage: "person.crop.circle") }
                }
                .listStyle(.sidebar)
                .tint(accent)
                .frame(minWidth: 180)
            } detail: { DashboardView() }
            .enflowBackground()
            #endif

            // ───────── Gear button ─────────
            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3.weight(.semibold))
                    .padding(14)
            }
            .accessibilityLabel("Settings")
        }
        // ───────── Floating sheet ─────────
        .sheet(isPresented: $showSettings) {
            OnboardingAndSettingsView()
                .presentationDetents([.fraction(0.95)])        // pop-up height
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
                .presentationBackground(.ultraThinMaterial)    // depth-effect blur
        }
    }
}

struct MainShellView_Previews: PreviewProvider {
    static var previews: some View { MainShellView() }
}
