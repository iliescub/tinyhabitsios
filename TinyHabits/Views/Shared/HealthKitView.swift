//
//  HeathKitView.swift
//  TinyHabits
//
//  Created by Bogdan Iliescu on 26.11.2025.
//
import SwiftUI
import SwiftData

struct HealthKitView: View {
    
    @AppStorage("accentTheme") private var accentRaw: String = AccentTheme.blue.rawValue
    
    @State private var showingPermissionAlert = false
    @State private var stepCount: Int?
    @State private var heartRate: Double?
    @State private var sleepHours: Double?
    @State private var healthError: String?
    @State private var healthAuthResult: HealthAuthorizationResult?
    @State private var isRequestInProgress = false

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    
    private var accent: Color { AccentTheme(rawValue: accentRaw)?.color ?? .blue }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health snapshot")
                .font(.headline)
            
            HStack(spacing: 12) {
                healthMetric(title: "Steps today", value: stepCountString, detail: "From HealthKit")
                healthMetric(title: "Heart rate", value: heartRateString, detail: "Latest reading")
                healthMetric(title: "Sleep", value: sleepString, detail: "Last night")
            }
            
            if let message = healthMessageText {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
 //           healthActionButton()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
        )
        .onAppear {
//            seedReminderState()
            requestHealthData()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshHealthData()
            }
        }
    }
    
    private func healthMetric(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var stepCountString: String {
        if let steps = stepCount {
            return "\(steps)"
        }
        return "—"
    }

    private var heartRateString: String {
        if let bpm = heartRate {
            return String(format: "%.0f bpm", bpm)
        }
        return "—"
    }
    
    private var sleepString: String {
        if let hours = sleepHours {
            return String(format: "%.1f h", hours)
        }
        return "—"
    }

    private var healthMessageText: String? {
        if let error = healthError {
            return error
        }
        switch healthAuthResult {
        case .denied:
            return "Grant Health permissions to show daily progress."
        case .unavailable:
            return "Health data is unavailable on this device."
        default:
            return stepCount == nil && heartRate == nil ? "Authorize HealthKit to surface more insights." : nil
        }
    }

    @ViewBuilder
    private func healthActionButton() -> some View {
        if healthAuthResult == .denied {
            healthButton(title: "Open Settings") {
                openHealthSettings()
            }
        } else if healthAuthResult != .granted {
            healthButton(title: "Request access") {
                requestHealthData(force: true)
            }
        } else {
            healthButton(title: "Refresh data") {
                refreshHealthData()
            }
        }
    }

    private func healthButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(accent)
    }

    private func requestHealthData(force: Bool = false) {
        if !force && healthAuthResult == .granted {
            return
        }
        guard !isRequestInProgress else { return }
        isRequestInProgress = true
        healthError = nil
        
        HealthKitManager.shared.requestAuthorization { result in
            DispatchQueue.main.async {
                self.healthAuthResult = result
                self.isRequestInProgress = false
            }
            switch result {
            case .granted:
                fetchSteps()
                fetchHeartRate()
                fetchSleep()
            case .denied:
                DispatchQueue.main.async {
                    healthError = "Grant Health permissions to show daily progress."
                }
            case .unavailable:
                DispatchQueue.main.async {
                    healthError = "Health data is unavailable on this device."
                }
            }
        }
    }
    
        private func refreshHealthData() {
            healthError = nil
            fetchSteps()
            fetchHeartRate()
            fetchSleep()
        }
    
        private func fetchSteps() {
            HealthKitManager.shared.fetchTodayStepCount { value in
                DispatchQueue.main.async {
                    if let value = value {
                        stepCount = value
                    } else {
                        healthError = "Could not read today's steps."
                    }
                }
            }
        }
    
        private func fetchHeartRate() {
            HealthKitManager.shared.fetchLatestHeartRate { value in
                DispatchQueue.main.async {
                    if let value = value {
                        heartRate = value
                    } else {
                        healthError = "Could not read heart rate."
                    }
                }
            }
        }
    
        private func fetchSleep() {
            HealthKitManager.shared.fetchLastNightSleepHours { hours in
                DispatchQueue.main.async {
                    sleepHours = hours
                }
            }
        }
    
        private func openHealthSettings() {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        }
    
}
