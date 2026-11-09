// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import Foundation
import Testing
@testable import Vzato

/// TestFlight builds use model version 5. Their stores must open with the current model by
/// lightweight migration, and old plans must keep their weekday behaviour.
@MainActor
struct MigrationTests {
    @Test func version5StoreOpensWithTheCurrentModel() throws {
        let bundle = Bundle(for: PersistenceController.self)
        let momd = try #require(bundle.url(forResource: "Vzato", withExtension: "momd"))
        let oldModel = try #require(NSManagedObjectModel(contentsOf: momd.appendingPathComponent("Vzato 5.mom")))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString)")
            .appendingPathComponent("Vzato.sqlite")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        // A version 5 store with one medication on Mondays and Wednesdays.
        let old = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
        try old.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
        let oldContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        oldContext.persistentStoreCoordinator = old
        try oldContext.performAndWait {
            let medication = NSEntityDescription.insertNewObject(forEntityName: "Medication", into: oldContext)
            medication.setValue("Letrox", forKey: "name")
            medication.setValue(UUID(), forKey: "id")
            let schedule = NSEntityDescription.insertNewObject(forEntityName: "Schedule", into: oldContext)
            schedule.setValue("2,4", forKey: "weekdaysRaw")
            schedule.setValue("480", forKey: "minutesRaw")
            schedule.setValue(medication, forKey: "medication")
            try oldContext.save()
        }
        for store in old.persistentStores { try old.remove(store) }

        // Open with the current model, as the app does.
        let current = NSPersistentStoreCoordinator(managedObjectModel: PersistenceController.model)
        try current.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
        ])
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = current
        try context.performAndWait {
            let schedules = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Schedule"))
            #expect(schedules.count == 1)
            #expect(schedules.first?.value(forKey: "repeatKindRaw") as? String == "weekdays")
            #expect(schedules.first?.value(forKey: "repeatIntervalCount") as? Int == 1)
            #expect(schedules.first?.value(forKey: "weekdaysRaw") as? String == "2,4")
            let medications = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Medication"))
            #expect(medications.first?.value(forKey: "registryCode") == nil)
        }
        for store in current.persistentStores { try current.remove(store) }
    }
}
