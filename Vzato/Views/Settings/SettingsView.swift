// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AudioToolbox
import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system
    @AppStorage(AppSettings.snoozeMinutesKey) private var snoozeMinutes = AppSettings.defaultSnoozeMinutes
    @AppStorage(AppSettings.missedAfterMinutesKey) private var missedAfterMinutes = AppSettings.defaultMissedAfterMinutes
    @AppStorage(AppSettings.lowStockNotificationsKey) private var lowStockNotifications = true
    @AppStorage(AppSettings.repeatCountKey) private var repeatCount = AppSettings.defaultRepeatCount
    @AppStorage(AppSettings.runOutWarningDaysKey) private var runOutWarningDays = AppSettings.defaultRunOutWarningDays
    @AppStorage(AppSettings.appIconKey) private var appIcon = AppIcon.pill
    @AppStorage(AppSettings.doseSoundKey) private var doseSound = ReminderSound.chime
    @AppStorage(AppSettings.mealSoundKey) private var mealSound = ReminderSound.soft

    @Environment(AppState.self) private var state
    private var notifications: NotificationService { NotificationService.shared }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ProfilesView()
                    } label: {
                        Label("Profiles", systemImage: "person.2")
                    }
                    .accessibilityIdentifier("profiles")
                } footer: {
                    Text("Medications for your children or animals.")
                }

                Section {
                    MedicineSourceNote()
                } header: {
                    Text("Medicines database")
                }

                Section {
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                    .accessibilityIdentifier("help")
                    Button {
                        state.showingOnboarding = true
                    } label: {
                        Label("Show the introduction again", systemImage: "arrow.counterclockwise.circle")
                    }
                } header: {
                    Text("Help")
                }

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
                    iconPicker
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
                    .onChange(of: missedAfterMinutes) {
                        AppSettings.shareWithWidgets()
                        WidgetBridge.shared.reloadNow()
                    }
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
                    soundPicker(Text("Medication reminders"), options: ReminderSound.forDoses, selection: $doseSound)
                    soundPicker(Text("\u{201E}You can eat now\u{201C}"), options: ReminderSound.forMeals, selection: $mealSound)
                } header: {
                    Text("Sounds")
                } footer: {
                    Text("Different sounds tell you at a glance whether it is time for a medication or time to eat.")
                }
                .onChange(of: doseSound) {
                    AppSettings.shareWithWidgets()
                    SoundPreview.play(doseSound)
                    Task { await notifications.rescheduleAll() }
                }
                .onChange(of: mealSound) {
                    AppSettings.shareWithWidgets()
                    SoundPreview.play(mealSound)
                }

                Section {
                    NavigationLink {
                        ActivityLogView()
                    } label: {
                        Label("Activity log", systemImage: "list.bullet.rectangle")
                    }
                } header: {
                    Text("Activity")
                } footer: {
                    Text("Who recorded what and when, on which device.")
                }

                Section {
                    syncStatus
                } header: {
                    Text("iCloud sync")
                } footer: {
                    Text("Syncs between your own devices through your iCloud account. Nobody else, not even the developer, can read the data.")
                }

                Section {
                    Text("Every feature is free for everyone, including the source code. No ads, no account, no paid version.")
                    Text("I look after Vzato mainly for myself. Any comment or idea is welcome.")
                        .foregroundStyle(.secondary)
                    if let mail = URL(string: "mailto:info@vzato.app") {
                        Link(destination: mail) {
                            Label("Write to us: info@vzato.app", systemImage: "envelope")
                        }
                    }
                    if let site = URL(string: "https://vzato.app") {
                        Link(destination: site) {
                            Label {
                                Text(verbatim: "vzato.app")
                            } icon: {
                                Image(systemName: "globe")
                            }
                        }
                    }
                } header: {
                    Text("Free for everyone")
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

    private func soundPicker(_ title: Text, options: [ReminderSound], selection: Binding<ReminderSound>) -> some View {
        HStack {
            Picker(selection: selection) {
                ForEach(options) { sound in
                    Text(sound.label).tag(sound)
                }
            } label: {
                title
            }
            Button {
                SoundPreview.play(selection.wrappedValue)
            } label: {
                Image(systemName: "play.circle")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .disabled(selection.wrappedValue.fileName == nil)
            .accessibilityLabel(Text("Play"))
        }
    }

    /// Pill or organizer. On iOS this swaps the home-screen icon, on the Mac the Dock icon.
    private var iconPicker: some View {
        HStack(spacing: 20) {
            ForEach(AppIcon.allCases) { icon in
                Button {
                    appIcon = icon
                } label: {
                    VStack(spacing: 6) {
                        Image(icon.previewAssetName)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(appIcon == icon ? Color.accentColor : .clear, lineWidth: 3))
                        Text(icon.label).font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(icon.label))
                .accessibilityAddTraits(appIcon == icon ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .onChange(of: appIcon) { _, icon in icon.apply() }
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
    SettingsView().environment(AppState())
}

/// Plays a notification sound in Settings so the choice can be heard.
@MainActor
enum SoundPreview {
    private static var ids: [String: SystemSoundID] = [:]

    static func play(_ sound: ReminderSound) {
        guard let fileName = sound.fileName else { return }
        if let id = ids[fileName] {
            AudioServicesPlaySystemSound(id)
            return
        }
        let name = (fileName as NSString).deletingPathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else { return }
        var id: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError else { return }
        ids[fileName] = id
        AudioServicesPlaySystemSound(id)
    }
}
