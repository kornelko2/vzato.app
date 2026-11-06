// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData

/// Owns the Core Data stack. CloudKit sync is not enabled yet (phase 6); the container is
/// already an NSPersistentCloudKitContainer so turning it on later is a configuration change.
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

    let container: NSPersistentCloudKitContainer
    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Vzato", managedObjectModel: Self.model)
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store description")
        }
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        // Phase 1: local only. Phase 6 sets cloudKitContainerOptions here.
        description.cloudKitContainerOptions = nil
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Could not load the data store: \(error)")
            }
        }
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
    @MainActor
    static func populate(in context: NSManagedObjectContext) {
        let profileRequest = Profile.fetchRequest()
        profileRequest.predicate = NSPredicate(format: "isDefault == YES")
        let profile = (try? context.fetch(profileRequest).first) ?? {
            let profile = Profile(context: context)
            profile.name = "Me"
            profile.isDefault = true
            return profile
        }()

        let ibuprofen = Medication(context: context)
        ibuprofen.name = "Ibuprofen"
        ibuprofen.dosageText = "400 mg"
        ibuprofen.colorHex = "D9534F"
        ibuprofen.tracksStock = true
        ibuprofen.stockCount = 4
        ibuprofen.lowStockThreshold = 5
        ibuprofen.stockAtLastCount = 10
        ibuprofen.stockCountedAt = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        ibuprofen.profile = profile
        let s1 = Schedule(context: context)
        s1.minutesOfDay = [8 * 60, 20 * 60]
        s1.mealRelation = .after
        s1.startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        s1.medication = ibuprofen

        let vitamin = Medication(context: context)
        vitamin.name = "Vitamin D"
        vitamin.dosageText = "1 drop"
        vitamin.colorHex = "E0A526"
        vitamin.profile = profile
        let s2 = Schedule(context: context)
        s2.minutesOfDay = [12 * 60]
        s2.startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        s2.medication = vitamin

        try? context.save()
    }
}
