// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import Vzato

@MainActor
struct ReconciliationTests {
    /// 10 pills counted Monday 00:00, two doses a day, nothing confirmed for three days.
    private func threeDaysUnconfirmed() -> (TestStore, Medication, Date) {
        let store = TestStore()
        let medication = store.medication(times: [8 * 60, 20 * 60], stock: 10)
        let now = at(days(3, after: monday), 12) // Thursday noon: 7 scheduled doses so far
        return (store, medication, now)
    }

    @Test func reportCountsScheduledAndRecordedDoses() {
        let (store, medication, now) = threeDaysUnconfirmed()
        let logger = DoseLogger(context: store.context, now: now, notifier: SpyNotifier())
        let mondaySlots = DoseScheduler.slots(for: [medication], on: monday, calendar: testCalendar)
        logger.markTaken(mondaySlots[0], at: at(monday, 8))
        logger.markSkipped(mondaySlots[1])

        let report = ReconciliationService.report(for: medication, actualStock: nil, now: now, calendar: testCalendar)
        #expect(report.scheduledDoses == 7)
        #expect(report.recordedTaken == 1)
        #expect(report.recordedSkipped == 1)
        #expect(report.unaccounted == 5)
        #expect(report.expectedStock == 9)
        #expect(report.verdict == .needsCount)
    }

    @Test func detectsConsistentMissingAndExtraUnits() {
        let (_, medication, now) = threeDaysUnconfirmed()
        #expect(ReconciliationService.report(for: medication, actualStock: 10, now: now, calendar: testCalendar).verdict == .consistent)
        #expect(ReconciliationService.report(for: medication, actualStock: 7, now: now, calendar: testCalendar).verdict == .unrecordedDoses(3))
        #expect(ReconciliationService.report(for: medication, actualStock: 12, now: now, calendar: testCalendar).verdict == .overRecordedDoses(2))
    }

    @Test func applyBackfillsOldestUnrecordedDosesAndSetsStock() {
        let (store, medication, now) = threeDaysUnconfirmed()
        let report = ReconciliationService.report(for: medication, actualStock: 7, now: now, calendar: testCalendar)
        ReconciliationService.apply(report, actualStock: 7, recordMissingDoses: true, context: store.context,
                                    now: now, calendar: testCalendar, notifier: SpyNotifier())

        let taken = medication.eventList.filter { $0.status == .taken }.sorted { $0.scheduledAt! < $1.scheduledAt! }
        #expect(taken.count == 3)
        #expect(taken.map(\.scheduledAt) == [at(monday, 8), at(monday, 20), at(days(1, after: monday), 8)])
        #expect(taken.allSatisfy { $0.source == .reconciliation && $0.takenAt == $0.scheduledAt })
        #expect(medication.stockCount == 7)
        #expect(medication.stockAtLastCount == 7)
        #expect(medication.stockCountedAt == now)

        let after = ReconciliationService.report(for: medication, actualStock: 7, now: now, calendar: testCalendar)
        #expect(after.verdict == .consistent)
    }

    @Test func applyWithoutBackfillOnlySetsStock() {
        let (store, medication, now) = threeDaysUnconfirmed()
        let report = ReconciliationService.report(for: medication, actualStock: 7, now: now, calendar: testCalendar)
        ReconciliationService.apply(report, actualStock: 7, recordMissingDoses: false, context: store.context,
                                    now: now, calendar: testCalendar, notifier: SpyNotifier())
        #expect(medication.eventList.isEmpty)
        #expect(medication.stockCount == 7)
    }

    @Test func csvEscapesCommasAndQuotes() {
        #expect(CSVExport.escape("plain") == "plain")
        #expect(CSVExport.escape("a,b") == "\"a,b\"")
        #expect(CSVExport.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }
}
