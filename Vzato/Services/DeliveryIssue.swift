// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UserNotifications

/// A system setting that keeps reminders quiet although notifications are allowed. The app cannot
/// change these; Settings lists them with a link to the system's notification settings.
enum DeliveryIssue: String, Sendable, CaseIterable, Identifiable {
    /// "Time Sensitive Notifications" is off for Vzato: reminders wait behind Focus and Do Not Disturb.
    case timeSensitiveOff
    /// Banners and alerts are off: reminders only land in Notification Center.
    case alertsOff
    /// Not shown on the lock screen: a locked phone shows nothing.
    case lockScreenOff
    /// Sounds are off for Vzato.
    case soundOff

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .timeSensitiveOff: "Time Sensitive notifications are off"
        case .alertsOff: "Banners are off"
        case .lockScreenOff: "Reminders are hidden on the lock screen"
        case .soundOff: "Reminder sounds are off"
        }
    }

    var explanation: LocalizedStringResource {
        switch self {
        case .timeSensitiveOff: "Reminders stay silent during Focus and Do Not Disturb. Turn on Time Sensitive Notifications for Vzato in the system settings."
        case .alertsOff: "Reminders only appear in Notification Center. Turn on banners for Vzato in the system settings."
        case .lockScreenOff: "A locked phone shows no reminder. Turn on Lock Screen for Vzato in the system settings."
        case .soundOff: "Reminders arrive without a sound. Turn on Sounds for Vzato in the system settings."
        }
    }

    nonisolated static func issues(in settings: UNNotificationSettings) -> [DeliveryIssue] {
        issues(authorization: settings.authorizationStatus, alert: settings.alertSetting, lockScreen: settings.lockScreenSetting,
               sound: settings.soundSetting, timeSensitive: settings.timeSensitiveSetting,
               wantsTimeSensitive: AppSettings.breaksThroughFocus)
    }

    /// Only settings the person switched off count; `.notSupported` (no entitlement, older system)
    /// is not their doing. Nothing is reported while notifications are not allowed at all: Settings
    /// shows that on its own.
    nonisolated static func issues(authorization: UNAuthorizationStatus, alert: UNNotificationSetting,
                                   lockScreen: UNNotificationSetting, sound: UNNotificationSetting,
                                   timeSensitive: UNNotificationSetting, wantsTimeSensitive: Bool) -> [DeliveryIssue] {
        guard authorization != .denied, authorization != .notDetermined else { return [] }
        var result: [DeliveryIssue] = []
        if wantsTimeSensitive, timeSensitive == .disabled { result.append(.timeSensitiveOff) }
        if alert == .disabled { result.append(.alertsOff) }
        if lockScreen == .disabled { result.append(.lockScreenOff) }
        if sound == .disabled { result.append(.soundOff) }
        return result
    }
}
