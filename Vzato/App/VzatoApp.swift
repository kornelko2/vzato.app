// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct VzatoApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    private let persistence: PersistenceController
    @State private var state = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        persistence = PersistenceController.shared
        // Without the store nothing may run: a reminder rebuild would see no medications and
        // remove every scheduled reminder. The ones already scheduled keep working.
        guard persistence.isStoreLoaded else { return }
        #if DEBUG
        if LaunchArguments.resetsData {
            let context = persistence.viewContext
            for entity in ["DoseEvent", "MedicationPhoto", "Schedule", "Medication", "ActivityEntry"] {
                let request = NSFetchRequest<NSManagedObject>(entityName: entity)
                (try? context.fetch(request))?.forEach(context.delete)
            }
            try? context.save()
        }
        // `--sample-data` fills an empty store with demo medications (simulator screenshots, UI work).
        if CommandLine.arguments.contains("--sample-data") {
            let request = Medication.fetchRequest()
            request.fetchLimit = 1
            if (try? persistence.viewContext.count(for: request)) == 0 {
                SampleData.populate(in: persistence.viewContext,
                                    withProfiles: CommandLine.arguments.contains("--sample-profiles"))
            }
            // `--sample-organizer`: a 7 × 4 pill organizer for the default profile.
            if CommandLine.arguments.contains("--sample-organizer"), let profile = Profile.defaultProfile(in: persistence.viewContext) {
                let organizer = OrganizerService.organizer(for: profile, in: persistence.viewContext)
                organizer.layout = .week4
                organizer.isEnabled = true
                try? persistence.viewContext.save()
            }
        }
        #endif
        if LaunchArguments.usesScratchStore {
            // Only read the permission, so Today shows the same state as the real app.
            Task { await NotificationService.shared.refreshAuthorizationStatus() }
        } else {
            NotificationService.shared.configure(context: persistence.viewContext)
        }
        SyncMonitor.shared.start(controller: persistence)
        persistence.startMergingExternalChanges()
        DuplicateResolver.resolve(in: persistence.viewContext)
        WidgetBridge.shared.start(context: persistence.viewContext)
        AppSettings.shareWithWidgets()
        AppIcon.stored.apply()
        Appearance.stored.apply()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if persistence.isStoreLoaded {
                    RootView()
                } else {
                    StoreErrorView(message: persistence.loadErrorDescription ?? "")
                }
            }
                .environment(state)
                .environment(\.managedObjectContext, persistence.viewContext)
                #if os(macOS)
                .onAppear {
                    guard let size = LaunchArguments.windowSize else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.styleMask.contains(.titled) }) else { return }
                        let screen = window.screen?.visibleFrame ?? .zero
                        window.setFrame(NSRect(x: screen.minX + 40, y: screen.maxY - size.height - 40, width: size.width, height: size.height), display: true)
                    }
                }
                #endif
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        guard persistence.isStoreLoaded else { break }
                        persistence.mergeExternalChanges()
                        Task { await NotificationService.shared.rescheduleAll() }
                    case .background:
                        WidgetBridge.shared.reloadNow()
                        SyncMonitor.shared.keepRunningWhileSyncing()
                        #if os(iOS)
                        BackgroundRefresh.schedule()
                        #endif
                    default:
                        break
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
                ForEach(Array(AppTab.sidebar.enumerated()), id: \.element) { index, tab in
                    Button { state.section = tab } label: { Text(tab.label) }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                }
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(state)
                .environment(\.managedObjectContext, persistence.viewContext)
                .frame(minWidth: 480, minHeight: 560)
        }
        #endif
    }
}

#if os(iOS)
/// Registers the daily background refresh and, for silent pushes from iCloud, holds background time while CloudKit imports the changes,
/// so iOS does not suspend the app with the store file locked.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BackgroundRefresh.register()
        return true
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        await SyncMonitor.shared.waitForRemoteChanges()
        return .newData
    }
}
#endif
