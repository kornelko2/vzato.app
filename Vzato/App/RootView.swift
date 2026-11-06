// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct RootView: View {
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }
            MedicationsView()
                .tabItem { Label("Medications", systemImage: "pills") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .preferredColorScheme(appearance.colorScheme)
    }
}

#Preview {
    RootView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
