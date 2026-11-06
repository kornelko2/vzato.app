// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

@main
struct VzatoApp: App {
    private let persistence: PersistenceController
    @State private var state = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        persistence = PersistenceController.shared
        #if DEBUG
        // `--sample-data` fills an empty store with demo medications (simulator screenshots, UI work).
        if CommandLine.arguments.contains("--sample-data") {
            let request = Medication.fetchRequest()
            request.fetchLimit = 1
            if (try? persistence.viewContext.count(for: request)) == 0 {
                SampleData.populate(in: persistence.viewContext)
            }
        }
        #endif
        NotificationService.shared.configure(context: persistence.viewContext)
        SyncMonitor.shared.start(controller: persistence)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .environment(\.managedObjectContext, persistence.viewContext)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await NotificationService.shared.rescheduleAll() }
                    }
                }
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 720)
        #endif
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New medication") { state.showingNewMedication = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Log extra dose") { state.showingExtraDose = true }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandMenu(Text("Go")) {
                ForEach(Array(AppTab.visible.enumerated()), id: \.element) { index, tab in
                    Button { state.section = tab } label: { Text(tab.label) }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                }
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(\.managedObjectContext, persistence.viewContext)
                .frame(minWidth: 480, minHeight: 560)
        }
        #endif
    }
}
