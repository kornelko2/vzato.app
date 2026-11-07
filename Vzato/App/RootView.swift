// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// Tabs on the iPhone, a sidebar split view on the iPad and the Mac.
struct RootView: View {
    @Environment(AppState.self) private var state
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system
    @AppStorage(AppSettings.onboardingCompletedKey) private var onboardingCompleted = false
    @Environment(\.managedObjectContext) private var context
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
        #if os(iOS)
        .preferredColorScheme(appearance.colorScheme)
        #else
        .onChange(of: appearance) { _, value in value.apply() }
        #endif
        .sheet(isPresented: $state.showingNewMedication) {
            MedicationFormView(medication: nil)
        }
        .sheet(isPresented: $state.showingExtraDose) {
            ExtraDoseView()
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $state.showingOnboarding) { onboarding }
        #else
        .sheet(isPresented: $state.showingOnboarding) { onboarding }
        #endif
        .onAppear(perform: decideOnboarding)
    }

    private var onboarding: some View {
        OnboardingView {
            onboardingCompleted = true
            state.showingOnboarding = false
            state.section = .today
        }
        .environment(\.managedObjectContext, context)
    }

    /// The guide is for a first start: nobody who already has medications (an update, or data
    /// from iCloud) sees it unasked. Settings › Help can start it again.
    private func decideOnboarding() {
        if let forced = LaunchArguments.onboardingOverride {
            state.showingOnboarding = forced
            return
        }
        guard !onboardingCompleted else { return }
        let request = Medication.fetchRequest()
        request.fetchLimit = 1
        if (try? context.count(for: request)) ?? 0 > 0 {
            onboardingCompleted = true
        } else {
            state.showingOnboarding = true
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
            .safeAreaInset(edge: .bottom) {
                // The Mac keeps Settings in its own window (Vzato › Settings…, ⌘,); this makes it findable.
                SettingsLink {
                    Label("Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
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
