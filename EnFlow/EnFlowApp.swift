// EnFlowApp.swift
// Entry Point for EnFlow – Energy Intelligence Platform

import SwiftUI
#if os(iOS)
import UIKit
#endif

@main
struct EnFlowApp: App {
    @AppStorage("didCompleteOnboarding") private var onboarded = false

#if os(iOS)
    init() { setupAppearance() }
#endif

    var body: some Scene {
        WindowGroup {
            if onboarded {
                MainShellView()
            } else {
                OnboardingAndSettingsView()
            }
            .preferredColorScheme(.dark)
        }
    }

#if os(iOS)
    private func setupAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = UIColor(red: 0.05, green: 0.08, blue: 0.20, alpha: 0.8)
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundColor = UIColor(red: 0.05, green: 0.08, blue: 0.20, alpha: 0.8)
        UITabBar.appearance().standardAppearance = tab
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tab
        }
    }
#endif
}

