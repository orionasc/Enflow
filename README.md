# EnFlow

EnFlow is an energy forecasting app that blends HealthKit metrics, calendar context and OpenAI-driven insights. The goal is to give users a quick picture of their upcoming energy levels with actionable tips for each day.

## Build & Run

1. Open `EnFlow.xcodeproj` in the latest Xcode (iOS deployment target 18.5).
2. Xcode will automatically resolve Swift Package Manager dependencies (`OpenAISwift` and `SwiftDate`). If packages fail to resolve, choose **File → Packages → Resolve Package Versions**.
3. Select the *EnFlow* scheme and run on an iOS simulator or device.

## OpenAI API Key

The app requires an OpenAI API key for GPT features. In the app:

1. Open the Settings screen from the gear icon.
2. Under **OpenAI API Key**, paste your key and tap **Save**. The key is stored securely in the keychain.
3. You can replace it at any time by tapping **Replace Key**.

Keychain helper logic lives in `Settings/KeychainHelper.swift` and stores values using the `com.enflow.keys` service.

## Required Permissions

EnFlow uses your calendar and Health data:

- Grant Calendar access so events can be aligned with energy forecasts.
- Grant Health access so metrics like HRV, resting heart rate and sleep data can be read. The project’s Info.plist explains why these permissions are needed.

You can grant permissions during onboarding or later from the Settings screen.

## Editing Your User Profile

From the **User** tab you can view your saved habits and tap **Edit Profile** to update them. The quiz collects sleep, caffeine and activity routines. Your answers are stored locally in `UserProfile.json` and influence energy forecasts. Revisit the quiz anytime to keep recommendations fresh.

The profile records your daily caffeine intake in milligrams. As a reminder, a cup of coffee is roughly 95&nbsp;mg of caffeine while an iced tea is around 45&nbsp;mg. Use the toggles to indicate if you typically consume caffeine in the morning, afternoon or evening. You can also open the **Data** page from the User tab to browse your recent HealthKit samples and calendar events. A switch on that screen lets you use simulated health data for testing.

## Testing & Troubleshooting

- Run unit and UI tests from Xcode with **⌘U** or via `xcodebuild test`.
- If builds fail, ensure packages are resolved and that you have a recent Xcode matching the deployment target.
- If API responses are empty, verify that your OpenAI key is valid and that the device has network connectivity.
- Permissions can be revoked only from the iOS Settings app. If data appears missing, re‑check Calendar and Health permissions there.

