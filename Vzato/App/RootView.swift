// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

enum AppTab: String, Hashable {
    case today, history, medications, settings
}

struct RootView: View {
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system
    @State private var selectedTab = AppTab(rawValue: LaunchArguments.initialTab ?? "") ?? .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(AppTab.today)
            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }
                .tag(AppTab.history)
            MedicationsView()
                .tabItem { Label("Medications", systemImage: "pills") }
                .tag(AppTab.medications)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppTab.settings)
        }
        .preferredColorScheme(appearance.colorScheme)
    }
}

#Preview {
    RootView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
