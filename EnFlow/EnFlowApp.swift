// EnFlowApp.swift
// Entry Point for EnFlow – Energy Intelligence Platform

import SwiftUI

@main
struct EnFlowApp: App {
    @AppStorage("didCompleteOnboarding") private var onboarded = false

    var body: some Scene {
        WindowGroup {
            if onboarded {
                MainShellView()
            } else {
                OnboardingAndSettingsView()
            }
        }
    }
}

