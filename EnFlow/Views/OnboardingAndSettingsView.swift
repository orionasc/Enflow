//
//  OnboardingAndSettingsView.swift
//  EnFlow
//
//  Rev. 2025-06-17  • Fix .onChange signature + live permission toggles
//

import SwiftUI
import EventKit
import HealthKit
#if os(iOS)
import UIKit
#endif

struct OnboardingAndSettingsView: View {

    // ───── Persistent prefs ─────
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @AppStorage("gptTone")               private var gptTone               = "wellness"

    // ───── Runtime state ─────
    @State private var calendarGranted = false
    @State private var healthGranted   = false

    @State private var showSettingsAlert = false      // for revoke-flow

    // ───── API-key section ─────
    @State private var apiKeyInput = ""
    @State private var apiStatus   = ""

    private var hasStoredKey: Bool {
        (try? KeychainHelper.read())?.isEmpty == false
    }

    // ────────────────── UI ──────────────────
    var body: some View {
        NavigationView {
            Form {
                // ─── First-run onboarding ───
                if !didCompleteOnboarding { onboardingSection }

                // ─── Permissions ───
                Section(header: Text("Permissions")) {
                    Toggle(isOn: $calendarGranted) {
                        Label("Calendar", systemImage: "calendar")
                    }
                    .onChange(of: calendarGranted, perform: calendarToggleChanged)

                    Toggle(isOn: $healthGranted) {
                        Label("Health", systemImage: "heart")
                    }
                    .onChange(of: healthGranted, perform: healthToggleChanged)
                }

                // ─── OpenAI API key ───
                apiKeySection

                // ─── Preferences ───
                preferencesSection

                // ─── About ───
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .enflowBackground()
        .onAppear(perform: refreshAuthStatus)
        .alert("Revoke permission in Settings",
               isPresented: $showSettingsAlert,
               actions: systemSettingsButtons,
               message: { Text("iOS only lets you turn access off from the Settings app.") })
    }

    // ────────────────── Sub-sections ──────────────────
    @ViewBuilder
    private var onboardingSection: some View {
        Section(header: Text("Welcome to EnFlow")) {
            Text("To personalize your energy forecast we need access to your Apple Calendar and Health data.")
            Button("Grant Calendar Access") {
                CalendarDataPipeline.shared.requestAccess { granted in
                    calendarGranted = granted
                    completeIfBothGranted()
                }
            }
            Button("Grant Health Access") {
                HealthDataPipeline.shared.requestAuthorization { granted in
                    healthGranted = granted
                    completeIfBothGranted()
                }
            }
        }
    }

    @ViewBuilder
    private var apiKeySection: some View {
        Section(header: Text("OpenAI API Key")) {
            if hasStoredKey {
                Label("Key stored securely", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Button("Replace Key") { apiKeyInput = "" }
            }

            SecureField("sk-...", text: $apiKeyInput).textContentType(.password)
            Button("Save") { saveKey() }
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

            if !apiStatus.isEmpty {
                Text(apiStatus).font(.footnote).foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var preferencesSection: some View {
        ZStack {
            Section(header: Text("App Preferences")) {
                Toggle("Enable Notifications", isOn: .constant(false))
                Picker("GPT Tone", selection: $gptTone) {
                    Text("Wellness").tag("wellness")
                    Text("Scientific").tag("scientific")
                    Text("Friendly").tag("friendly")
                }
                .pickerStyle(.segmented)
            }
            .disabled(true)

            Color.black.opacity(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("Coming Soon")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section(header: Text("About")) {
            Text("Version 1.0.0")
            Link("Privacy Policy", destination: URL(string: "https://yourdomain.com/privacy")!)
        }
    }

    // ────────────────── Helpers ──────────────────
    private func refreshAuthStatus() {
        calendarGranted =
            EKEventStore.authorizationStatus(for: .event) == .authorized

        updateHealthGranted()
    }

    // Toggle callbacks
    private func calendarToggleChanged(_ newValue: Bool) {
        if newValue {
            CalendarDataPipeline.shared.requestAccess { calendarGranted = $0 }
        } else {
            // Permissions can only be revoked in the iOS Settings app. If the
            // user cancels the alert, keep the toggle enabled so the state
            // reflects the actual authorization status.
            showSettingsAlert = true
            calendarGranted = true
        }
    }

    private func healthToggleChanged(_ newValue: Bool) {
        if newValue {
            HealthDataPipeline.shared.requestAuthorization {
                healthGranted = $0
                updateHealthGranted()
            }
        } else {
            // Mirror the same revoke-flow behavior for Health permissions.
            showSettingsAlert = true
            healthGranted = true
        }
    }

    private func systemSettingsButtons() -> some View {
        Group {
            #if os(iOS)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            #endif
            Button("OK", role: .cancel) { }
        }
    }

    private func completeIfBothGranted() {
        if calendarGranted && healthGranted { didCompleteOnboarding = true }
    }

    private func saveKey() {
        do {
            try OpenAIManager.shared.storeAPIKey(apiKeyInput.trimmingCharacters(in: .whitespaces))
            apiStatus = "Saved ✔︎"
        } catch {
            apiStatus = "Failed: \(error.localizedDescription)"
        }
        apiKeyInput = ""
    }

    private func updateHealthGranted() {
        //  same read type as in HealthDataPipeline
        let readTypes: Set<HKObjectType> = [
            .quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            .quantityType(forIdentifier: .restingHeartRate)!,
            .quantityType(forIdentifier: .heartRate)!,
            .quantityType(forIdentifier: .activeEnergyBurned)!,
            .quantityType(forIdentifier: .stepCount)!
        ]

        HKHealthStore().getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, _ in
        
            DispatchQueue.main.async { healthGranted = (status == .unnecessary) }
        }
    }

}

struct OnboardingAndSettingsView_Previews: PreviewProvider {
    static var previews: some View { OnboardingAndSettingsView() }
}
