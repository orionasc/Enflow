//
//  MainShellView.swift
//  EnFlow
//
//  Rev. 2025-06-17   • gear-icon → floating Settings sheet
//

import SwiftUI

struct MainShellView: View {
    @State private var showSettings = false
    /// Active tab index
    @State private var selection = 0
    /// Unique IDs to force-reset scroll position when a tab is revisited
    @State private var tabIDs: [Int: UUID] = [0: UUID(), 1: UUID(), 2: UUID(), 3: UUID()]
    private let accent = ColorPalette.color(for: 70)

    var body: some View {
        ZStack(alignment: .topLeading) {

            // ───────── Main content (tabs) ─────────
            #if os(iOS)
            TabView(selection: $selection) {
                NavigationView { DashboardView() }
                    .id(tabIDs[0]!)
                    .tabItem {
                        TabBarLabel(title: "Dashboard", systemImage: "waveform.path.ecg", index: 0, selection: $selection)
                    }
                    .tag(0)

                NavigationView { CalendarRootView() }
                    .id(tabIDs[1]!)
                    .tabItem {
                        TabBarLabel(title: "Calendar", systemImage: "calendar", index: 1, selection: $selection)
                    }
                    .tag(1)

                NavigationView { TrendsView() }
                    .id(tabIDs[2]!)
                    .tabItem {
                        TabBarLabel(title: "Trends", systemImage: "chart.bar.fill", index: 2, selection: $selection)
                    }
                    .tag(2)

                NavigationView { UserProfileSummaryView() }
                    .id(tabIDs[3]!)
                    .tabItem {
                        TabBarLabel(title: "User", systemImage: "person.crop.circle", index: 3, selection: $selection)
                    }
                    .tag(3)
            }
            .onChange(of: selection) { newValue in
                // Regenerate IDs for non-active tabs so they reset when revisited
                for index in 0..<4 where index != newValue {
                    tabIDs[index] = UUID()
                }
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
