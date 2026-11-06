// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// Tabs on the iPhone, a sidebar split view on the iPad and the Mac.
struct RootView: View {
    @Environment(AppState.self) private var state
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var useSidebar: Bool {
        #if os(macOS)
        return true
        #else
        return sizeClass == .regular
        #endif
    }

    var body: some View {
        @Bindable var state = state
        Group {
            if useSidebar {
                sidebarLayout
            } else {
                tabLayout
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .sheet(isPresented: $state.showingNewMedication) {
            MedicationFormView(medication: nil)
        }
        .sheet(isPresented: $state.showingExtraDose) {
            ExtraDoseView()
        }
    }

    private var tabLayout: some View {
        @Bindable var state = state
        return TabView(selection: $state.section) {
            ForEach(AppTab.visible) { tab in
                content(for: tab)
                    .tabItem { Label(tab.label, systemImage: tab.symbolName) }
                    .tag(tab)
            }
        }
    }

    private var sidebarLayout: some View {
        @Bindable var state = state
        return NavigationSplitView {
            List(AppTab.visible, selection: Binding(get: { Optional(state.section) }, set: { state.section = $0 ?? .today })) { tab in
                Label(tab.label, systemImage: tab.symbolName)
                    .tag(tab)
            }
            .navigationTitle(Text(verbatim: "Vzato"))
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
            #endif
        } detail: {
            content(for: state.section)
        }
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .today: TodayView()
        case .history: HistoryView()
        case .medications: MedicationsView()
        case .settings: SettingsView()
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
