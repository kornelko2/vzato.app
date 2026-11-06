// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system
    @AppStorage(AppSettings.snoozeMinutesKey) private var snoozeMinutes = AppSettings.defaultSnoozeMinutes
    @AppStorage(AppSettings.missedAfterMinutesKey) private var missedAfterMinutes = AppSettings.defaultMissedAfterMinutes
    @AppStorage(AppSettings.lowStockNotificationsKey) private var lowStockNotifications = true
    @AppStorage(AppSettings.repeatCountKey) private var repeatCount = AppSettings.defaultRepeatCount
    @AppStorage(AppSettings.runOutWarningDaysKey) private var runOutWarningDays = AppSettings.defaultRunOutWarningDays

    private var notifications: NotificationService { NotificationService.shared }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Vzato follows the language you set for it in the system settings. Czech, Slovak, English and Hungarian are available.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    #if os(iOS)
                    Button("Open system settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    #else
                    Text("Change it in System Settings › General › Language & Region › Applications.")
                        .font(.subheadline)
                    #endif
                } header: {
                    Text("Language")
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    notificationStatus
                    Stepper(value: $snoozeMinutes, in: 5...60, step: 5) {
                        LabeledContent("Snooze") { Text("\(snoozeMinutes) min") }
                    }
                    Stepper(value: $missedAfterMinutes, in: 30...360, step: 30) {
                        LabeledContent("Mark as missed after") { Text("\(missedAfterMinutes) min") }
                    }
                    Stepper(value: $repeatCount, in: 0...3) {
                        LabeledContent("Repeat unconfirmed reminders") {
                            if repeatCount == 0 { Text("Off") } else { Text("\(repeatCount)×") }
                        }
                    }
                    Toggle("Low supply alerts", isOn: $lowStockNotifications)
                    Stepper(value: $runOutWarningDays, in: 0...30) {
                        LabeledContent("Warn before running out") {
                            if runOutWarningDays == 0 { Text("Off") } else { Text("\(runOutWarningDays) days") }
                        }
                    }
                    .disabled(!lowStockNotifications)
                    Button("Refresh reminders") {
                        Task { await notifications.rescheduleAll() }
                    }
                    .onChange(of: repeatCount) { Task { await notifications.rescheduleAll() } }
                    .onChange(of: runOutWarningDays) { Task { await notifications.rescheduleAll() } }
                    .onChange(of: snoozeMinutes) { Task { await notifications.rescheduleAll() } }
                } header: {
                    Text("Reminders")
                } footer: {
                    if notifications.hitLimit {
                        Text("iOS allows at most 64 scheduled reminders. Some times were not scheduled.")
                    } else {
                        Text("Scheduled reminders: \(notifications.scheduledCount)")
                    }
                }

                Section {
                    syncStatus
                } header: {
                    Text("iCloud sync")
                } footer: {
                    Text("Syncs between your own devices through your iCloud account. Nobody else, not even the developer, can read the data.")
                }

                Section("About") {
                    LabeledContent("Version") {
                        Text(verbatim: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    }
                    Text("Vzato is not a medical device and does not replace your doctor or pharmacist. It only reminds you and keeps your own notes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Your data stays on this device and in your iCloud. Nothing is collected.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("Source code and license (MPL-2.0)", destination: URL(string: "https://github.com/kornelko2/vzato.app")!)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(Text("Settings"))
            .task { await notifications.refreshAuthorizationStatus() }
        }
    }

    @ViewBuilder
    private var syncStatus: some View {
        let monitor = SyncMonitor.shared
        if !monitor.isEnabled {
            Label("Not available in this build.", systemImage: "icloud.slash")
                .foregroundStyle(.secondary)
        } else if let error = monitor.lastError {
            VStack(alignment: .leading, spacing: 4) {
                Label("Sync error", systemImage: "exclamationmark.icloud")
                    .foregroundStyle(Palette.missed)
                Text(error).font(.caption).foregroundStyle(.secondary)
            }
        } else if let last = monitor.lastSuccess {
            LabeledContent {
                Text(last, format: .dateTime.hour().minute())
            } label: {
                Label("Last sync", systemImage: "checkmark.icloud")
            }
        } else {
            Label("Waiting for the first sync", systemImage: "arrow.triangle.2.circlepath.icloud")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var notificationStatus: some View {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            Label("Notifications are allowed", systemImage: "bell.badge")
        case .denied:
            VStack(alignment: .leading, spacing: 4) {
                Label("Notifications are turned off", systemImage: "bell.slash")
                    .foregroundStyle(Palette.missed)
                Text("Turn them on in the system settings to get reminders.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        default:
            Button {
                Task { await notifications.requestAuthorization() }
            } label: {
                Label("Allow notifications", systemImage: "bell")
            }
        }
    }
}

#Preview {
    SettingsView()
}
