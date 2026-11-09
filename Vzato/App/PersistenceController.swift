// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

/// Owns the Core Data stack. iCloud sync is a build-time opt-in (`VzatoCloudKit` in Info.plist,
/// set from `VZATO_CLOUDKIT` in Config/Local.xcconfig); without it the store is local only.
/// The store lives in the App Group container so the widget extension opens the same file;
/// the widget never syncs, the app exports its changes to CloudKit through persistent history.
@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        SampleData.populate(in: controller.viewContext)
        return controller
    }()

    /// Loaded once: several containers (app, tests, previews) sharing one model avoids Core Data's
    /// "failed to find a unique match for an NSEntityDescription" warning.
    static let model: NSManagedObjectModel = {
        guard let url = Bundle(for: PersistenceController.self).url(forResource: "Vzato", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Missing Core Data model")
        }
        return model
    }()

    static let cloudKitContainerIdentifier = "iCloud.app.vzato"

    /// True when this build was made with `VZATO_CLOUDKIT = YES` and the iCloud entitlements.
    nonisolated static var isCloudKitBuild: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "VzatoCloudKit") as? String)?.uppercased() == "YES"
    }

    let container: NSPersistentCloudKitContainer
    let isCloudKitEnabled: Bool
    /// False only in the widget when the store could not be opened (for example while the app is
    /// still migrating it after an update). The widget then shows its empty state.
    private(set) var isStoreLoaded = true
    var viewContext: NSManagedObjectContext { container.viewContext }

    /// `Vzato.sqlite` in the App Group container, or nil when the entitlement is missing.
    nonisolated static var sharedStoreURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppSettings.appGroupIdentifier)?
            .appendingPathComponent("Vzato.sqlite")
    }

    private var historyObserver: (any NSObjectProtocol)?
    private static let historyTokenKey = "persistentHistoryToken"

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Vzato", managedObjectModel: Self.model)
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store description")
        }
        let scratch = !inMemory && !AppSettings.isAppExtension && LaunchArguments.usesScratchStore
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else if scratch {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("VzatoScratch", isDirectory: true)
            try? FileManager.default.removeItem(at: folder)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            description.url = folder.appendingPathComponent("Vzato.sqlite")
        } else if let shared = Self.sharedStoreURL,
                  Self.moveLegacyStore(to: shared, coordinator: container.persistentStoreCoordinator) {
            description.url = shared
        }
        // The widget reads and writes the same file but never talks to CloudKit itself.
        isCloudKitEnabled = !inMemory && (!scratch || LaunchArguments.initsCloudKitSchema)
            && Self.isCloudKitBuild && !AppSettings.isAppExtension
        if isCloudKitEnabled {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudKitContainerIdentifier)
        } else {
            description.cloudKitContainerOptions = nil
        }
        // History tracking and remote change notifications are what CloudKit sync builds on; harmless locally.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        // Only the app migrates the store to a new model version. If the widget migrated too, both
        // processes could upgrade the same file at once after an update and one of them would fail.
        let migrates = !AppSettings.isAppExtension
        description.shouldMigrateStoreAutomatically = migrates
        description.shouldInferMappingModelAutomatically = migrates

        var loadError: (any Error)?
        container.loadPersistentStores { _, error in loadError = error }
        if loadError != nil, !inMemory, !AppSettings.isAppExtension {
            // The widget may have held the file at the same moment; try once more.
            Thread.sleep(forTimeInterval: 0.5)
            loadError = nil
            container.loadPersistentStores { _, error in loadError = error }
        }
        if let loadError {
            guard AppSettings.isAppExtension else { fatalError("Could not load the data store: \(loadError)") }
            print("Vzato widget: store not available yet: \(loadError)")
            isStoreLoaded = false
        }
        #if DEBUG
        // `--init-cloudkit-schema` pushes the model to the CloudKit development environment once.
        if isCloudKitEnabled, LaunchArguments.initsCloudKitSchema {
            // Off the main thread: CloudKit's setup needs the main thread while this call waits.
            let container = container
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try container.initializeCloudKitSchema(options: [])
                    NSLog("CloudKit schema: uploaded to the development environment")
                } catch {
                    NSLog("CloudKit schema: %@", String(describing: error))
                }
            }
        }
        #endif
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.transactionAuthor = AppSettings.isAppExtension ? "widget" : "app"
        if isStoreLoaded { ensureDefaultProfile() }
    }

    /// Builds before the widget kept the store in the app's own container. Copy it over once.
    /// Returns false when the shared location cannot be used; the app then keeps the old store
    /// (the widget shows nothing, but no data is lost and the app keeps working).
    private static func moveLegacyStore(to shared: URL, coordinator: NSPersistentStoreCoordinator) -> Bool {
        let legacy = NSPersistentCloudKitContainer.defaultDirectoryURL().appendingPathComponent("Vzato.sqlite")
        let files = FileManager.default
        guard legacy != shared, files.fileExists(atPath: legacy.path), !files.fileExists(atPath: shared.path) else { return true }
        let options: [String: Any] = [NSPersistentHistoryTrackingKey: true as NSNumber]
        do {
            try coordinator.replacePersistentStore(at: shared, destinationOptions: options,
                                                   withPersistentStoreFrom: legacy, sourceOptions: options, type: .sqlite)
            try coordinator.destroyPersistentStore(at: legacy, type: .sqlite, options: options)
            return true
        } catch {
            print("Vzato: moving the store to the App Group failed, keeping the old location: \(error)")
            return false
        }
    }

    // MARK: Changes from other processes (widget)

    /// The app merges what the widget wrote. Core Data posts a remote-change notification for writes
    /// from other processes; persistent history says what changed.
    func startMergingExternalChanges() {
        guard historyObserver == nil else { return }
        if loadHistoryToken() == nil {
            saveHistoryToken(container.persistentStoreCoordinator.currentPersistentHistoryToken(fromStores: nil))
        }
        historyObserver = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange,
                                                                 object: container.persistentStoreCoordinator,
                                                                 queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.mergeExternalChanges() }
        }
    }

    func mergeExternalChanges() {
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: loadHistoryToken())
        guard let result = try? viewContext.execute(request) as? NSPersistentHistoryResult,
              let transactions = result.result as? [NSPersistentHistoryTransaction],
              !transactions.isEmpty else { return }
        let ownAuthor = viewContext.transactionAuthor
        var foreign = 0
        for transaction in transactions where transaction.author != ownAuthor {
            viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
            foreign += 1
        }
        saveHistoryToken(transactions.last?.token)
        // Changes from another device or the widget may duplicate a dose recorded here.
        if foreign > 0 { DuplicateResolver.resolve(in: viewContext) }
    }

    private func loadHistoryToken() -> NSPersistentHistoryToken? {
        guard let data = UserDefaults.standard.data(forKey: Self.historyTokenKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: data)
    }

    private func saveHistoryToken(_ token: NSPersistentHistoryToken?) {
        guard let token, let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyTokenKey)
    }

    /// Phase 1 shows a single profile; the entity exists so profiles can be added later without migration.
    @discardableResult
    func ensureDefaultProfile() -> Profile {
        let request = Profile.fetchRequest()
        request.predicate = NSPredicate(format: "isDefault == YES")
        request.fetchLimit = 1
        if let existing = try? viewContext.fetch(request).first {
            return existing
        }
        let profile = Profile(context: viewContext)
        profile.name = String(localized: "Me")
        profile.isDefault = true
        profile.kind = .person
        save()
        return profile
    }

    func save() {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
            assertionFailure("Save failed: \(error)")
        }
    }
}

enum SampleData {
    /// Demo content for simulator screenshots and previews. Times are relative to now so the Today
    /// screen always shows one taken dose, one overdue dose and upcoming ones.
    @MainActor
    static func populate(in context: NSManagedObjectContext, now: Date = Date(), withProfiles: Bool = false) {
        let calendar = Calendar.current
        let profileRequest = Profile.fetchRequest()
        profileRequest.predicate = NSPredicate(format: "isDefault == YES")
        let profile = (try? context.fetch(profileRequest).first) ?? {
            let profile = Profile(context: context)
            profile.name = "Me"
            profile.isDefault = true
            return profile
        }()
        let minutesNow = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        func clamp(_ minutes: Int) -> Int { min(max(minutes, 0), 23 * 60 + 59) }
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: now)

        func make(_ name: String, _ dosage: String, _ hex: String, times: [Int], meal: MealRelation = .any) -> Medication {
            let medication = Medication(context: context)
            medication.createdAt = monthAgo
            medication.name = name
            medication.dosageText = dosage
            medication.colorHex = hex
            medication.profile = profile
            let schedule = Schedule(context: context)
            schedule.minutesOfDay = times.map(clamp)
            schedule.mealRelation = meal
            schedule.startDate = monthAgo
            schedule.medication = medication
            return medication
        }

        let letrox = make("Letrox", "50 µg", "3B7DD8", times: [clamp(minutesNow - 150), clamp(minutesNow + 300)], meal: .before)
        letrox.unitsPerDose = 0.5
        let ibuprofen = make("Ibuprofen", "400 mg", "D9534F", times: [clamp(minutesNow - 25), clamp(minutesNow + 180)], meal: .after)
        let vitamin = make("Vitamin D", "", "E0A526", times: [clamp(minutesNow + 90)])
        vitamin.unitKind = .drop
        vitamin.unitsPerDose = 20

        ibuprofen.tracksStock = true
        ibuprofen.unitsPerDose = 1
        ibuprofen.lowStockThreshold = 5
        ibuprofen.stockCount = 4
        ibuprofen.stockAtLastCount = 10
        ibuprofen.stockCountedAt = calendar.date(byAdding: .day, value: -3, to: now)

        // Letrox was taken this morning, a few minutes late.
        if let scheduled = calendar.date(bySettingHour: clamp(minutesNow - 150) / 60, minute: clamp(minutesNow - 150) % 60, second: 0, of: now) {
            let event = DoseEvent(context: context)
            event.scheduledAt = scheduled
            event.status = .taken
            event.takenAt = scheduled.addingTimeInterval(4 * 60)
            event.medication = letrox
        }
        // Some history for the calendar: last week fully taken except one missed dose.
        for dayOffset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            for (medication, minutes) in [(letrox, clamp(minutesNow - 150)), (ibuprofen, clamp(minutesNow - 25))] {
                if dayOffset == 3 && medication == ibuprofen { continue }
                guard let scheduled = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) else { continue }
                let event = DoseEvent(context: context)
                event.scheduledAt = scheduled
                event.status = .taken
                event.takenAt = scheduled.addingTimeInterval(120)
                event.medication = medication
            }
        }
        if withProfiles {
            // A dog with a monthly deworming tablet that is due today.
            let dog = Profile(context: context)
            dog.name = "Mentík"
            dog.kind = .pet
            dog.symbolName = "dog.fill"
            dog.colorHex = "8E5A3C"
            let milbemax = make("Milbemax", "", "2E8B57", times: [clamp(minutesNow + 30)])
            milbemax.profile = dog
            if let schedule = milbemax.allSchedules.first {
                schedule.repeatKind = .months
                schedule.startDate = calendar.date(byAdding: .month, value: -2, to: calendar.startOfDay(for: now))
            }
        }
        try? context.save()
    }
}
