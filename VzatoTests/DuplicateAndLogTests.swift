// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreData
import Foundation
import Testing
@testable import Vzato

/// Simulates two devices that recorded the same dose before syncing: after sync both records
/// exist in one store.
@MainActor
struct DuplicateTests {
    private let grace: TimeInterval = 2 * 60 * 60

    private func record(_ status: DoseStatus, for medication: Medication, at scheduledAt: Date, takenAt: Date? = nil,
                        device: String, updatedAt: Date, in context: NSManagedObjectContext) -> DoseEvent {
        let event = DoseEvent(context: context)
        event.medication = medication
        event.scheduledAt = scheduledAt
        event.status = status
        event.takenAt = takenAt
        event.deviceName = device
        event.updatedAt = updatedAt
        return event
    }

    @Test func takenWinsOverSkippedEvenWhenSkippedIsNewer() throws {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60])
        let dose = at(monday, 8)
        record(.taken, for: medication, at: dose, takenAt: at(monday, 8, 5), device: "iPhone", updatedAt: at(monday, 8, 5), in: store.context)
        record(.skipped, for: medication, at: dose, device: "iPad", updatedAt: at(monday, 8, 30), in: store.context)
        try store.context.save()

        // Before the resolver runs, the screen already shows "taken" and one row only.
        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)
        #expect(slots.count == 1)
        #expect(slots[0].status(now: at(monday, 9), grace: grace) == .taken)

        #expect(DuplicateResolver.resolve(in: store.context, now: at(monday, 9)) == 1)
        let remaining = medication.eventList
        #expect(remaining.count == 1)
        #expect(remaining.first?.status == .taken)
        #expect(remaining.first?.deviceName == "iPhone")
    }

    @Test func earliestIntakeWinsWhenBothTook() throws {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60])
        let dose = at(monday, 8)
        record(.taken, for: medication, at: dose, takenAt: at(monday, 8, 10), device: "iPad", updatedAt: at(monday, 8, 10), in: store.context)
        record(.taken, for: medication, at: dose, takenAt: at(monday, 8, 2), device: "iPhone", updatedAt: at(monday, 8, 2), in: store.context)
        try store.context.save()

        DuplicateResolver.resolve(in: store.context, now: at(monday, 9))
        #expect(medication.eventList.map(\.takenAt) == [at(monday, 8, 2)])
    }

    @Test func choiceIsTheSameRegardlessOfOrder() throws {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60])
        let dose = at(monday, 8)
        let a = record(.taken, for: medication, at: dose, takenAt: at(monday, 8), device: "A", updatedAt: at(monday, 8), in: store.context)
        let b = record(.taken, for: medication, at: dose, takenAt: at(monday, 8), device: "B", updatedAt: at(monday, 8), in: store.context)
        #expect(DoseEvent.preferred([a, b]) === DoseEvent.preferred([b, a]))
    }

    @Test func mergeIsLoggedAndSupplyUntouched() throws {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60], stock: 9)
        let dose = at(monday, 8)
        record(.taken, for: medication, at: dose, takenAt: at(monday, 8), device: "iPhone", updatedAt: at(monday, 8), in: store.context)
        record(.taken, for: medication, at: dose, takenAt: at(monday, 8, 1), device: "iPad", updatedAt: at(monday, 8, 1), in: store.context)
        try store.context.save()

        DuplicateResolver.resolve(in: store.context, now: at(monday, 9))
        #expect(medication.stockCount == 9)
        let merges = try store.context.fetch(ActivityEntry.fetchRequest()).filter { $0.kind == .duplicateMerged }
        #expect(merges.count == 1)
        #expect(merges.first?.medicationName == medication.name)
        #expect(merges.first?.detail.contains("iPhone") == true)
        #expect(merges.first?.detail.contains("iPad") == true)
    }

    @Test func differentDosesAreNotMerged() throws {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60, 20 * 60])
        record(.taken, for: medication, at: at(monday, 8), takenAt: at(monday, 8), device: "iPhone", updatedAt: at(monday, 8), in: store.context)
        record(.taken, for: medication, at: at(monday, 20), takenAt: at(monday, 20), device: "iPad", updatedAt: at(monday, 20), in: store.context)
        try store.context.save()
        #expect(DuplicateResolver.resolve(in: store.context, now: at(monday, 21)) == 0)
        #expect(medication.eventList.count == 2)
    }
}

@MainActor
struct ActivityLogTests {
    private func entries(_ store: TestStore) throws -> [ActivityEntry] {
        let request = ActivityEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        return try store.context.fetch(request)
    }

    @Test func everyDoseActionIsLogged() throws {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60, 20 * 60])
        let before = try entries(store).count   // the test fixture may log the initial stock
        let logger = DoseLogger(context: store.context, now: at(monday, 8, 5), notifier: SpyNotifier())
        let slots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)

        let taken = logger.markTaken(slots[0], source: .widget)
        logger.markSkipped(slots[1], source: .notification)
        logger.reset(DoseSlot(medication: medication, scheduledAt: slots[0].scheduledAt, event: taken))
        logger.logExtraDose(for: medication, at: at(monday, 14))

        let log = try entries(store).dropFirst(before)
        #expect(log.map(\.kind) == [.taken, .skipped, .reset, .extraDose])
        #expect(log.map(\.source) == [.widget, .notification, .app, .app])
        #expect(log.allSatisfy { $0.medicationName == medication.name && $0.medicationID == medication.id })
        #expect(log.allSatisfy { !$0.deviceName.isEmpty })
        #expect(log.first?.scheduledAt == at(monday, 8))
    }

    @Test func lateConfirmationSaysWhenItWasTaken() throws {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60])
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        DoseLogger(context: store.context, now: at(monday, 13), notifier: SpyNotifier()).markTaken(slot, at: at(monday, 8, 10))
        let entry = try entries(store).last
        #expect(entry?.kind == .taken)
        #expect(entry?.detail.isEmpty == false)
    }

    @Test func supplyCheckAndCountAreLoggedOnce() throws {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60, 20 * 60], stock: 10)
        let before = try entries(store).count
        let now = at(days(3, after: monday), 12)
        let report = ReconciliationService.report(for: medication, actualStock: 7, now: now, calendar: testCalendar)
        ReconciliationService.apply(report, actualStock: 7, recordMissingDoses: true, context: store.context,
                                    now: now, calendar: testCalendar, notifier: SpyNotifier())
        let log = try entries(store).dropFirst(before)
        #expect(log.filter { $0.kind == .taken && $0.source == .reconciliation }.count == 3)
        #expect(log.filter { $0.kind == .supplyCheck }.count == 1)
        #expect(log.filter { $0.kind == .stockCounted }.isEmpty)
    }

    @Test func doseRecordsKnowTheirDevice() {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60])
        let slot = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)[0]
        let event = DoseLogger(context: store.context, now: at(monday, 8), notifier: SpyNotifier()).markTaken(slot)
        #expect(event.deviceName?.isEmpty == false)
    }
}
