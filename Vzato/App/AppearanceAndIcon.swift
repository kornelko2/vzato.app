// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// App-only: uses UIApplication / NSApplication, which app extensions may not touch.

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

/// Home screen icon: pill (primary) or organizer (alternate on iOS, Dock image on the Mac).
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
