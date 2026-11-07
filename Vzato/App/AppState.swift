// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Observation
import SwiftUI

enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case today, history, medications, settings
    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .today: "Today"
        case .history: "History"
        case .medications: "Medications"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .today: "sun.max"
        case .history: "calendar"
        case .medications: "pills"
        case .settings: "gear"
        }
    }

    /// Sections shown in the sidebar / tab bar. The Mac has Settings in its own window.
    static var visible: [AppTab] {
        #if os(macOS)
        return [.today, .history, .medications]
        #else
        return allCases
        #endif
    }
}

/// Navigation and command state shared between the window, the sidebar and the Mac menu bar.
@MainActor
@Observable
final class AppState {
    var section: AppTab = AppTab(rawValue: LaunchArguments.initialTab ?? "") ?? .today
    var showingNewMedication = false
    var showingExtraDose = false
    var showingOnboarding = false
}
