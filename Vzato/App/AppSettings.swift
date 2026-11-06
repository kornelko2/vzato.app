// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// UserDefaults keys and defaults shared by views (@AppStorage) and services.
enum AppSettings {
    static let appearanceKey = "appearance"
    static let snoozeMinutesKey = "snoozeMinutes"
    static let missedAfterMinutesKey = "missedAfterMinutes"
    static let lowStockNotificationsKey = "lowStockNotifications"

    static let defaultSnoozeMinutes = 10
    static let defaultMissedAfterMinutes = 120

    static var snoozeMinutes: Int {
        let value = UserDefaults.standard.integer(forKey: snoozeMinutesKey)
        return value > 0 ? value : defaultSnoozeMinutes
    }

    static var missedAfterMinutes: Int {
        let value = UserDefaults.standard.integer(forKey: missedAfterMinutesKey)
        return value > 0 ? value : defaultMissedAfterMinutes
    }

    static var missedAfterInterval: TimeInterval { TimeInterval(missedAfterMinutes * 60) }

    static var lowStockNotificationsEnabled: Bool {
        guard UserDefaults.standard.object(forKey: lowStockNotificationsKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: lowStockNotificationsKey)
    }
}
