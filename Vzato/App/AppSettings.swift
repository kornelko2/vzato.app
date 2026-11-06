// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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

    static var stored: Appearance {
        Appearance(rawValue: UserDefaults.standard.string(forKey: AppSettings.appearanceKey) ?? "") ?? .system
    }

    /// macOS: set the application appearance so every window (main and Settings) matches.
    /// iOS uses `preferredColorScheme` on the root view instead.
    @MainActor
    func apply() {
        #if os(macOS)
        switch self {
        case .system: NSApplication.shared.appearance = nil
        case .light: NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case .dark: NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
        #endif
    }
}

/// UserDefaults keys and defaults shared by views (@AppStorage) and services.
enum AppSettings {
    static let appearanceKey = "appearance"
    static let snoozeMinutesKey = "snoozeMinutes"
    static let missedAfterMinutesKey = "missedAfterMinutes"
    static let lowStockNotificationsKey = "lowStockNotifications"
    static let repeatCountKey = "repeatCount"
    static let runOutWarningDaysKey = "runOutWarningDays"
    static let appIconKey = "appIcon"

    static let defaultSnoozeMinutes = 10
    static let defaultMissedAfterMinutes = 120
    static let defaultRepeatCount = 2
    static let defaultRunOutWarningDays = 7

    static var snoozeMinutes: Int {
        let value = UserDefaults.standard.integer(forKey: snoozeMinutesKey)
        return value > 0 ? value : defaultSnoozeMinutes
    }

    static var missedAfterMinutes: Int {
        let value = UserDefaults.standard.integer(forKey: missedAfterMinutesKey)
        return value > 0 ? value : defaultMissedAfterMinutes
    }

    static var missedAfterInterval: TimeInterval { TimeInterval(missedAfterMinutes * 60) }

    /// Follow-up reminders after an unconfirmed dose (0 = off).
    static var repeatCount: Int {
        guard UserDefaults.standard.object(forKey: repeatCountKey) != nil else { return defaultRepeatCount }
        return max(0, min(3, UserDefaults.standard.integer(forKey: repeatCountKey)))
    }

    /// Days before the projected run-out date to warn (0 = off).
    static var runOutWarningDays: Int {
        guard UserDefaults.standard.object(forKey: runOutWarningDaysKey) != nil else { return defaultRunOutWarningDays }
        return max(0, min(30, UserDefaults.standard.integer(forKey: runOutWarningDaysKey)))
    }

    static var lowStockNotificationsEnabled: Bool {
        guard UserDefaults.standard.object(forKey: lowStockNotificationsKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: lowStockNotificationsKey)
    }
}

/// Debug-only launch arguments used for simulator screenshots and UI work.
enum LaunchArguments {
    static var initialTab: String? {
        #if DEBUG
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--tab"), index + 1 < args.count else { return nil }
        return args[index + 1]
        #else
        return nil
        #endif
    }

    static var opensFirstMedication: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--open-first-medication")
        #else
        return false
        #endif
    }
}

/// Home screen icon. The organizer variant is an alternate icon on iOS; the Mac always shows the pill.
enum AppIcon: String, CaseIterable, Identifiable {
    case pill, organizer
    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .pill: "Pill"
        case .organizer: "Organizer"
        }
    }

    var previewAssetName: String {
        switch self {
        case .pill: "IconPreviewPill"
        case .organizer: "IconPreviewOrganizer"
        }
    }

    /// nil means the primary icon.
    var alternateIconName: String? {
        switch self {
        case .pill: nil
        case .organizer: "AppIcon-Organizer"
        }
    }

    static var stored: AppIcon {
        AppIcon(rawValue: UserDefaults.standard.string(forKey: AppSettings.appIconKey) ?? "") ?? .pill
    }

    /// Applies the choice. iOS swaps the home-screen icon; macOS swaps the Dock icon of the
    /// running app (Finder keeps the bundled icon, which the app may not rewrite).
    @MainActor
    func apply() {
        #if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != alternateIconName else { return }
        UIApplication.shared.setAlternateIconName(alternateIconName)
        #elseif os(macOS)
        switch self {
        case .pill: NSApplication.shared.applicationIconImage = nil
        case .organizer: NSApplication.shared.applicationIconImage = NSImage(named: "IconDockOrganizer")
        }
        #endif
    }
}
