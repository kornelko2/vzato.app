// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Observation
import SwiftUI

enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case today, history, medications, database, settings
    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .today: "Today"
        case .history: "History"
        case .medications: "Medications"
        case .database: "Medicines database"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .today: "sun.max"
        case .history: "calendar"
        case .medications: "pills"
        case .database: "books.vertical"
        case .settings: "gear"
        }
    }

    /// Sections shown in the sidebar / tab bar. The Mac has Settings in its own window.
    static var visible: [AppTab] {
        #if os(macOS)
        return [.today, .history, .medications]
        #else
        return [.today, .history, .medications, .settings]
        #endif
    }

    /// The sidebar on the iPad and the Mac also lists the medicines database; on the iPhone it is
    /// the search in Medications, without an extra tab.
    static var sidebar: [AppTab] {
        visible.flatMap { $0 == .medications ? [.medications, .database] : [$0] }
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
    /// Today and History show one profile's doses when set, everyone's when nil.
    var profileFilter: UUID?
}
