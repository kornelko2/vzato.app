// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

/// Owns the Core Data stack. iCloud sync is a build-time opt-in (`VzatoCloudKit` in Info.plist,
/// set from `VZATO_CLOUDKIT` in Config/Local.xcconfig); without it the store is local only.
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
    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Vzato", managedObjectModel: Self.model)
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store description")
        }
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        isCloudKitEnabled = !inMemory && Self.isCloudKitBuild
        if isCloudKitEnabled {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudKitContainerIdentifier)
        } else {
            description.cloudKitContainerOptions = nil
        }
        // History tracking and remote change notifications are what CloudKit sync builds on; harmless locally.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Could not load the data store: \(error)")
            }
        }
        #if DEBUG
        // `--init-cloudkit-schema` pushes the model to the CloudKit development environment once.
        if isCloudKitEnabled, CommandLine.arguments.contains("--init-cloudkit-schema") {
            do { try container.initializeCloudKitSchema(options: []) } catch { print("CloudKit schema: \(error)") }
        }
        #endif
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        ensureDefaultProfile()
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
    static func populate(in context: NSManagedObjectContext, now: Date = Date()) {
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
        let vitamin = make("Vitamin D", "", "E0A526", times: [clamp(minutesNow + 60)])
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
        try? context.save()
    }
}
