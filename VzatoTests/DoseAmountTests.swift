// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

/// A taken dose keeps the amount it was taken with, also after the medication's amount changes.
@MainActor
struct DoseAmountTests {
    private func slot(_ medication: Medication, _ day: Date, _ store: TestStore) -> DoseSlot {
        DoseScheduler.slots(for: [medication], on: day, calendar: testCalendar).first!
    }

    @Test func takenDoseSavesItsAmount() {
        let store = TestStore()
        let medication = store.medication(name: "Letrox", times: [8 * 60], stock: 10, unitsPerDose: 1)
        let logger = DoseLogger(context: store.context, now: at(monday, 8, 5), notifier: SpyNotifier())
        let event = logger.markTaken(slot(medication, monday, store))
        #expect(event.units == 1)
        #expect(event.takenUnit == .tablet)

        medication.unitsPerDose = 0.5
        #expect(event.takenUnits == 1, "The record keeps 1 tablet")
        #expect(event.amountText == DoseFormatter.amount(1, unit: .tablet))
    }

    @Test func undoReturnsWhatWasTaken() {
        let store = TestStore()
        let medication = store.medication(name: "Letrox", times: [8 * 60], stock: 10, unitsPerDose: 1)
        let logger = DoseLogger(context: store.context, now: at(monday, 8, 5), notifier: SpyNotifier())
        logger.markTaken(slot(medication, monday, store))
        #expect(medication.stockCount == 9)

        medication.unitsPerDose = 0.5
        logger.reset(slot(medication, monday, store))
        #expect(medication.stockCount == 10, "Undo returns the 1 tablet taken, not the new ½")
    }

    @Test func olderRecordsKeepTheOldAmountWhenItChanges() {
        let store = TestStore()
        let medication = store.medication(name: "Letrox", times: [8 * 60], unitsPerDose: 1)
        let logger = DoseLogger(context: store.context, now: at(monday, 8, 5), notifier: SpyNotifier())
        let event = logger.markTaken(slot(medication, monday, store))
        // As written by version 7 or an older app on another device.
        event.units = 0
        event.unitRaw = ""
        #expect(event.takenUnits == 1, "Without a saved amount the current one is shown")

        DoseLogger.keepAmounts(of: medication)
        medication.unitsPerDose = 0.5
        #expect(event.takenUnits == 1)
    }

    @Test func doctorSummaryShowsTheChange() {
        let store = TestStore()
        let medication = store.medication(name: "Letrox", times: [8 * 60], unitsPerDose: 1)
        let tuesday = testCalendar.date(byAdding: .day, value: 1, to: monday)!
        DoseLogger(context: store.context, now: at(monday, 8, 5), notifier: SpyNotifier()).markTaken(slot(medication, monday, store))
        medication.unitsPerDose = 0.5
        DoseLogger(context: store.context, now: at(tuesday, 8, 5), notifier: SpyNotifier()).markTaken(slot(medication, tuesday, store))

        let slots = [slot(medication, monday, store), slot(medication, tuesday, store)]
        let one = DoseFormatter.amount(1, unit: .tablet), half = DoseFormatter.amount(0.5, unit: .tablet)
        #expect(DoctorSummaryBuilder.amountHistory(of: slots, current: medication.doseAmountText) == "\(one) → \(half)")
        #expect(DoctorSummaryBuilder.amountHistory(of: [slots[1]], current: medication.doseAmountText) == half)
    }

    @Test func csvHasTheAmountTaken() {
        let store = TestStore()
        let medication = store.medication(name: "Letrox", times: [8 * 60], unitsPerDose: 0.5)
        let event = DoseLogger(context: store.context, now: at(monday, 8, 5), notifier: SpyNotifier())
            .markTaken(slot(medication, monday, store))
        let csv = CSVExport.make(events: [event])
        #expect(csv.hasPrefix("medication,dosage,scheduled_at,status,taken_at,source,unscheduled,profile,amount,unit\n"))
        #expect(csv.split(separator: "\n").last.map(String.init)?.hasSuffix(",0.5,tablet") == true)
    }
}
