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

    /// 1.0.1 on the App Store uses version 6.
    @Test func version6StoreOpensWithTheCurrentModel() throws {
        let bundle = Bundle(for: PersistenceController.self)
        let momd = try #require(bundle.url(forResource: "Vzato", withExtension: "momd"))
        let oldModel = try #require(NSManagedObjectModel(contentsOf: momd.appendingPathComponent("Vzato 6.mom")))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString)")
            .appendingPathComponent("Vzato.sqlite")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let old = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
        try old.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
        let oldContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        oldContext.persistentStoreCoordinator = old
        try oldContext.performAndWait {
            let profile = NSEntityDescription.insertNewObject(forEntityName: "Profile", into: oldContext)
            profile.setValue("Me", forKey: "name")
            let medication = NSEntityDescription.insertNewObject(forEntityName: "Medication", into: oldContext)
            medication.setValue("Letrox", forKey: "name")
            medication.setValue(profile, forKey: "profile")
            try oldContext.save()
        }
        for store in old.persistentStores { try old.remove(store) }

        let current = NSPersistentStoreCoordinator(managedObjectModel: PersistenceController.model)
        try current.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
        ])
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = current
        try context.performAndWait {
            let medications = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Medication"))
            #expect(medications.first?.value(forKey: "organizerModeRaw") as? String == "auto")
            #expect(try context.count(for: NSFetchRequest<NSManagedObject>(entityName: "Organizer")) == 0)
        }
        for store in current.persistentStores { try current.remove(store) }
    }

    /// Build 19 on TestFlight uses version 7. A taken dose from then has no amount saved.
    @Test func version7StoreOpensWithTheCurrentModel() throws {
        let bundle = Bundle(for: PersistenceController.self)
        let momd = try #require(bundle.url(forResource: "Vzato", withExtension: "momd"))
        let oldModel = try #require(NSManagedObjectModel(contentsOf: momd.appendingPathComponent("Vzato 7.mom")))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString)")
            .appendingPathComponent("Vzato.sqlite")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let old = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
        try old.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
        let oldContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        oldContext.persistentStoreCoordinator = old
        try oldContext.performAndWait {
            let medication = NSEntityDescription.insertNewObject(forEntityName: "Medication", into: oldContext)
            medication.setValue("Letrox", forKey: "name")
            let event = NSEntityDescription.insertNewObject(forEntityName: "DoseEvent", into: oldContext)
            event.setValue("taken", forKey: "statusRaw")
            event.setValue(medication, forKey: "medication")
            try oldContext.save()
        }
        for store in old.persistentStores { try old.remove(store) }

        let current = NSPersistentStoreCoordinator(managedObjectModel: PersistenceController.model)
        try current.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
        ])
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = current
        try context.performAndWait {
            let events = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "DoseEvent"))
            #expect(events.first?.value(forKey: "units") as? Double == 0)
            #expect(events.first?.value(forKey: "unitRaw") as? String == "")
        }
        for store in current.persistentStores { try current.remove(store) }
    }
}
